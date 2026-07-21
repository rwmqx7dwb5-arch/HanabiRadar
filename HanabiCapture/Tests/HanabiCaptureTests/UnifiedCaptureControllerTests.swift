import XCTest
import Foundation
import HanabiCore
@testable import HanabiCapture

/// Thread-safe collector for the `@Sendable` event closure.
private final class EventCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [UnifiedEvent] = []

    func add(_ event: UnifiedEvent) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    func snapshot() -> [UnifiedEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

final class UnifiedCaptureControllerTests: XCTestCase {

    func testAwaitableStartStopTearsDownAllResources() async throws {
        let backend = MockUnifiedCaptureBackend()
        let controller = UnifiedCaptureController(backend: backend)

        var running = await controller.isRunning
        XCTAssertFalse(running)

        try await controller.start { _ in }
        running = await controller.isRunning
        XCTAssertTrue(running)
        let during = await controller.residualResources()
        XCTAssertFalse(during.isEmpty)

        await controller.stop()
        running = await controller.isRunning
        XCTAssertFalse(running)
        let after = await controller.residualResources()
        XCTAssertTrue(after.isEmpty, "No session/output/delegate/tap/task may remain after stop")
    }

    func testStopIsIdempotent() async throws {
        let backend = MockUnifiedCaptureBackend()
        let controller = UnifiedCaptureController(backend: backend)
        try await controller.start { _ in }
        await controller.stop()
        await controller.stop()
        let after = await controller.residualResources()
        XCTAssertTrue(after.isEmpty)
    }

    func testVideoAndAudioShareOneTimeAxis() async throws {
        // A flash (video) and its bang (audio) are stamped by the SAME session clock, so
        // the difference of their timestamps is a valid flash-to-bang delay.
        let backend = MockUnifiedCaptureBackend()
        let controller = UnifiedCaptureController(backend: backend)
        let collector = EventCollector()

        try await controller.start { event in collector.add(event) }

        let intrinsics = CameraIntrinsics(fx: 1600, fy: 1600, cx: 960, cy: 540, width: 1920, height: 1080)
        let luminance = FrameLuminanceSample(
            time: CaptureTimestamp(seconds: 10.0),
            meanLuminance: 0.1, peakLuminance: 0.8, brightArea: 0.03,
            brightCentroid: NormalizedPoint(x: 0.5, y: 0.5)
        )
        backend.emit(.sample(UnifiedSample(
            time: CaptureTimestamp(seconds: 10.0),
            payload: .video(luminance, metadata: FrameMetadata(intrinsics: intrinsics, lensIdentifier: "wide", frameRate: 60))
        )))
        backend.emit(.sample(UnifiedSample(
            time: CaptureTimestamp(seconds: 14.3),
            payload: .audio(AudioFeatureFrame(
                time: CaptureTimestamp(seconds: 14.3),
                energy: 0.9, spectralFlux: 0.3, lowBandEnergy: 0.5
            ))
        )))

        let events = collector.snapshot()
        let videoTime = events.compactMap { event -> Double? in
            if case .sample(let sample) = event, sample.isVideo { return sample.time.seconds }
            return nil
        }.first
        let audioTime = events.compactMap { event -> Double? in
            if case .sample(let sample) = event, sample.isAudio { return sample.time.seconds }
            return nil
        }.first

        XCTAssertNotNil(videoTime)
        XCTAssertNotNil(audioTime)
        XCTAssertEqual((audioTime ?? 0) - (videoTime ?? 0), 4.3, accuracy: 1e-9)

        await controller.stop()
    }
}
