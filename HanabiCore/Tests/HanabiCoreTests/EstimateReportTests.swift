import XCTest
import Foundation
@testable import HanabiCore

final class EstimateReportTests: XCTestCase {

    private func estimate(iterations: Int, ground: Double? = nil) -> BurstEstimate {
        let est = BurstSolver().estimate(
            observer: GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 0),
            enuRay: Vector3(0, 0, 1),
            deltaT: 3,
            effectiveSoundSpeed: 340,
            iterations: iterations
        )
        guard let ground else { return est }
        return est.applyingGroundElevation(ElevationSample(elevation: ground, source: "test"))
    }

    private func uncertainty(
        category: ConfidenceCategory,
        radius: Double,
        factor: UncertaintyFactor = .heading,
        confidence: Double = 0.5
    ) -> UncertaintyResult {
        UncertaintyResult(
            distanceMedian: 1000, distanceLow95: 950, distanceHigh95: 1050,
            centerLatitude: 35, centerLongitude: 139,
            horizontalEllipse: ErrorEllipse(semiMajorMeters: radius, semiMinorMeters: radius * 0.6, orientationDegrees: 10),
            altitudeMedian: 300, altitudeLow95: 280, altitudeHigh95: 320,
            confidence: confidence, confidenceCategory: category, dominantFactor: factor, sampleCount: 1000
        )
    }

    func testFinePrecisionForTightHighConfidence() {
        let r = EstimateReporter.report(estimate: estimate(iterations: 2), uncertainty: uncertainty(category: .high, radius: 20))
        XCTAssertEqual(r.horizontalPrecision, .fine)
        XCTAssertEqual(r.horizontalPrecision.latLonDecimalPlaces, 5)
    }

    func testCoarsePrecisionForMediumRadius() {
        let r = EstimateReporter.report(estimate: estimate(iterations: 2), uncertainty: uncertainty(category: .medium, radius: 120))
        XCTAssertEqual(r.horizontalPrecision, .coarse)
        XCTAssertEqual(r.horizontalPrecision.latLonDecimalPlaces, 3)
    }

    func testAreaOnlyForLargeRadius() {
        let r = EstimateReporter.report(estimate: estimate(iterations: 2), uncertainty: uncertainty(category: .high, radius: 400))
        XCTAssertEqual(r.horizontalPrecision, .areaOnly)
        XCTAssertEqual(r.horizontalPrecision.latLonDecimalPlaces, 2)
    }

    /// Low confidence must never be shown as a sharp point even when the ellipse is tiny.
    func testLowConfidenceDemotesToAreaEvenWhenTight() {
        let r = EstimateReporter.report(estimate: estimate(iterations: 2), uncertainty: uncertainty(category: .low, radius: 10))
        XCTAssertEqual(r.horizontalPrecision, .areaOnly)
    }

    func testWeatherFullyAppliedReflectsIterations() {
        let none = EstimateReporter.report(estimate: estimate(iterations: 0), uncertainty: uncertainty(category: .high, radius: 20))
        XCTAssertFalse(none.weatherFullyApplied)
        let applied = EstimateReporter.report(estimate: estimate(iterations: 2), uncertainty: uncertainty(category: .high, radius: 20))
        XCTAssertTrue(applied.weatherFullyApplied)
    }

    func testGroundHeightAvailabilityReflectsEstimate() {
        let without = EstimateReporter.report(estimate: estimate(iterations: 1), uncertainty: uncertainty(category: .high, radius: 20))
        XCTAssertFalse(without.groundHeightAvailable)
        let with = EstimateReporter.report(estimate: estimate(iterations: 1, ground: 12), uncertainty: uncertainty(category: .high, radius: 20))
        XCTAssertTrue(with.groundHeightAvailable)
    }

    func testDominantFactorAndRadiusPassThrough() {
        let r = EstimateReporter.report(
            estimate: estimate(iterations: 1),
            uncertainty: uncertainty(category: .medium, radius: 85, factor: .gpsHorizontal, confidence: 0.42)
        )
        XCTAssertEqual(r.dominantFactor, .gpsHorizontal)
        XCTAssertEqual(r.horizontalRadius95Meters, 85, accuracy: 1e-9)
        XCTAssertEqual(r.confidence, 0.42, accuracy: 1e-9)
        XCTAssertEqual(r.confidenceCategory, .medium)
    }

    func testCustomThresholds() {
        // With a tighter fine ceiling, 40 m becomes coarse rather than fine.
        let tight = EstimateReporter.Thresholds(fineMaxMeters: 25, coarseMaxMeters: 300)
        let r = EstimateReporter.report(
            estimate: estimate(iterations: 1),
            uncertainty: uncertainty(category: .high, radius: 40),
            thresholds: tight
        )
        XCTAssertEqual(r.horizontalPrecision, .coarse)
    }
}
