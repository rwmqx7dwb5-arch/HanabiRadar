import XCTest
@testable import HanabiRadar

final class SessionExportShareTests: XCTestCase {

    private func record() -> MeasurementSessionRecord {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return MeasurementSessionRecord(
            startedAt: base, endedAt: base.addingTimeInterval(600),
            latitude: 35.681, longitude: 139.767, deviceModel: "iPhone",
            appVersion: "0.1", calculationVersion: "t",
            burstCount: 3, usedBurstCount: 2,
            representativeDistanceMeters: 1500, representativeAltitudeMeters: 300,
            launchClusterCount: 1, largestClusterRadiusMeters: 80
        )
    }

    func testFileNamesUseUTCDateAndExtension() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)   // 2023-11-14 22:13:20 UTC
        XCTAssertEqual(SessionExportFormat.csv.fileName(date: date), "hanabi-radar-sessions-20231114.csv")
        XCTAssertEqual(SessionExportFormat.geojson.fileName(date: date), "hanabi-radar-sessions-20231114.geojson")
    }

    func testEveryFormatRendersNonEmpty() throws {
        for format in SessionExportFormat.allCases {
            let file = try XCTUnwrap(SessionExportFile(format: format, records: [record()]))
            XCTAssertFalse(file.contents.isEmpty, format.title)
        }
    }

    func testCSVHasHeaderPlusOneRow() throws {
        let file = try XCTUnwrap(SessionExportFile(format: .csv, records: [record()]))
        XCTAssertEqual(file.contents.split(separator: "\n").count, 2)
    }

    func testGeoJSONIsLonLat() throws {
        let file = try XCTUnwrap(SessionExportFile(format: .geojson, records: [record()]))
        XCTAssertTrue(file.contents.contains("FeatureCollection"))
        let lon = file.contents.range(of: "139.767")
        let lat = file.contents.range(of: "35.681")
        XCTAssertNotNil(lon); XCTAssertNotNil(lat)
        XCTAssertLessThan(lon!.lowerBound, lat!.lowerBound)
    }
}
