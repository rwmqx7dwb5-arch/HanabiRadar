import XCTest
import HanabiCore
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

    func testDistanceLineShowsInterval() {
        let line = Formatting.distanceLine(median: 1840, low95: 1770, high95: 1910, metric: true)
        XCTAssertEqual(line, "1.84 km（1.77 km–1.91 km）")
    }

    func testCoordinatePrecisionGatesDecimals() {
        let coord = GeodeticCoordinate(latitude: 35.6812345, longitude: 139.7678912)
        XCTAssertEqual(Formatting.coordinate(coord, precision: .fine), "35.68123, 139.76789")   // 5 dp
        XCTAssertEqual(Formatting.coordinate(coord, precision: .coarse), "35.681, 139.768")      // 3 dp
        XCTAssertEqual(Formatting.coordinate(coord, precision: .areaOnly), "35.68, 139.77")       // 2 dp
    }

    private func verticalEstimate(iterations: Int, ground: Double? = nil) -> BurstEstimate {
        let est = BurstSolver().estimate(
            observer: GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 30),
            enuRay: Vector3(0, 0, 1),
            deltaT: 1,
            effectiveSoundSpeed: 340,
            iterations: iterations
        )
        guard let ground else { return est }
        return est.applyingGroundElevation(ElevationSample(elevation: ground, source: "t"))
    }

    func testHeightLineWithGroundClaimsAboveGround() {
        let line = Formatting.heightLine(estimate: verticalEstimate(iterations: 1, ground: 20), metric: true)
        XCTAssertTrue(line.contains("地上高約"))
        XCTAssertTrue(line.contains("海抜約"))
        XCTAssertFalse(line.contains("標高データなし"))
    }

    func testHeightLineWithoutGroundWithholdsAboveGround() {
        let line = Formatting.heightLine(estimate: verticalEstimate(iterations: 1), metric: true)
        XCTAssertTrue(line.contains("標高データなし"))
        XCTAssertTrue(line.contains("観測点から +"))
        XCTAssertFalse(line.contains("地上高約"))
    }

    func testWeatherPartialNote() {
        XCTAssertEqual(Formatting.weatherPartialNote(estimate: verticalEstimate(iterations: 0)), "気象補正: 一部未適用")
        XCTAssertNil(Formatting.weatherPartialNote(estimate: verticalEstimate(iterations: 2)))
    }

    func testConfidenceAndFactorLabels() {
        XCTAssertEqual(Formatting.confidenceLabel(.high), "高")
        XCTAssertEqual(Formatting.confidenceLabel(.medium), "中")
        XCTAssertEqual(Formatting.confidenceLabel(.low), "低")
        XCTAssertEqual(Formatting.dominantFactorLabel(.heading), "方位精度")
        XCTAssertEqual(Formatting.dominantFactorLabel(.timeDifference), "時間差")
        XCTAssertEqual(Formatting.dominantFactorLabel(.gpsVertical), "GPS垂直精度")
    }
}
