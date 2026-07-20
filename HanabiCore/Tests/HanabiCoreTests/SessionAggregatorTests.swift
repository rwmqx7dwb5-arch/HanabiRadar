import XCTest
import Foundation
@testable import HanabiCore

final class SessionAggregatorTests: XCTestCase {

    private let origin = GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 0)

    /// A burst whose subpoint sits at a known ENU offset (meters) from a fixed origin.
    private func point(
        _ id: String, _ east: Double, _ north: Double,
        confidence: Double = 0.8, distance: Double = 1000, altitude: Double = 300
    ) -> SessionBurst {
        let coord = Geodesy.coordinate(from: origin, enuOffset: Vector3(east, north, 0))
        return SessionBurst(
            id: id, subpoint: coord, confidence: confidence,
            lineOfSightDistance: distance, burstAltitude: altitude
        )
    }

    func testEmptyInput() {
        let s = SessionAggregator().summarize([])
        XCTAssertTrue(s.clusters.isEmpty)
        XCTAssertEqual(s.burstCount, 0)
        XCTAssertEqual(s.usedBurstCount, 0)
        XCTAssertEqual(s.clusteredBurstCount, 0)
        XCTAssertNil(s.representativeDistance)
        XCTAssertNil(s.representativeAltitude)
    }

    func testSinglePadClustersAndRepresentativeStats() {
        let bursts = [
            point("a", 0, 0, distance: 900, altitude: 300),
            point("b", 30, 20, distance: 1000, altitude: 320),
            point("c", -25, 15, distance: 1100, altitude: 310),
            point("d", 10, -20, distance: 1000, altitude: 290)
        ]
        let s = SessionAggregator().summarize(bursts)
        XCTAssertEqual(s.clusters.count, 1)
        XCTAssertEqual(s.burstCount, 4)
        XCTAssertEqual(s.usedBurstCount, 4)
        XCTAssertEqual(s.clusteredBurstCount, 4)
        XCTAssertEqual(s.clusters[0].eventCount, 4)
        // median of [900,1000,1000,1100] = 1000; median of [290,300,310,320] = 305.
        XCTAssertEqual(s.representativeDistance ?? .nan, 1000, accuracy: 1e-6)
        XCTAssertEqual(s.representativeAltitude ?? .nan, 305, accuracy: 1e-6)
    }

    func testLowConfidenceBurstsAreGatedOut() {
        var bursts = [
            point("a", 0, 0, distance: 900, altitude: 300),
            point("b", 30, 20, distance: 1000, altitude: 320),
            point("c", -25, 15, distance: 1100, altitude: 310),
            point("d", 10, -20, distance: 1000, altitude: 290)
        ]
        bursts.append(point("lowconf", 0, 0, confidence: 0.05, distance: 9000, altitude: 9000))
        let s = SessionAggregator().summarize(bursts)
        XCTAssertEqual(s.burstCount, 5)
        XCTAssertEqual(s.usedBurstCount, 4)                       // low-confidence excluded
        XCTAssertEqual(s.representativeDistance ?? .nan, 1000, accuracy: 1e-6)  // 9000 ignored
    }

    func testTwoLaunchPadsYieldTwoClustersOrderedByCount() {
        let padA = (0..<5).map { point("a\($0)", Double($0) * 20, Double($0) * 10, distance: 1000, altitude: 300) }
        let padB = (0..<4).map { point("b\($0)", 2000 + Double($0) * 15, 2000 + Double($0) * 15, distance: 1500, altitude: 400) }
        let s = SessionAggregator().summarize(padA + padB)
        XCTAssertEqual(s.clusters.count, 2)
        XCTAssertEqual(s.clusters[0].eventCount, 5)               // most-populous first
        XCTAssertEqual(s.clusters[1].eventCount, 4)
        XCTAssertEqual(s.usedBurstCount, 9)
        XCTAssertEqual(s.clusteredBurstCount, 9)
    }

    func testIsolatedOutlierIsNotForcedIntoACluster() {
        let padA = [
            point("a", 0, 0), point("b", 30, 20), point("c", -25, 15), point("d", 10, -20)
        ]
        let outlier = point("out", 5000, 5000, confidence: 0.8, distance: 1200, altitude: 500)
        let s = SessionAggregator().summarize(padA + [outlier])
        XCTAssertEqual(s.usedBurstCount, 5)                        // outlier passes confidence gate
        XCTAssertEqual(s.clusters.count, 1)
        XCTAssertEqual(s.clusteredBurstCount, 4)                   // but is left as noise, not clustered
        XCTAssertFalse(s.clusters[0].memberIDs.contains("out"))
    }
}
