import Foundation

/// One burst subpoint fed to the clusterer.
public struct ClusterInputPoint: Sendable, Equatable {
    public var id: String
    /// Ground projection (subpoint) of the burst.
    public var coordinate: GeodeticCoordinate
    /// Per-event weight, typically the estimate confidence in 0...1.
    public var weight: Double

    public init(id: String, coordinate: GeodeticCoordinate, weight: Double) {
        self.id = id
        self.coordinate = coordinate
        self.weight = weight
    }
}

/// An estimated launch area produced from many burst subpoints.
public struct LaunchCluster: Equatable, Sendable {
    public var memberIDs: [String]
    public var center: GeodeticCoordinate
    /// Radius (meters) containing ~95% of member subpoints from the center.
    public var confidenceRadiusMeters: Double
    public var eventCount: Int
    public var confidence: Double

    public init(
        memberIDs: [String],
        center: GeodeticCoordinate,
        confidenceRadiusMeters: Double,
        eventCount: Int,
        confidence: Double
    ) {
        self.memberIDs = memberIDs
        self.center = center
        self.confidenceRadiusMeters = confidenceRadiusMeters
        self.eventCount = eventCount
        self.confidence = confidence
    }
}

/// Clusters burst subpoints into estimated launch areas with weighted DBSCAN,
/// a robust (MAD-trimmed, weighted) center, and a 95% radius. Noise points are
/// treated as outliers and excluded. Multiple launch pads yield multiple clusters.
public struct LaunchAreaClusterer: Sendable {

    public struct Options: Sendable {
        /// Neighborhood radius for DBSCAN, meters.
        public var epsilonMeters: Double
        /// Minimum points to form a dense region.
        public var minPoints: Int
        /// Robustness: members beyond `median + k * 1.4826 * MAD` are trimmed.
        public var madOutlierK: Double

        public init(epsilonMeters: Double = 120, minPoints: Int = 3, madOutlierK: Double = 3.0) {
            self.epsilonMeters = epsilonMeters
            self.minPoints = minPoints
            self.madOutlierK = madOutlierK
        }
    }

    public init() {}

    public func cluster(_ points: [ClusterInputPoint], options: Options = Options()) -> [LaunchCluster] {
        guard !points.isEmpty else { return [] }

        let origin = weightedCentroid(points)
        let projected: [(x: Double, y: Double)] = points.map {
            let offset = Geodesy.enuOffset(of: $0.coordinate, from: origin)
            return (offset.x, offset.y)
        }

        let n = points.count
        let eps2 = options.epsilonMeters * options.epsilonMeters
        var labels = [Int](repeating: -2, count: n)   // -2 unvisited, -1 noise, >=0 cluster
        var clusterID = 0

        func neighbors(of i: Int) -> [Int] {
            var result: [Int] = []
            for j in 0..<n {
                let dx = projected[i].x - projected[j].x
                let dy = projected[i].y - projected[j].y
                if dx * dx + dy * dy <= eps2 { result.append(j) }
            }
            return result
        }

        for i in 0..<n where labels[i] == -2 {
            let seed = neighbors(of: i)
            if seed.count < options.minPoints {
                labels[i] = -1
                continue
            }
            labels[i] = clusterID
            var queue = seed
            var queued = Set(seed)
            var k = 0
            while k < queue.count {
                let q = queue[k]
                k += 1
                if labels[q] == -1 { labels[q] = clusterID }   // border point
                if labels[q] != -2 { continue }
                labels[q] = clusterID
                let qNeighbors = neighbors(of: q)
                if qNeighbors.count >= options.minPoints {
                    for m in qNeighbors where !queued.contains(m) {
                        queued.insert(m)
                        queue.append(m)
                    }
                }
            }
            clusterID += 1
        }

        var clusters: [LaunchCluster] = []
        for cid in 0..<clusterID {
            let indices = (0..<n).filter { labels[$0] == cid }
            if indices.isEmpty { continue }
            if let built = buildCluster(indices: indices, points: points, projected: projected, origin: origin, options: options) {
                clusters.append(built)
            }
        }
        clusters.sort { $0.eventCount > $1.eventCount }
        return clusters
    }

    // MARK: - Private

    private func weightedCentroid(_ points: [ClusterInputPoint]) -> GeodeticCoordinate {
        var sumW = 0.0, lat = 0.0, lon = 0.0
        for p in points {
            let w = Swift.max(0, p.weight) + 1e-9
            sumW += w
            lat += w * p.coordinate.latitude
            lon += w * p.coordinate.longitude
        }
        guard sumW > 0 else { return points[0].coordinate }
        return GeodeticCoordinate(latitude: lat / sumW, longitude: lon / sumW, altitude: 0)
    }

    private func buildCluster(
        indices: [Int],
        points: [ClusterInputPoint],
        projected: [(x: Double, y: Double)],
        origin: GeodeticCoordinate,
        options: Options
    ) -> LaunchCluster? {
        func weightedMean(_ idxs: [Int]) -> (x: Double, y: Double, sumW: Double) {
            var sumW = 0.0, mx = 0.0, my = 0.0
            for i in idxs {
                let w = Swift.max(0, points[i].weight) + 1e-9
                sumW += w
                mx += w * projected[i].x
                my += w * projected[i].y
            }
            return sumW > 0 ? (mx / sumW, my / sumW, sumW) : (0, 0, 0)
        }

        var members = indices
        var mean = weightedMean(members)

        // Robust MAD-based outlier trim (one pass).
        let distances = members.map { hypot(projected[$0].x - mean.x, projected[$0].y - mean.y) }
        let medianR = Statistics.median(distances)
        let madR = Statistics.medianAbsoluteDeviation(distances)
        if madR > 0 {
            let threshold = medianR + options.madOutlierK * 1.4826 * madR
            let kept = members.filter { hypot(projected[$0].x - mean.x, projected[$0].y - mean.y) <= threshold }
            if kept.count >= 1 && kept.count < members.count {
                members = kept
                mean = weightedMean(members)
            }
        }

        guard !members.isEmpty else { return nil }

        let keptDistances = members.map { hypot(projected[$0].x - mean.x, projected[$0].y - mean.y) }
        let radius95 = Statistics.percentile(keptDistances, 0.95)
        let center = Geodesy.coordinate(from: origin, enuOffset: Vector3(mean.x, mean.y, 0))

        let count = members.count
        let countScore = Double(count) / Double(count + 3)
        let radiusScore = 1.0 / (1.0 + pow(radius95 / 150.0, 2))
        let meanWeight = Swift.max(0, Swift.min(1, Statistics.mean(members.map { Swift.max(0, Swift.min(1, points[$0].weight)) })))
        let confidence = Swift.max(0, Swift.min(1, 0.45 * countScore + 0.25 * radiusScore + 0.30 * meanWeight))

        return LaunchCluster(
            memberIDs: members.map { points[$0].id },
            center: center,
            confidenceRadiusMeters: radius95,
            eventCount: count,
            confidence: confidence
        )
    }
}
