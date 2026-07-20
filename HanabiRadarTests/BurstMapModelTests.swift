import XCTest
import MapKit
import HanabiCore
@testable import HanabiRadar

final class BurstMapModelTests: XCTestCase {

    private func uncertainty(
        centerLat: Double, centerLon: Double, semiMajor: Double
    ) -> UncertaintyResult {
        UncertaintyResult(
            distanceMedian: 1000, distanceLow95: 950, distanceHigh95: 1050,
            centerLatitude: centerLat, centerLongitude: centerLon,
            horizontalEllipse: ErrorEllipse(semiMajorMeters: semiMajor, semiMinorMeters: semiMajor * 0.6, orientationDegrees: 10),
            altitudeMedian: 300, altitudeLow95: 280, altitudeHigh95: 320,
            confidence: 0.6, confidenceCategory: .medium, dominantFactor: .heading, sampleCount: 100
        )
    }

    func testBuildProducesObserverBurstSubpointAndCircle() {
        let observer = GeodeticCoordinate(latitude: 35.681, longitude: 139.767, altitude: 30)
        let estimate = BurstSolver().estimate(
            observer: observer, enuRay: Vector3(0, 1, 1), deltaT: 4, effectiveSoundSpeed: 340, iterations: 1
        )
        let unc = uncertainty(centerLat: estimate.burst.latitude, centerLon: estimate.burst.longitude, semiMajor: 120)
        let model = BurstMapModel.build(observer: observer, estimate: estimate, uncertainty: unc)

        XCTAssertEqual(model.points.map(\.kind), [.observer, .burst, .subpoint])
        XCTAssertEqual(model.points[0].latitude, observer.latitude, accuracy: 1e-9)
        XCTAssertEqual(model.points[0].longitude, observer.longitude, accuracy: 1e-9)
        XCTAssertEqual(model.points[1].latitude, estimate.burst.latitude, accuracy: 1e-9)
        XCTAssertEqual(model.points[2].latitude, estimate.subpoint.latitude, accuracy: 1e-9)
        XCTAssertEqual(model.circleRadiusMeters, 120, accuracy: 1e-9)
        XCTAssertEqual(model.circleCenterLatitude, estimate.burst.latitude, accuracy: 1e-9)
    }

    func testRegionHasMinimumSpanAndSaneCenter() {
        // A near-vertical burst places all points at ~the observer, so the span must fall
        // back to the minimum rather than collapse to zero.
        let observer = GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 0)
        let estimate = BurstSolver().estimate(
            observer: observer, enuRay: Vector3(0, 0, 1), deltaT: 1, effectiveSoundSpeed: 340, iterations: 0
        )
        let unc = uncertainty(centerLat: 35, centerLon: 139, semiMajor: 50)
        let region = BurstMapModel.build(observer: observer, estimate: estimate, uncertainty: unc).region

        XCTAssertGreaterThanOrEqual(region.span.latitudeDelta, 0.01)
        XCTAssertGreaterThanOrEqual(region.span.longitudeDelta, 0.01)
        XCTAssertEqual(region.center.latitude, 35, accuracy: 0.05)
        XCTAssertEqual(region.center.longitude, 139, accuracy: 0.05)
    }
}
