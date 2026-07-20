import XCTest
import Foundation
@testable import HanabiCore

final class UncertaintyInputsTests: XCTestCase {

    func testDeltaTCombinesFrameAndBangOnset() {
        let inputs = UncertaintyEstimator.Inputs.fromMeasurement(
            horizontalAccuracy: 10, verticalAccuracy: 15,
            headingAccuracyDegrees: 8, frameRate: 60, pairingConfidence: 1.0
        )
        let expected = (pow(1.0 / 60.0, 2) + pow(0.003, 2)).squareRoot()
        XCTAssertEqual(inputs.deltaTSigma, expected, accuracy: 1e-9)
        // Higher frame rate must reduce the timing sigma.
        let fast = UncertaintyEstimator.Inputs.fromMeasurement(
            horizontalAccuracy: 10, verticalAccuracy: 15,
            headingAccuracyDegrees: 8, frameRate: 120, pairingConfidence: 1.0
        )
        XCTAssertLessThan(fast.deltaTSigma, inputs.deltaTSigma)
    }

    func testZeroFrameRateFallsBackTo30() {
        let inputs = UncertaintyEstimator.Inputs.fromMeasurement(
            horizontalAccuracy: 10, verticalAccuracy: 15,
            headingAccuracyDegrees: 8, frameRate: 0, pairingConfidence: 1.0
        )
        let expected = (pow(1.0 / 30.0, 2) + pow(0.003, 2)).squareRoot()
        XCTAssertEqual(inputs.deltaTSigma, expected, accuracy: 1e-9)
    }

    func testHeadingSigmaFollowsAccuracyButIsFloored() {
        let good = UncertaintyEstimator.Inputs.fromMeasurement(
            horizontalAccuracy: 10, verticalAccuracy: 15,
            headingAccuracyDegrees: 12, frameRate: 60, pairingConfidence: 1.0
        )
        XCTAssertEqual(good.headingSigma, 12, accuracy: 1e-9)
        let optimistic = UncertaintyEstimator.Inputs.fromMeasurement(
            horizontalAccuracy: 10, verticalAccuracy: 15,
            headingAccuracyDegrees: 0.4, frameRate: 60, pairingConfidence: 1.0
        )
        XCTAssertEqual(optimistic.headingSigma, 1.0, accuracy: 1e-9)   // floored at 1 degree
    }

    func testAccuraciesAndConfidenceAreClamped() {
        let inputs = UncertaintyEstimator.Inputs.fromMeasurement(
            horizontalAccuracy: -5, verticalAccuracy: -3,
            headingAccuracyDegrees: 8, frameRate: 60, pairingConfidence: 1.7
        )
        XCTAssertEqual(inputs.horizontalAccuracy, 0, accuracy: 1e-9)
        XCTAssertEqual(inputs.verticalAccuracy, 0, accuracy: 1e-9)
        XCTAssertEqual(inputs.pairingConfidence, 1.0, accuracy: 1e-9)

        let low = UncertaintyEstimator.Inputs.fromMeasurement(
            horizontalAccuracy: 10, verticalAccuracy: 15,
            headingAccuracyDegrees: 8, frameRate: 60, pairingConfidence: -0.2
        )
        XCTAssertEqual(low.pairingConfidence, 0, accuracy: 1e-9)
    }

    func testPassThroughAccuracies() {
        let inputs = UncertaintyEstimator.Inputs.fromMeasurement(
            horizontalAccuracy: 22, verticalAccuracy: 33,
            headingAccuracyDegrees: 8, frameRate: 60, pairingConfidence: 0.7
        )
        XCTAssertEqual(inputs.horizontalAccuracy, 22, accuracy: 1e-9)
        XCTAssertEqual(inputs.verticalAccuracy, 33, accuracy: 1e-9)
        XCTAssertEqual(inputs.pairingConfidence, 0.7, accuracy: 1e-9)
    }

    /// The live-derived inputs must actually drive the estimator end to end.
    func testInputsFeedUncertaintyEstimator() {
        let inputs = UncertaintyEstimator.Inputs.fromMeasurement(
            horizontalAccuracy: 10, verticalAccuracy: 15,
            headingAccuracyDegrees: 8, frameRate: 60, pairingConfidence: 0.9,
            sampleCount: 400
        )
        let result = UncertaintyEstimator().evaluate(
            observer: GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 0),
            enuRay: Vector3(0, 1, 1),
            deltaT: 4,
            weather: WeatherConditions(temperatureCelsius: 20),
            inputs: inputs
        )
        XCTAssertEqual(result.sampleCount, 400)
        XCTAssertGreaterThan(result.distanceHigh95, result.distanceLow95)
        XCTAssertGreaterThan(result.horizontalEllipse.semiMajorMeters, 0)
    }
}
