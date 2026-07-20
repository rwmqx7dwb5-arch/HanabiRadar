import HanabiCore

/// The payload of a unified capture sample.
public enum UnifiedSamplePayload: Sendable {
    case video(FrameMetadata)
    case audio(level: Double)
}

/// A video or audio sample. Its `time` is on the shared capture-session clock, so a
/// video (flash) time and an audio (bang) time are directly comparable — that single
/// axis is what unifying camera + audio into ONE `AVCaptureSession` guarantees.
public struct UnifiedSample: Sendable {
    public var time: CaptureTimestamp
    public var payload: UnifiedSamplePayload

    public init(time: CaptureTimestamp, payload: UnifiedSamplePayload) {
        self.time = time
        self.payload = payload
    }

    public var isVideo: Bool {
        if case .video = payload { return true }
        return false
    }

    public var isAudio: Bool {
        if case .audio = payload { return true }
        return false
    }
}

/// An event emitted by a unified capture backend.
public enum UnifiedEvent: Sendable {
    case sample(UnifiedSample)
    case routeChange(AudioRouteChange, CaptureTimestamp)
}

/// The single-`AVCaptureSession` capture backend. Video and audio come from ONE session,
/// so their sample presentation timestamps share one clock. `start`/`stop` complete
/// asynchronously; after `stop()` returns, no resources remain.
public protocol UnifiedCaptureBackend: AnyObject, Sendable {
    func start(_ onEvent: @escaping @Sendable (UnifiedEvent) -> Void) async throws
    func stop() async
    func residualResources() async -> Set<CaptureResource>
}

/// Drives a `UnifiedCaptureBackend` with an awaitable lifecycle and exposes the residual
/// resources so teardown completeness can be verified.
public actor UnifiedCaptureController {
    public private(set) var isRunning = false
    private let backend: UnifiedCaptureBackend

    public init(backend: UnifiedCaptureBackend) {
        self.backend = backend
    }

    public func start(_ onEvent: @escaping @Sendable (UnifiedEvent) -> Void) async throws {
        guard !isRunning else { return }
        try await backend.start(onEvent)
        isRunning = true
    }

    public func stop() async {
        await backend.stop()
        isRunning = false
    }

    /// Resources still held by the backend. Empty once `stop()` has completed.
    public func residualResources() async -> Set<CaptureResource> {
        await backend.residualResources()
    }
}
