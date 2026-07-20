import HanabiCore

/// Owns the capture services, funnels their samples into the `SynchronizedTimeline`, and
/// guarantees that stopping a session releases every service — including when only some
/// services started before a failure.
public final class CaptureCoordinator: CaptureSink {
    public private(set) var state: CaptureSessionState = .idle
    public private(set) var timeline: SynchronizedTimeline
    public private(set) var lastRouteChange: AudioRouteChange?
    public private(set) var lastAudioLevel: Timed<Double>?
    /// True when an audio-route change happened while running: the in-flight event is invalid.
    public private(set) var routeInvalidatedMeasurement = false

    private let camera: CameraCaptureService
    private let audio: AudioCaptureService
    private let motion: MotionCaptureService
    private let location: LocationCaptureService
    private let logger: StructuredLogging

    public init(
        capacity: Int,
        camera: CameraCaptureService,
        audio: AudioCaptureService,
        motion: MotionCaptureService,
        location: LocationCaptureService,
        logger: StructuredLogging
    ) {
        self.timeline = SynchronizedTimeline(capacity: capacity)
        self.camera = camera
        self.audio = audio
        self.motion = motion
        self.location = location
        self.logger = logger
        camera.sink = self
        audio.sink = self
        motion.sink = self
        location.sink = self
    }

    public func start() {
        guard state == .idle || isFailed else { return }
        state = .starting
        routeInvalidatedMeasurement = false
        do {
            try camera.start()
            try audio.start()
            try motion.start()
            try location.start()
            state = .running
            logger.log(LogEvent(level: .info, category: "session", message: "started"))
        } catch {
            // Ensure a partial start is fully torn down before reporting failure.
            stop()
            state = .failed(String(describing: error))
            logger.log(LogEvent(level: .error, category: "session", message: "start failed"))
        }
    }

    /// Idempotent: always releases every service, whatever the prior state.
    public func stop() {
        camera.stop()
        audio.stop()
        motion.stop()
        location.stop()
        state = .idle
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    // MARK: - CaptureSink

    public func ingest(attitude: Timed<Quaternion>) {
        timeline.recordAttitude(attitude.value, at: attitude.time)
    }

    public func ingest(location sample: Timed<LocationSample>) {
        timeline.recordLocation(sample.value, at: sample.time)
    }

    public func ingest(heading sample: Timed<HeadingSample>) {
        timeline.recordHeading(sample.value, at: sample.time)
    }

    public func ingest(audioLevel: Timed<Double>) {
        lastAudioLevel = audioLevel
    }

    public func ingest(routeChange: AudioRouteChange, at time: CaptureTimestamp) {
        lastRouteChange = routeChange
        if state == .running { routeInvalidatedMeasurement = true }
        let level: LogLevel = routeChange.route.warrantsWarning ? .warning : .info
        logger.log(LogEvent(level: level, category: "audio", message: "route changed: \(routeChange.route.portName)"))
    }
}
