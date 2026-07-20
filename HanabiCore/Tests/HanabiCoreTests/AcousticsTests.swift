import XCTest
import Foundation
@testable import HanabiCore

final class AcousticsTests: XCTestCase {

    let model = SoundSpeedModel()

    func testDrySpeedKnownValues() {
        XCTAssertEqual(model.drySpeed(temperatureCelsius: 0), 331.3, accuracy: 1e-6)
        XCTAssertEqual(model.drySpeed(temperatureCelsius: 20), 343.2, accuracy: 0.2)
        XCTAssertEqual(model.drySpeed(temperatureCelsius: 15), 340.3, accuracy: 0.3)
    }

    func testHumidityRaisesSpeedByASmallAmount() {
        let correction = model.humidityCorrection(temperatureCelsius: 25, relativeHumidity: 1.0, pressureHPa: 1013.25)
        XCTAssertGreaterThan(correction, 0)
        XCTAssertLessThan(correction, 1.0)
    }

    func testWindVectorFromNorthBlowsSouth() {
        let v = SoundSpeedModel.windVectorENU(speed: 5, fromDirectionDegrees: 0)
        XCTAssertEqual(v.x, 0, accuracy: 1e-9)
        XCTAssertEqual(v.y, -5, accuracy: 1e-9)
    }

    func testWindVectorFromEastBlowsWest() {
        let v = SoundSpeedModel.windVectorENU(speed: 5, fromDirectionDegrees: 90)
        XCTAssertEqual(v.x, -5, accuracy: 1e-9)
        XCTAssertEqual(v.y, 0, accuracy: 1e-9)
    }

    func testEffectiveSpeedAddsAlongPathWind() {
        // Wind blowing toward north (from the south, 180 deg) along a burst->observer
        // path that points north should add exactly the wind speed.
        let wind = SoundSpeedModel.windVectorENU(speed: 4, fromDirectionDegrees: 180)
        let dry = model.drySpeed(temperatureCelsius: 20)
        let effective = model.effectiveSpeed(
            temperatureCelsius: 20,
            relativeHumidity: 0,
            pressureHPa: 1013.25,
            windENU: wind,
            pathUnitBurstToObserver: Vector3(0, 1, 0)
        )
        XCTAssertEqual(effective - dry, 4, accuracy: 1e-6)
    }
}
