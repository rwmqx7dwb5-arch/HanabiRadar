import XCTest
import Foundation
@testable import HanabiCore

private struct StubWeather: WeatherConditionsProviding {
    let fixed: WeatherConditions
    func conditions(at coordinate: GeodeticCoordinate) async throws -> WeatherConditions { fixed }
}

private struct FailingWeather: WeatherConditionsProviding {
    struct Failure: Error {}
    func conditions(at coordinate: GeodeticCoordinate) async throws -> WeatherConditions { throw Failure() }
}

final class BurstSolverTests: XCTestCase {

    let solver = BurstSolver()

    func testDistanceEqualsSpeedTimesDelay() {
        let est = solver.estimate(
            observer: GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 0),
            enuRay: Vector3(0, 0, 1),
            deltaT: 3,
            effectiveSoundSpeed: 340,
            iterations: 0
        )
        XCTAssertEqual(est.lineOfSightDistance, 1020, accuracy: 1e-6)
    }

    func testVerticalRayGivesAltitude() {
        let observer = GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 20)
        let est = solver.estimate(
            observer: observer,
            enuRay: Vector3(0, 0, 1),
            deltaT: 1,
            effectiveSoundSpeed: 340,
            iterations: 0
        )
        XCTAssertEqual(est.elevationDegrees, 90, accuracy: 1e-6)
        XCTAssertEqual(est.relativeHeight, 340, accuracy: 0.2)
        XCTAssertEqual(est.burst.altitude, 360, accuracy: 0.2)
        XCTAssertEqual(est.horizontalDistance, 0, accuracy: 1e-3)
    }

    func testWeatherIterationBlendsTemperature() async {
        let sighting = BurstSolver.Sighting(
            observer: GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 0),
            imagePoint: ImagePoint(u: 0, v: 0),
            intrinsics: CameraIntrinsics(fx: 1000, fy: 1000, cx: 0, cy: 0, width: 100, height: 100),
            deviceToENU: .identity,
            deltaT: 3
        )
        let observerWeather = WeatherConditions(temperatureCelsius: 30, relativeHumidity: 0, pressureHPa: 1013.25)
        let provider = StubWeather(fixed: WeatherConditions(temperatureCelsius: 20, relativeHumidity: 0, pressureHPa: 1013.25))
        let est = await solver.solve(sighting, observerWeather: observerWeather, weatherProvider: provider)
        let expected = SoundSpeedModel().drySpeed(temperatureCelsius: 25)
        XCTAssertEqual(est.effectiveSoundSpeed, expected, accuracy: 0.05)
        XCTAssertGreaterThanOrEqual(est.iterations, 1)
    }

    func testWeatherFailureFallsBackToObserverOnly() async {
        let sighting = BurstSolver.Sighting(
            observer: GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 0),
            imagePoint: ImagePoint(u: 0, v: 0),
            intrinsics: CameraIntrinsics(fx: 1000, fy: 1000, cx: 0, cy: 0, width: 100, height: 100),
            deviceToENU: .identity,
            deltaT: 3
        )
        let observerWeather = WeatherConditions(temperatureCelsius: 30, relativeHumidity: 0, pressureHPa: 1013.25)
        let est = await solver.solve(sighting, observerWeather: observerWeather, weatherProvider: FailingWeather())
        let expected = SoundSpeedModel().drySpeed(temperatureCelsius: 30)
        XCTAssertEqual(est.effectiveSoundSpeed, expected, accuracy: 0.05)
    }
}
