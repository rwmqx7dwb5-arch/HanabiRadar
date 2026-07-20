import XCTest
import Foundation
@testable import HanabiCore

final class CalibrationAssessorTests: XCTestCase {

    private let assessor = CalibrationAssessor()

    /// A snapshot where everything is comfortably good.
    private func good() -> SensorQuality {
        SensorQuality(
            horizontalAccuracyMeters: 8,
            headingAccuracyDegrees: 5,
            hasAttitude: true,
            hasCameraIntrinsics: true,
            frameRate: 60,
            audioInputLevel: 0.3,
            audioRouteIsBuiltIn: true
        )
    }

    func testReadyWhenAllGood() {
        let r = assessor.assess(good())
        XCTAssertEqual(r.quality, .ready)
        XCTAssertTrue(r.issues.isEmpty)
    }

    func testMarginalHorizontalDegrades() {
        var q = good(); q.horizontalAccuracyMeters = 30      // between good(15) and max(50)
        let r = assessor.assess(q)
        XCTAssertEqual(r.quality, .degraded)
        XCTAssertEqual(r.issues, [.poorHorizontalAccuracy])
    }

    func testPoorHorizontalBlocks() {
        var q = good(); q.horizontalAccuracyMeters = 80      // beyond max(50)
        let r = assessor.assess(q)
        XCTAssertEqual(r.quality, .blocked)
        XCTAssertTrue(r.issues.contains(.poorHorizontalAccuracy))
    }

    func testLocationUnavailableBlocks() {
        var q = good(); q.horizontalAccuracyMeters = nil
        let r = assessor.assess(q)
        XCTAssertEqual(r.quality, .blocked)
        XCTAssertTrue(r.issues.contains(.locationUnavailable))
    }

    func testHeadingUnavailableOrInvalidBlocks() {
        var missing = good(); missing.headingAccuracyDegrees = nil
        XCTAssertEqual(assessor.assess(missing).quality, .blocked)
        XCTAssertTrue(assessor.assess(missing).issues.contains(.headingUnavailable))

        var invalid = good(); invalid.headingAccuracyDegrees = -1   // Core Location invalid sentinel
        XCTAssertTrue(assessor.assess(invalid).issues.contains(.headingUnavailable))
    }

    func testHeadingDegradesThenBlocks() {
        var marginal = good(); marginal.headingAccuracyDegrees = 15  // >10 good, <=25 max
        XCTAssertEqual(assessor.assess(marginal).quality, .degraded)
        XCTAssertEqual(assessor.assess(marginal).issues, [.poorHeadingAccuracy])

        var poor = good(); poor.headingAccuracyDegrees = 30          // >25 max
        XCTAssertEqual(assessor.assess(poor).quality, .blocked)
        XCTAssertTrue(assessor.assess(poor).issues.contains(.poorHeadingAccuracy))
    }

    func testAttitudeMissingBlocks() {
        var q = good(); q.hasAttitude = false
        let r = assessor.assess(q)
        XCTAssertEqual(r.quality, .blocked)
        XCTAssertTrue(r.issues.contains(.attitudeUnavailable))
    }

    func testSoftProblemsDegrade() {
        var noIntrinsics = good(); noIntrinsics.hasCameraIntrinsics = false
        XCTAssertEqual(assessor.assess(noIntrinsics).quality, .degraded)
        XCTAssertEqual(assessor.assess(noIntrinsics).issues, [.cameraIntrinsicsUnavailable])

        var lowFps = good(); lowFps.frameRate = 24
        XCTAssertEqual(assessor.assess(lowFps).issues, [.lowFrameRate])

        var noAudio = good(); noAudio.audioInputLevel = 0
        XCTAssertEqual(assessor.assess(noAudio).issues, [.noAudioInput])

        var extMic = good(); extMic.audioRouteIsBuiltIn = false
        XCTAssertEqual(assessor.assess(extMic).issues, [.externalMicrophone])
    }

    func testUnknownAudioLevelIsNotPenalized() {
        var q = good(); q.audioInputLevel = nil
        XCTAssertEqual(assessor.assess(q).quality, .ready)
    }

    func testBlockingIssuesComeBeforeDegrading() {
        var q = good()
        q.horizontalAccuracyMeters = 30     // degrading
        q.hasAttitude = false               // blocking
        let r = assessor.assess(q)
        XCTAssertEqual(r.quality, .blocked)
        XCTAssertEqual(r.issues.first, .attitudeUnavailable)
        XCTAssertTrue(r.issues.contains(.poorHorizontalAccuracy))
    }

    func testCustomThresholds() {
        var q = good(); q.horizontalAccuracyMeters = 20
        // Default: 20 > good(15) -> degraded. Loosen good to 25 -> ready.
        let loose = CalibrationAssessor.Thresholds(goodHorizontalAccuracyMeters: 25)
        XCTAssertEqual(assessor.assess(q, thresholds: loose).quality, .ready)
    }
}
