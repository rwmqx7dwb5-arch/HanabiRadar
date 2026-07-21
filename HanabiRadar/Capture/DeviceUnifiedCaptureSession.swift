import Foundation
import AVFoundation
import HanabiCore
import HanabiCapture

/// A single `AVCaptureSession` capturing BOTH video and audio, so both sample streams'
/// presentation timestamps come from one session clock (the unified time axis the
/// estimator relies on for flash-to-bang). `start`/`stop` complete asynchronously and
/// `stop` fully tears the session down.
///
/// Compile-verified on the iOS Simulator; runtime behavior needs a physical device.
/// Camera-intrinsics and audio-RMS extraction from the sample buffers are refined with
/// the detectors in the next increments.
final class DeviceUnifiedCaptureSession: NSObject, UnifiedCaptureBackend, CameraPreviewSource,
    @unchecked Sendable,
    AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let queue = DispatchQueue(label: "com.example.hanabiradar.capture")
    private let lock = NSLock()
    private var onEvent: (@Sendable (UnifiedEvent) -> Void)?
    private var resources: Set<CaptureResource> = []
    private var routeObserver: NSObjectProtocol?

    func start(_ onEvent: @escaping @Sendable (UnifiedEvent) -> Void) async throws {
        setHandler(onEvent)
        try configure()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                if !self.session.isRunning { self.session.startRunning() }
                continuation.resume()
            }
        }
        insert(.session)
        addRouteObserver()
    }

    func stop() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                if self.session.isRunning { self.session.stopRunning() }
                self.session.beginConfiguration()
                self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
                self.audioOutput.setSampleBufferDelegate(nil, queue: nil)
                for output in self.session.outputs { self.session.removeOutput(output) }
                for input in self.session.inputs { self.session.removeInput(input) }
                self.session.commitConfiguration()
                continuation.resume()
            }
        }
        if let observer = routeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        routeObserver = nil
        setHandler(nil)
        clearResources()
    }

    func residualResources() async -> Set<CaptureResource> {
        lock.lock()
        defer { lock.unlock() }
        return resources
    }

    // MARK: - Preview

    /// Exposes the single `AVCaptureSession` so a preview layer can render the live feed.
    /// The session instance is stable across start/stop, so the layer stays attached; it
    /// simply shows frames once the session is running.
    var previewSession: AVCaptureSession? { session }

    // MARK: - Helpers (lock-guarded shared state)

    private func setHandler(_ handler: (@Sendable (UnifiedEvent) -> Void)?) {
        lock.lock(); onEvent = handler; lock.unlock()
    }

    private func insert(_ resource: CaptureResource) {
        lock.lock(); resources.insert(resource); lock.unlock()
    }

    private func clearResources() {
        lock.lock(); resources.removeAll(); lock.unlock()
    }

    private func emit(_ event: UnifiedEvent) {
        lock.lock(); let handler = onEvent; lock.unlock()
        handler?(event)
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(videoInput) else {
            throw CaptureError.unavailable("camera")
        }
        session.addInput(videoInput)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            insert(.videoOutput)
            insert(.videoDelegate)
        }
        if let connection = videoOutput.connection(with: .video),
           connection.isCameraIntrinsicMatrixDeliverySupported {
            connection.isCameraIntrinsicMatrixDeliveryEnabled = true
        }

        if let microphone = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: microphone),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
            audioOutput.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(audioOutput) {
                session.addOutput(audioOutput)
                insert(.audioOutput)
                insert(.audioDelegate)
            }
        }
    }

    private func addRouteObserver() {
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let input = AVAudioSession.sharedInstance().currentRoute.inputs.first
            let route = AudioRoute(
                portName: input?.portName ?? "unknown",
                isBuiltIn: input?.portType == .builtInMic
            )
            self.emit(.routeChange(
                AudioRouteChange(route: route, reason: "routeChange"),
                CaptureTimestamp(seconds: UptimeClock.now())
            ))
        }
    }

    // Both video and audio arrive here on the shared session clock.
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let seconds = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        let time = CaptureTimestamp(seconds: seconds)
        if output === videoOutput {
            let intrinsics = CameraIntrinsics(fx: 0, fy: 0, cx: 0, cy: 0, width: 0, height: 0)
            emit(.sample(UnifiedSample(
                time: time,
                payload: .video(FrameMetadata(intrinsics: intrinsics, lensIdentifier: "wide", frameRate: 0))
            )))
        } else {
            emit(.sample(UnifiedSample(time: time, payload: .audio(level: 0))))
        }
    }
}
