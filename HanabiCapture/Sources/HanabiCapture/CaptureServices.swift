import HanabiCore

/// Receives timed sensor samples from the capture services. The `CaptureCoordinator`
/// is the concrete sink; it funnels samples into the `SynchronizedTimeline`.
public protocol CaptureSink: AnyObject {
    func ingest(attitude: Timed<Quaternion>)
    func ingest(location: Timed<LocationSample>)
    func ingest(heading: Timed<HeadingSample>)
    func ingest(audioLevel: Timed<Double>)
    func ingest(routeChange: AudioRouteChange, at time: CaptureTimestamp)
}

/// A startable/stoppable capture source that delivers samples to its `sink`.
/// Concrete AVFoundation/CoreMotion/CoreLocation implementations live in the app target
/// and conform to the specific protocols below; the pure package provides protocols and
/// mocks so the coordinator, replay, and tests need no hardware.
public protocol CaptureService: AnyObject {
    var isRunning: Bool { get }
    var sink: CaptureSink? { get set }
    func start() throws
    func stop()
}

public protocol CameraCaptureService: CaptureService {}
public protocol AudioCaptureService: CaptureService {}
public protocol MotionCaptureService: CaptureService {}
public protocol LocationCaptureService: CaptureService {}
