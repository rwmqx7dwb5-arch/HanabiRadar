import XCTest
import SwiftData
@testable import HanabiRadar

final class SessionExporterTests: XCTestCase {

    private func record(lat: Double = 35.681, lon: Double = 139.767, distance: Double? = 1840) -> MeasurementSessionRecord {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        return MeasurementSessionRecord(
            startedAt: start, endedAt: start.addingTimeInterval(600),
            latitude: lat, longitude: lon, deviceModel: "iPhone", appVersion: "0.1",
            calculationVersion: "0.1.0", burstCount: 12, usedBurstCount: 10,
            representativeDistanceMeters: distance, representativeAltitudeMeters: 320,
            launchClusterCount: 1, largestClusterRadiusMeters: 95
        )
    }

    // MARK: CSV

    func testCSVHasHeaderAndRowPerRecord() {
        let csv = SessionExporter.csv([record(), record(lat: 34.70, lon: 135.50)])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        XCTAssertEqual(lines.count, 3)   // header + 2 rows
        XCTAssertTrue(lines[0].hasPrefix("id,startedAt,endedAt,latitude,longitude"))
        XCTAssertTrue(lines[1].contains("35.681000"))
        XCTAssertTrue(lines[1].contains("139.767000"))
        XCTAssertTrue(lines[1].contains("1840.00"))
        XCTAssertTrue(lines[2].contains("34.700000"))
    }

    func testCSVEmptyIsHeaderOnly() {
        let lines = SessionExporter.csv([]).split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 1)
    }

    // MARK: JSON

    private struct TestSession: Decodable {
        let id: String
        let latitude: Double
        let longitude: Double
        let burstCount: Int
        let representativeDistanceMeters: Double?
        let calculationVersion: String
    }

    func testJSONEncodesAllRecords() throws {
        let json = try SessionExporter.json([record(), record(lat: 1, lon: 2, distance: nil)])
        let decoded = try JSONDecoder().decode([TestSession].self, from: Data(json.utf8))
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].latitude, 35.681, accuracy: 1e-9)
        XCTAssertEqual(decoded[0].burstCount, 12)
        XCTAssertEqual(decoded[0].calculationVersion, "0.1.0")
        XCTAssertNil(decoded[1].representativeDistanceMeters)   // nil distance omitted/null
    }

    func testJSONEmptyIsEmptyArray() throws {
        let json = try SessionExporter.json([])
        XCTAssertEqual(try JSONDecoder().decode([TestSession].self, from: Data(json.utf8)).count, 0)
    }

    // MARK: GeoJSON

    private struct TestFC: Decodable {
        let type: String
        let features: [TestFeature]
    }
    private struct TestFeature: Decodable {
        let type: String
        let geometry: TestGeom
        let properties: TestSession
    }
    private struct TestGeom: Decodable {
        let type: String
        let coordinates: [Double]
    }

    func testGeoJSONUsesLonLatOrder() throws {
        let json = try SessionExporter.geoJSON([record(lat: 35.681, lon: 139.767)])
        let fc = try JSONDecoder().decode(TestFC.self, from: Data(json.utf8))
        XCTAssertEqual(fc.type, "FeatureCollection")
        XCTAssertEqual(fc.features.count, 1)
        XCTAssertEqual(fc.features[0].type, "Feature")
        XCTAssertEqual(fc.features[0].geometry.type, "Point")
        XCTAssertEqual(fc.features[0].geometry.coordinates.count, 2)
        XCTAssertEqual(fc.features[0].geometry.coordinates[0], 139.767, accuracy: 1e-9)   // longitude first
        XCTAssertEqual(fc.features[0].geometry.coordinates[1], 35.681, accuracy: 1e-9)    // then latitude
        XCTAssertEqual(fc.features[0].properties.burstCount, 12)
    }
}
