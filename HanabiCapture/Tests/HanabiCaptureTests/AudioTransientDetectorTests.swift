import XCTest
@testable import HanabiCapture

final class AudioTransientDetectorTests: XCTestCase {

    private func frame(
        _ t: Double,
        energy: Double,
        flux: Double,
        lowBand: Double,
        clip: Double = 0
    ) -> AudioFeatureFrame {
        AudioFeatureFrame(time: CaptureTimestamp(seconds: t), energy: energy, spectralFlux: flux, lowBandEnergy: lowBand, clippingFraction: clip)
    }

    private func floor(count: Int) -> [AudioFeatureFrame] {
        (0..<count).map { frame(Double($0), energy: 0.01, flux: 0.01, lowBand: 0.005) }
    }

    private func run(_ frames: [AudioFeatureFrame], config: AudioTransientDetectorConfig = AudioTransientDetectorConfig()) -> [AudioTransientCandidate] {
        let detector = AudioTransientDetector(config: config)
        return frames.compactMap { detector.process($0) }
    }

    func testDetectsBoomyTransient() {
        var frames = floor(count: 30)
        frames.append(frame(30, energy: 0.5, flux: 0.3, lowBand: 0.3))
        frames.append(frame(31, energy: 0.7, flux: 0.2, lowBand: 0.42))
        frames.append(frame(32, energy: 0.2, flux: 0.05, lowBand: 0.1))

        let candidates = run(frames)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].onsetTime.seconds, 30, accuracy: 1e-9)
        XCTAssertEqual(candidates[0].peakTime.seconds, 31, accuracy: 1e-9)
        XCTAssertGreaterThan(candidates[0].transientConfidence, 0.5)
        XCTAssertFalse(candidates[0].clippingDetected)
    }

    func testRejectsNonBoomyClap() {
        var frames = floor(count: 30)
        // Loud and sharp, but almost no low-frequency energy (handclap-like).
        frames.append(frame(30, energy: 0.5, flux: 0.4, lowBand: 0.02))
        frames.append(frame(31, energy: 0.2, flux: 0.05, lowBand: 0.01))
        XCTAssertTrue(run(frames).isEmpty)
    }

    func testRejectsGradualNonSharpRise() {
        var frames = floor(count: 30)
        var energy = 0.05
        for i in 30..<70 {
            frames.append(frame(Double(i), energy: energy, flux: 0.02, lowBand: energy * 0.5))
            energy += 0.01   // rises, but spectral flux stays low -> not a transient
        }
        XCTAssertTrue(run(frames).isEmpty)
    }

    func testFlagsClipping() {
        var frames = floor(count: 30)
        frames.append(frame(30, energy: 0.6, flux: 0.3, lowBand: 0.36, clip: 0.05))
        frames.append(frame(31, energy: 0.8, flux: 0.2, lowBand: 0.48, clip: 0.08))
        frames.append(frame(32, energy: 0.2, flux: 0.05, lowBand: 0.1))

        let candidates = run(frames)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertTrue(candidates[0].clippingDetected)
    }
}
