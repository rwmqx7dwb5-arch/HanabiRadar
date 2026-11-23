import XCTest
@testable import HanabiRadar

final class RecordedMeasurementTests: XCTestCase {

    func testSyntheticSampleRoundTripsThroughJSON() throws {
        let sample = RecordedMeasurement.syntheticSample()
        let decoded = try RecordedMeasurement.decode(sample.encoded())
        XCTAssertEqual(decoded, sample)
    }

    func testReplayRecoversKnownDistance() async throws {
        let decoded = try RecordedMeasurement.decode(RecordedMeasurement.syntheticSample().encoded())
        let result = await decoded.replay()
        let analysis = try XCTUnwrap(result)
        XCTAssertEqual(analysis.sightingCount, 1)
        XCTAssertEqual(analysis.estimate.lineOfSightDistance, 1800, accuracy: 2.0)
    }

    func testRejectsUnsupportedVersion() throws {
        var sample = RecordedMeasurement.syntheticSample()
        sample.version = 99
        let data = try sample.encoded()
        XCTAssertThrowsError(try RecordedMeasurement.decode(data)) { error in
            XCTAssertEqual(error as? RecordedMeasurement.LoadError, .unsupportedVersion(99))
        }
    }

    func testRejectsRecordingWithoutBang() throws {
        var sample = RecordedMeasurement.syntheticSample()
        sample.transients = []
        let data = try sample.encoded()
        XCTAssertThrowsError(try RecordedMeasurement.decode(data)) { error in
            XCTAssertEqual(error as? RecordedMeasurement.LoadError, .empty)
        }
    }

    func testRejectsGarbage() {
        XCTAssertThrowsError(try RecordedMeasurement.decode(Data("nope".utf8)))
    }

    func testLiveCaptureRebuildsTheSameRecording() {
        let sample = RecordedMeasurement.syntheticSample()
        let rebuilt = RecordedMeasurement.capture(
            flashes: sample.flashCandidates(), transients: sample.transientCandidates(),
            timeline: sample.timeline(), intrinsics: sample.cameraIntrinsics(),
            temperatureCelsius: sample.temperatureCelsius, note: sample.note
        )
        XCTAssertEqual(rebuilt, sample)
    }
}
