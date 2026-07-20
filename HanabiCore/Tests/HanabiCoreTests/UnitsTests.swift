import XCTest
@testable import HanabiCore

final class UnitsTests: XCTestCase {

    func testTemperature() {
        XCTAssertEqual(Units.celsiusToFahrenheit(0), 32, accuracy: 1e-9)
        XCTAssertEqual(Units.celsiusToFahrenheit(100), 212, accuracy: 1e-9)
        XCTAssertEqual(Units.fahrenheitToCelsius(32), 0, accuracy: 1e-9)
        XCTAssertEqual(Units.celsiusToKelvin(0), 273.15, accuracy: 1e-9)
    }

    func testDistance() {
        XCTAssertEqual(Units.metersToFeet(0.3048), 1, accuracy: 1e-9)
        XCTAssertEqual(Units.feetToMeters(1), 0.3048, accuracy: 1e-9)
        XCTAssertEqual(Units.kilometersToMiles(1.609344), 1, accuracy: 1e-9)
        XCTAssertEqual(Units.milesToKilometers(1), 1.609344, accuracy: 1e-9)
    }
}
