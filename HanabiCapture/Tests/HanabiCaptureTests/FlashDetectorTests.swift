import XCTest
@testable import HanabiCapture

final class FlashDetectorTests: XCTestCase {

    private func frame(
        _ t: Double,
        peak: Double,
        mean: Double,
        area: Double,
        centroid: NormalizedPoint = NormalizedPoint(x: 0.5, y: 0.5),
        edge: Bool = false
    ) -> FrameLuminanceSample {
        FrameLuminanceSample(
            time: CaptureTimestamp(seconds: t),
            meanLuminance: mean,
            peakLuminance: peak,
            brightArea: area,
            brightCentroid: centroid,
            atFrameEdge: edge
        )
    }

    private func run(_ frames: [FrameLuminanceSample], config: FlashDetectorConfig = FlashDetectorConfig()) -> [FlashCandidate] {
        let detector = FlashDetector(config: config)
        return frames.compactMap { detector.process($0) }
    }

    func testDetectsLocalizedFlash() {
        var frames: [FrameLuminanceSample] = []
        for i in 0..<15 { frames.append(frame(Double(i), peak: 0.2, mean: 0.1, area: 0.02)) }
        frames.append(frame(15, peak: 0.7, mean: 0.12, area: 0.05, centroid: NormalizedPoint(x: 0.6, y: 0.4)))
        frames.append(frame(16, peak: 0.9, mean: 0.13, area: 0.06, centroid: NormalizedPoint(x: 0.61, y: 0.39)))
        frames.append(frame(17, peak: 0.6, mean: 0.11, area: 0.04))
        frames.append(frame(18, peak: 0.3, mean: 0.10, area: 0.02))

        let candidates = run(frames)
        XCTAssertEqual(candidates.count, 1)
        let flash = candidates[0]
        XCTAssertEqual(flash.onsetTime.seconds, 15, accuracy: 1e-9)
        XCTAssertEqual(flash.peakTime.seconds, 16, accuracy: 1e-9)
        XCTAssertEqual(flash.centroid.x, 0.61, accuracy: 1e-9)
        XCTAssertEqual(flash.centroid.y, 0.39, accuracy: 1e-9)
        XCTAssertGreaterThan(flash.visualConfidence, 0.7)
        XCTAssertFalse(flash.atFrameEdge)
    }

    func testRejectsGlobalExposureChange() {
        var frames: [FrameLuminanceSample] = []
        for i in 0..<15 { frames.append(frame(Double(i), peak: 0.2, mean: 0.1, area: 0.02)) }
        // Whole frame brightens uniformly (mean rises with peak, large area).
        for i in 15..<25 { frames.append(frame(Double(i), peak: 0.7, mean: 0.55, area: 0.7)) }

        XCTAssertTrue(run(frames).isEmpty)
    }

    func testRejectsGradualRamp() {
        var frames: [FrameLuminanceSample] = []
        var peak = 0.2
        for i in 0..<40 {
            frames.append(frame(Double(i), peak: peak, mean: 0.1, area: 0.02))
            peak += 0.01   // slow ramp; baseline follows, so peak-over-baseline stays small
        }
        XCTAssertTrue(run(frames).isEmpty)
    }

    func testEdgeFlashIsKeptButDownWeighted() {
        var edgeFrames: [FrameLuminanceSample] = []
        for i in 0..<15 { edgeFrames.append(frame(Double(i), peak: 0.2, mean: 0.1, area: 0.02)) }
        edgeFrames.append(frame(15, peak: 0.9, mean: 0.12, area: 0.05, edge: true))
        edgeFrames.append(frame(16, peak: 0.5, mean: 0.10, area: 0.03, edge: true))

        var centerFrames: [FrameLuminanceSample] = []
        for i in 0..<15 { centerFrames.append(frame(Double(i), peak: 0.2, mean: 0.1, area: 0.02)) }
        centerFrames.append(frame(15, peak: 0.9, mean: 0.12, area: 0.05, edge: false))
        centerFrames.append(frame(16, peak: 0.5, mean: 0.10, area: 0.03, edge: false))

        let edge = run(edgeFrames)
        let center = run(centerFrames)
        XCTAssertEqual(edge.count, 1)
        XCTAssertEqual(center.count, 1)
        XCTAssertTrue(edge[0].atFrameEdge)
        XCTAssertLessThan(edge[0].visualConfidence, center[0].visualConfidence)
    }
}
