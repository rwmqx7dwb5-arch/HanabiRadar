import XCTest
@testable import HanabiRadar

final class FormattingTests: XCTestCase {

    func testMetricMeters() {
        XCTAssertEqual(Formatting.distance(meters: 840, metric: true), "840 m")
    }

    func testMetricKilometers() {
        XCTAssertEqual(Formatting.distance(meters: 1840, metric: true), "1.84 km")
    }

    func testImperialFeet() {
        XCTAssertEqual(Formatting.distance(meters: 100, metric: false), "328 ft")
    }

    func testDemoEstimateProducesText() {
        XCTAssertFalse(DemoEstimate.compute().isEmpty)
    }
}
