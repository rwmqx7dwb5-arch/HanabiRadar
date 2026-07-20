import XCTest
import Foundation
@testable import HanabiCore

final class ClusteringTests: XCTestCase {

    let clusterer = LaunchAreaClusterer()
    let base = GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 0)

    private func offset(east: Double, north: Double) -> GeodeticCoordinate {
        Geodesy.coordinate(from: base, enuOffset: Vector3(east, north, 0))
    }

    func testTwoSeparateClusters() {
        var points: [ClusterInputPoint] = []
        for i in 0..<5 {
            points.append(ClusterInputPoint(id: "a\(i)", coordinate: offset(east: Double(i) * 5, north: Double(i) * 3), weight: 0.8))
        }
        for i in 0..<4 {
            points.append(ClusterInputPoint(id: "b\(i)", coordinate: offset(east: 400 + Double(i) * 5, north: Double(i) * 3), weight: 0.7))
        }
        let clusters = clusterer.cluster(points, options: .init(epsilonMeters: 100, minPoints: 3))
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters[0].eventCount, 5)   // sorted by event count, descending
        XCTAssertEqual(clusters[1].eventCount, 4)
    }

    func testOutlierIsExcluded() {
        var points: [ClusterInputPoint] = []
        for i in 0..<5 {
            points.append(ClusterInputPoint(id: "a\(i)", coordinate: offset(east: Double(i) * 5, north: Double(i) * 3), weight: 0.9))
        }
        points.append(ClusterInputPoint(id: "far", coordinate: offset(east: 5000, north: 5000), weight: 0.9))
        let clusters = clusterer.cluster(points, options: .init(epsilonMeters: 100, minPoints: 3))
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].eventCount, 5)
        XCTAssertFalse(clusters[0].memberIDs.contains("far"))
    }

    func testClusterCenterIsNearTruth() {
        var points: [ClusterInputPoint] = []
        for i in 0..<6 {
            points.append(ClusterInputPoint(id: "c\(i)", coordinate: offset(east: 200 + Double(i), north: 150 + Double(i)), weight: 1.0))
        }
        let clusters = clusterer.cluster(points, options: .init(epsilonMeters: 100, minPoints: 3))
        XCTAssertEqual(clusters.count, 1)
        let centerOffset = Geodesy.enuOffset(of: clusters[0].center, from: base)
        XCTAssertEqual(centerOffset.x, 202.5, accuracy: 5)
        XCTAssertEqual(centerOffset.y, 152.5, accuracy: 5)
    }

    func testEmptyInput() {
        XCTAssertTrue(clusterer.cluster([]).isEmpty)
    }
}
