import XCTest
import SwiftData
import HanabiCore
@testable import HanabiRadar

@MainActor
final class SessionStoreTests: XCTestCase {

    private func makeStore(limit: Int?) throws -> SessionStore {
        let container = try ModelContainer(
            for: MeasurementSessionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SessionStore(context: ModelContext(container), retentionLimit: limit)
    }

    private func record(day: Int, distance: Double? = 1000) -> MeasurementSessionRecord {
        let start = Date(timeIntervalSince1970: Double(day) * 86_400)
        return MeasurementSessionRecord(
            startedAt: start, endedAt: start.addingTimeInterval(600),
            latitude: 35, longitude: 139, deviceModel: "test", appVersion: "0.1",
            calculationVersion: "0.1.0", burstCount: 5, usedBurstCount: 4,
            representativeDistanceMeters: distance, representativeAltitudeMeters: 300,
            launchClusterCount: 1, largestClusterRadiusMeters: 90
        )
    }

    private func days(_ records: [MeasurementSessionRecord]) -> [Int] {
        records.map { Int(($0.startedAt.timeIntervalSince1970 / 86_400).rounded()) }
    }

    func testSaveAndFetchNewestFirst() throws {
        let store = try makeStore(limit: nil)
        try store.save(record(day: 1))
        try store.save(record(day: 3))
        try store.save(record(day: 2))
        XCTAssertEqual(days(try store.allSessions()), [3, 2, 1])
    }

    func testDeleteRemovesRecord() throws {
        let store = try makeStore(limit: nil)
        let first = record(day: 1)
        try store.save(first)
        try store.save(record(day: 2))
        try store.delete(first)
        XCTAssertEqual(days(try store.allSessions()), [2])
    }

    func testFreeTierRetentionTrimsOldest() throws {
        let store = try makeStore(limit: 3)
        for day in 1...5 { try store.save(record(day: day)) }
        XCTAssertEqual(days(try store.allSessions()), [5, 4, 3])   // 3 newest kept
    }

    func testUnlimitedRetentionKeepsAll() throws {
        let store = try makeStore(limit: nil)
        for day in 1...5 { try store.save(record(day: day)) }
        XCTAssertEqual(try store.allSessions().count, 5)
    }

    func testDeleteAll() throws {
        let store = try makeStore(limit: nil)
        for day in 1...3 { try store.save(record(day: day)) }
        try store.deleteAll()
        XCTAssertTrue(try store.allSessions().isEmpty)
    }

    func testFromSummaryMapsFields() {
        let summary = SessionSummary(
            clusters: [LaunchCluster(
                memberIDs: ["a", "b"],
                center: GeodeticCoordinate(latitude: 35, longitude: 139),
                confidenceRadiusMeters: 95, eventCount: 2, confidence: 0.7
            )],
            burstCount: 6, usedBurstCount: 5, clusteredBurstCount: 2,
            representativeDistance: 1800, representativeAltitude: 250
        )
        let start = Date(timeIntervalSince1970: 1000)
        let rec = MeasurementSessionRecord.from(
            summary: summary,
            observer: GeodeticCoordinate(latitude: 35.5, longitude: 139.5),
            startedAt: start, endedAt: start.addingTimeInterval(300),
            deviceModel: "iPhone", appVersion: "0.1"
        )
        XCTAssertEqual(rec.burstCount, 6)
        XCTAssertEqual(rec.usedBurstCount, 5)
        XCTAssertEqual(rec.representativeDistanceMeters, 1800)
        XCTAssertEqual(rec.representativeAltitudeMeters, 250)
        XCTAssertEqual(rec.launchClusterCount, 1)
        XCTAssertEqual(rec.largestClusterRadiusMeters, 95)
        XCTAssertEqual(rec.latitude, 35.5, accuracy: 1e-9)
        XCTAssertEqual(rec.calculationVersion, CoreInfo.calculationVersion)
    }
}
