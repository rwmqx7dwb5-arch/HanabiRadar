import XCTest
@testable import HanabiCapture

final class EchoPairingTests: XCTestCase {

    private func transient(_ t: Double, energy: Double, confidence: Double = 0.8, echo: Double = 0) -> AudioTransientCandidate {
        AudioTransientCandidate(
            onsetTime: CaptureTimestamp(seconds: t),
            peakTime: CaptureTimestamp(seconds: t),
            peakEnergy: energy,
            transientConfidence: confidence,
            echoProbability: echo
        )
    }

    private func flash(_ t: Double, confidence: Double = 0.9) -> FlashCandidate {
        FlashCandidate(
            onsetTime: CaptureTimestamp(seconds: t),
            peakTime: CaptureTimestamp(seconds: t),
            centroid: NormalizedPoint(x: 0.5, y: 0.5),
            peakLuminance: 0.9,
            brightArea: 0.05,
            visualConfidence: confidence,
            atFrameEdge: false
        )
    }

    func testEchoGetsHighProbability() {
        let direct = transient(10.0, energy: 0.8)
        let echo = transient(10.3, energy: 0.3)
        let annotated = EchoDetector().annotate([echo, direct])   // unsorted input
        // Sorted by time: direct first, echo second.
        XCTAssertEqual(annotated[0].peakTime.seconds, 10.0, accuracy: 1e-9)
        XCTAssertLessThan(annotated[0].echoProbability, 0.01)
        XCTAssertGreaterThan(annotated[1].echoProbability, 0.5)
    }

    func testTwoSeparateBangsAreNotEchoes() {
        let first = transient(10.0, energy: 0.8)
        let second = transient(15.0, energy: 0.8)   // far apart, equally loud
        let annotated = EchoDetector().annotate([first, second])
        XCTAssertLessThan(annotated[0].echoProbability, 0.01)
        XCTAssertLessThan(annotated[1].echoProbability, 0.01)
    }

    func testPairingPicksBestAndKeepsAlternatives() {
        let source = flash(5.0, confidence: 0.9)
        let good = transient(9.8, energy: 0.8, confidence: 0.85, echo: 0)     // dt 4.8
        let echoey = transient(11.1, energy: 0.3, confidence: 0.5, echo: 0.7) // dt 6.1

        let bursts = EventPairingEngine().pair(flashes: [source], audio: [good, echoey])
        XCTAssertEqual(bursts.count, 1)
        XCTAssertEqual(bursts[0].best.audio, good)
        XCTAssertEqual(bursts[0].best.deltaT, 4.8, accuracy: 1e-9)
        XCTAssertGreaterThan(bursts[0].best.pairingConfidence, 0.7)
        XCTAssertEqual(bursts[0].alternatives.count, 1)
        XCTAssertEqual(bursts[0].alternatives[0].audio, echoey)
    }

    func testAudioTooSoonIsNotPaired() {
        let source = flash(5.0)
        let tooSoon = transient(5.1, energy: 0.8)   // dt 0.1 < minDeltaT
        XCTAssertTrue(EventPairingEngine().pair(flashes: [source], audio: [tooSoon]).isEmpty)
    }

    func testManualOverride() {
        let source = flash(5.0)
        let chosen = transient(11.1, energy: 0.3, confidence: 0.5, echo: 0.7)
        let pairing = EventPairingEngine().override(flash: source, with: chosen)
        XCTAssertEqual(pairing.audio, chosen)
        XCTAssertTrue(pairing.isUserCorrected)
        XCTAssertEqual(pairing.deltaT, 6.1, accuracy: 1e-9)
    }
}
