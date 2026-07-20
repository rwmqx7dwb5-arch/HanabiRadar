import XCTest
import Foundation
@testable import HanabiCore

final class UncertaintyTests: XCTestCase {

    let estimator = UncertaintyEstimator()
    let observer = GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 0)
    let weather = WeatherConditions(temperatureCelsius: 25, relativeHumidity: 0.5, pressureHPa: 1013.25)

    private func ray(azimuthDegrees az: Double, elevationDegrees el: Double) -> Vector3 {
        let a = az * .pi / 180
        let e = el * .pi / 180
        return Vector3(cos(e) * sin(a), cos(e) * cos(a), sin(e))
    }

    func testDeterministicForFixedSeed() {
        let inputs = UncertaintyEstimator.Inputs(sampleCount: 500, seed: 12345)
        let a = estimator.evaluate(observer: observer, enuRay: ray(azimuthDegrees: 45, elevationDegrees: 40), deltaT: 4, weather: weather, inputs: inputs)
        let b = estimator.evaluate(observer: observer, enuRay: ray(azimuthDegrees: 45, elevationDegrees: 40), deltaT: 4, weather: weather, inputs: inputs)
        XCTAssertEqual(a, b)
    }

    func testIntervalWidensWithDeltaTSigma() {
        let narrow = estimator.evaluate(
            observer: observer, enuRay: ray(azimuthDegrees: 45, elevationDegrees: 40), deltaT: 4,
            weather: weather, inputs: .init(deltaTSigma: 0.01, sampleCount: 2000, seed: 7)
        )
        let wide = estimator.evaluate(
            observer: observer, enuRay: ray(azimuthDegrees: 45, elevationDegrees: 40), deltaT: 4,
            weather: weather, inputs: .init(deltaTSigma: 0.15, sampleCount: 2000, seed: 7)
        )
        let narrowWidth = narrow.distanceHigh95 - narrow.distanceLow95
        let wideWidth = wide.distanceHigh95 - wide.distanceLow95
        XCTAssertGreaterThan(wideWidth, narrowWidth * 2)
    }

    func testMedianNearNominalAndEllipseOrdered() {
        let inputs = UncertaintyEstimator.Inputs(sampleCount: 3000, seed: 99)
        let result = estimator.evaluate(observer: observer, enuRay: ray(azimuthDegrees: 45, elevationDegrees: 40), deltaT: 4, weather: weather, inputs: inputs)
        let nominalSpeed = SoundSpeedModel().effectiveSpeed(
            temperatureCelsius: 25, relativeHumidity: 0.5, pressureHPa: 1013.25,
            windENU: .zero, pathUnitBurstToObserver: Vector3(0, 0, -1)
        )
        XCTAssertEqual(result.distanceMedian, nominalSpeed * 4, accuracy: nominalSpeed * 4 * 0.03)
        XCTAssertGreaterThanOrEqual(result.horizontalEllipse.semiMajorMeters, result.horizontalEllipse.semiMinorMeters)
        XCTAssertEqual(result.sampleCount, 3000)
    }

    func testDominantFactorHeading() {
        let inputs = UncertaintyEstimator.Inputs(
            deltaTSigma: 0.001, temperatureSigma: 0.1, headingSigma: 15, elevationSigma: 0.1,
            attitudeSigma: 0.1, horizontalAccuracy: 1, verticalAccuracy: 1, soundSpeedSigma: 0.05,
            windSpeedSigma: 0.05, sampleCount: 100, seed: 1
        )
        let result = estimator.evaluate(observer: observer, enuRay: ray(azimuthDegrees: 45, elevationDegrees: 40), deltaT: 6, weather: weather, inputs: inputs)
        XCTAssertEqual(result.dominantFactor, .heading)
    }

    func testDominantFactorTimeDifference() {
        let inputs = UncertaintyEstimator.Inputs(
            deltaTSigma: 0.3, temperatureSigma: 0.1, headingSigma: 0.1, elevationSigma: 0.1,
            attitudeSigma: 0.1, horizontalAccuracy: 1, verticalAccuracy: 1, soundSpeedSigma: 0.05,
            windSpeedSigma: 0.05, sampleCount: 100, seed: 1
        )
        let result = estimator.evaluate(observer: observer, enuRay: ray(azimuthDegrees: 45, elevationDegrees: 40), deltaT: 6, weather: weather, inputs: inputs)
        XCTAssertEqual(result.dominantFactor, .timeDifference)
    }
}
