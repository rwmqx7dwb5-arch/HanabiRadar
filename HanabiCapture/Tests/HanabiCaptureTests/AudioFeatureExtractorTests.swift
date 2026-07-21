import XCTest
import Foundation
@testable import HanabiCapture

final class RealFFTTests: XCTestCase {

    func testDCSignalConcentratesAtBinZero() {
        let mags = RealFFT.magnitudes([Double](repeating: 1.0, count: 8))
        XCTAssertEqual(mags.count, 4)
        XCTAssertEqual(mags[0], 1.0, accuracy: 1e-9)   // mean = 1
        for k in 1..<4 { XCTAssertEqual(mags[k], 0.0, accuracy: 1e-9) }
    }

    func testUnitCosinePeaksAtItsBin() {
        // cos(2π·i/8) is a pure tone at bin 1; a real unit cosine yields a half-amplitude peak.
        let n = 8
        let signal = (0..<n).map { cos(2.0 * Double.pi * Double($0) / Double(n)) }
        let mags = RealFFT.magnitudes(signal)
        XCTAssertEqual(mags[1], 0.5, accuracy: 1e-9)
        XCTAssertEqual(mags[0], 0.0, accuracy: 1e-9)
        XCTAssertEqual(mags[2], 0.0, accuracy: 1e-9)
        XCTAssertEqual(mags[3], 0.0, accuracy: 1e-9)
    }

    func testNonPowerOfTwoReturnsEmpty() {
        XCTAssertTrue(RealFFT.magnitudes([1, 2, 3, 4, 5]).isEmpty)
        XCTAssertTrue(RealFFT.magnitudes([1.0]).isEmpty)
    }
}

final class AudioFeatureExtractorTests: XCTestCase {

    // 6400 Hz / 64-sample window → 100 Hz per bin, 400 Hz cutoff at bin 4.
    // hopSize == windowSize keeps these feature tests on non-overlapping windows; the
    // overlap behavior is covered separately below.
    private let config = AudioFeatureExtractor.Config(
        sampleRate: 6_400, windowSize: 64, hopSize: 64, lowBandCutoffHz: 400, clippingThreshold: 0.98
    )

    private func tone(hz: Double, count: Int, amplitude: Float = 0.5) -> [Float] {
        (0..<count).map { Float(Double(amplitude) * sin(2.0 * Double.pi * hz * Double($0) / 6_400.0)) }
    }

    func testSilenceProducesZeroFeatures() {
        let ex = AudioFeatureExtractor(config: config)
        let frames = ex.process([Float](repeating: 0, count: 64), startTime: CaptureTimestamp(seconds: 0))
        XCTAssertEqual(frames.count, 1)
        let f = frames[0]
        XCTAssertEqual(f.energy, 0, accuracy: 1e-9)
        XCTAssertEqual(f.lowBandEnergy, 0, accuracy: 1e-9)
        XCTAssertEqual(f.spectralFlux, 0, accuracy: 1e-9)
        XCTAssertEqual(f.clippingFraction, 0, accuracy: 1e-9)
    }

    func testLowToneIsBoomy() {
        let ex = AudioFeatureExtractor(config: config)
        let f = ex.process(tone(hz: 100, count: 64), startTime: CaptureTimestamp(seconds: 0))[0]
        XCTAssertGreaterThan(f.energy, 0)
        let ratio = f.lowBandEnergy / f.energy
        XCTAssertGreaterThan(ratio, 0.9, "A 100 Hz tone should be almost entirely low-band")
    }

    func testHighToneIsNotBoomy() {
        let ex = AudioFeatureExtractor(config: config)
        let f = ex.process(tone(hz: 1_000, count: 64), startTime: CaptureTimestamp(seconds: 0))[0]
        XCTAssertGreaterThan(f.energy, 0)
        let ratio = f.lowBandEnergy / f.energy
        XCTAssertLessThan(ratio, 0.1, "A 1000 Hz tone should carry almost no low-band energy")
    }

    func testFluxRisesOnOnsetAndSettles() {
        let ex = AudioFeatureExtractor(config: config)
        // Frame 1: silence (establishes a zero baseline spectrum).
        _ = ex.process([Float](repeating: 0, count: 64), startTime: CaptureTimestamp(seconds: 0))
        // Frame 2: a tone appears — large positive spectral change.
        let onset = ex.process(tone(hz: 100, count: 64), startTime: CaptureTimestamp(seconds: 0.01))[0]
        XCTAssertGreaterThan(onset.spectralFlux, 0.5)
        // Frame 3: the same tone continues — little further change.
        let steady = ex.process(tone(hz: 100, count: 64), startTime: CaptureTimestamp(seconds: 0.02))[0]
        XCTAssertLessThan(steady.spectralFlux, 0.1)
    }

    func testClippingIsCounted() {
        let ex = AudioFeatureExtractor(config: config)
        let f = ex.process([Float](repeating: 1.0, count: 64), startTime: CaptureTimestamp(seconds: 0))[0]
        XCTAssertEqual(f.clippingFraction, 1.0, accuracy: 1e-9)
    }

    func testWindowingEmitsOneFramePerWindowAndBuffersRemainder() {
        let ex = AudioFeatureExtractor(config: config)
        // 200 samples → 3 full 64-sample windows (192), 8 buffered.
        let frames = ex.process([Float](repeating: 0, count: 200), startTime: CaptureTimestamp(seconds: 0))
        XCTAssertEqual(frames.count, 3)
        // A follow-up batch completes the next window using the buffered remainder.
        let more = ex.process([Float](repeating: 0, count: 56), startTime: CaptureTimestamp(seconds: 1))
        XCTAssertEqual(more.count, 1)
    }

    func testFrameTimestampsAdvanceByWindowDuration() {
        let ex = AudioFeatureExtractor(config: config)
        let frames = ex.process([Float](repeating: 0, count: 128), startTime: CaptureTimestamp(seconds: 5))
        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0].time.seconds, 5.0, accuracy: 1e-9)
        XCTAssertEqual(frames[1].time.seconds, 5.0 + 64.0 / 6_400.0, accuracy: 1e-9)  // +0.01 s
    }

    func testResetClearsBufferedRemainder() {
        let ex = AudioFeatureExtractor(config: config)
        _ = ex.process([Float](repeating: 0, count: 40), startTime: CaptureTimestamp(seconds: 0))  // buffered, no frame
        ex.reset()
        // After reset the 40 buffered samples are gone: 64 fresh samples make exactly one frame.
        let frames = ex.process([Float](repeating: 0, count: 64), startTime: CaptureTimestamp(seconds: 2))
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0].time.seconds, 2.0, accuracy: 1e-9)
    }
}

final class AudioFeatureExtractorOverlapTests: XCTestCase {

    // 6400 Hz / 64-sample window, 32-sample hop → 50% overlap, 5 ms frame period.
    private let config = AudioFeatureExtractor.Config(
        sampleRate: 6_400, windowSize: 64, hopSize: 32, lowBandCutoffHz: 400, clippingThreshold: 0.98
    )

    func testDefaultHopIsHalfWindow() {
        let auto = AudioFeatureExtractor.Config(sampleRate: 6_400, windowSize: 64)
        XCTAssertEqual(auto.hopSize, 32)
    }

    func testHopIsClampedToValidStride() {
        XCTAssertEqual(AudioFeatureExtractor.Config(windowSize: 64, hopSize: 999).hopSize, 64)  // no gaps
        XCTAssertEqual(AudioFeatureExtractor.Config(windowSize: 64, hopSize: 0).hopSize, 1)     // floored
    }

    func testOverlappingWindowsEmitMoreFramesAndAdvanceByHop() {
        let ex = AudioFeatureExtractor(config: config)
        // 128 samples span 2 non-overlapping windows but 3 at 50% overlap (starts 0, 32, 64).
        let frames = ex.process([Float](repeating: 0, count: 128), startTime: CaptureTimestamp(seconds: 0))
        XCTAssertEqual(frames.count, 3)
        XCTAssertEqual(frames[0].time.seconds, 0, accuracy: 1e-9)
        XCTAssertEqual(frames[1].time.seconds, 32.0 / 6_400.0, accuracy: 1e-9)  // +5 ms, half a window
        XCTAssertEqual(frames[2].time.seconds, 64.0 / 6_400.0, accuracy: 1e-9)
    }

    func testOverlapWindowingIsContinuousAcrossBatches() {
        let ex = AudioFeatureExtractor(config: config)
        // First batch yields one window; the 16 shared samples carry into the next window.
        let first = ex.process([Float](repeating: 0, count: 80), startTime: CaptureTimestamp(seconds: 0))
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first[0].time.seconds, 0, accuracy: 1e-9)
        // The next batch continues on the same hop grid (times anchored at the first sample).
        let second = ex.process([Float](repeating: 0, count: 48), startTime: CaptureTimestamp(seconds: 1))
        XCTAssertEqual(second.count, 2)
        XCTAssertEqual(second[0].time.seconds, 32.0 / 6_400.0, accuracy: 1e-9)
        XCTAssertEqual(second[1].time.seconds, 64.0 / 6_400.0, accuracy: 1e-9)
    }
}
