import Foundation

/// One burst's contribution to a session-level launch-area estimate. Built by the app
/// from a `BurstEstimate` (subpoint, distance, altitude) plus the burst's overall
/// confidence from `UncertaintyResult`.
public struct SessionBurst: Sendable, Equatable {
    public var id: String
    /// Ground projection (subpoint) of the burst — the input to launch-area clustering.
    public var subpoint: GeodeticCoordinate
    /// Overall confidence for this burst, 0...1. Used both as the clustering weight and
    /// to gate out very-low-confidence bursts before aggregation.
    public var confidence: Double
    /// Slant distance observer -> burst, meters (for representative session stats).
    public var lineOfSightDistance: Double
    /// Burst altitude in the estimate's datum, meters (for representative session stats).
    public var burstAltitude: Double

    public init(
        id: String,
        subpoint: GeodeticCoordinate,
        confidence: Double,
        lineOfSightDistance: Double,
        burstAltitude: Double
    ) {
        self.id = id
        self.subpoint = subpoint
        self.confidence = confidence
        self.lineOfSightDistance = lineOfSightDistance
        self.burstAltitude = burstAltitude
    }
}

/// The aggregated result for a measurement session: estimated launch areas plus a few
/// robust representative statistics.
///
/// A single burst subpoint is NEVER treated as the launch site; the launch area is
/// derived from many bursts, and bursts that do not fall in any dense region are left as
/// outliers rather than forced into a cluster (commissioning §15).
public struct SessionSummary: Equatable, Sendable {
    /// Estimated launch areas, most-populous first (empty when nothing dense enough).
    public var clusters: [LaunchCluster]
    /// Total bursts supplied.
    public var burstCount: Int
    /// Bursts that passed the confidence gate and fed clustering.
    public var usedBurstCount: Int
    /// Bursts assigned to some launch-area cluster (⊆ used; the rest are outliers/noise).
    public var clusteredBurstCount: Int
    /// Median slant distance across used bursts, meters; nil when there are none.
    public var representativeDistance: Double?
    /// Median burst altitude across used bursts, meters; nil when there are none.
    public var representativeAltitude: Double?

    public init(
        clusters: [LaunchCluster],
        burstCount: Int,
        usedBurstCount: Int,
        clusteredBurstCount: Int,
        representativeDistance: Double?,
        representativeAltitude: Double?
    ) {
        self.clusters = clusters
        self.burstCount = burstCount
        self.usedBurstCount = usedBurstCount
        self.clusteredBurstCount = clusteredBurstCount
        self.representativeDistance = representativeDistance
        self.representativeAltitude = representativeAltitude
    }
}

/// Combines many per-burst estimates into a session-level launch-area summary. Pure and
/// deterministic; it wires confidence-weighted clustering (`LaunchAreaClusterer`) to
/// robust session statistics so the result improves as more bursts are measured.
public struct SessionAggregator: Sendable {

    public struct Options: Sendable {
        /// Bursts below this confidence are excluded from clustering and statistics, so a
        /// few unreliable measurements cannot drag the launch area around.
        public var minConfidence: Double
        public var clusterOptions: LaunchAreaClusterer.Options

        public init(minConfidence: Double = 0.15, clusterOptions: LaunchAreaClusterer.Options = .init()) {
            self.minConfidence = minConfidence
            self.clusterOptions = clusterOptions
        }
    }

    public init() {}

    public func summarize(_ bursts: [SessionBurst], options: Options = Options()) -> SessionSummary {
        let used = bursts.filter { $0.confidence >= options.minConfidence }
        let points = used.map {
            ClusterInputPoint(id: $0.id, coordinate: $0.subpoint, weight: $0.confidence)
        }
        let clusters = LaunchAreaClusterer().cluster(points, options: options.clusterOptions)
        let clusteredIDs = Set(clusters.flatMap { $0.memberIDs })

        let distances = used.map(\.lineOfSightDistance)
        let altitudes = used.map(\.burstAltitude)

        return SessionSummary(
            clusters: clusters,
            burstCount: bursts.count,
            usedBurstCount: used.count,
            clusteredBurstCount: clusteredIDs.count,
            representativeDistance: distances.isEmpty ? nil : Statistics.median(distances),
            representativeAltitude: altitudes.isEmpty ? nil : Statistics.median(altitudes)
        )
    }
}
