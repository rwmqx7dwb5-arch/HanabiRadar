import HanabiCore

/// Shared mock base: records start/stop calls and can be made to fail on start. Mocks
/// are part of the library so the app (UI-test mode) and tests share them.
public class MockCaptureService {
    public weak var sink: CaptureSink?
    public private(set) var isRunning = false
    public private(set) var startCount = 0
    public private(set) var stopCount = 0
    public var startError: Error?

    public init() {}

    public func start() throws {
        startCount += 1
        if let error = startError { throw error }
        isRunning = true
    }

    public func stop() {
        stopCount += 1
        isRunning = false
    }
}

public final class MockCameraCaptureService: MockCaptureService, CameraCaptureService {}

public final class MockMotionCaptureService: MockCaptureService, MotionCaptureService {
    public func emit(attitude: Quaternion, at time: CaptureTimestamp) {
        sink?.ingest(attitude: Timed(time: time, value: attitude))
    }
}

public final class MockLocationCaptureService: MockCaptureService, LocationCaptureService {
    public func emit(location: LocationSample, at time: CaptureTimestamp) {
        sink?.ingest(location: Timed(time: time, value: location))
    }

    public func emit(heading: HeadingSample, at time: CaptureTimestamp) {
        sink?.ingest(heading: Timed(time: time, value: heading))
    }
}

public final class MockAudioCaptureService: MockCaptureService, AudioCaptureService {
    public func emit(audioLevel: Double, at time: CaptureTimestamp) {
        sink?.ingest(audioLevel: Timed(time: time, value: audioLevel))
    }

    public func emit(routeChange: AudioRouteChange, at time: CaptureTimestamp) {
        sink?.ingest(routeChange: routeChange, at: time)
    }
}
