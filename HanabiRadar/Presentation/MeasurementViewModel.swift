import Foundation
import AVFoundation
import HanabiCore
import HanabiCapture

/// Drives the measurement screen. Camera + audio are captured by one AVCaptureSession
/// (the unified controller, async start/stop); motion + location run through the
/// coordinator. Everything is released on `stop`.
@MainActor
final class MeasurementViewModel: ObservableObject {
    @Published private(set) var captureState = String(localized: "準備中")
    @Published private(set) var videoFrames = 0
    @Published private(set) var audioSamples = 0
    /// Peak luminance (0...1) of the most recent video frame, extracted live. A visible
    /// signal that real luminance features are flowing (the flash detector reads the same).
    @Published private(set) var latestPeakLuminance = 0.0
    /// Short-time energy of the most recent audio window, extracted live — a visible signal
    /// that real audio features are flowing (the bang detector reads the same).
    @Published private(set) var latestAudioEnergy = 0.0
    @Published private(set) var attitudeCount = 0
    @Published private(set) var locationCount = 0
    /// The best measurement mode the current permissions allow (§21); drives the banner.
    @Published private(set) var capability: MeasurementCapability = .full
    /// The live capture session for on-screen preview, or `nil` on the Simulator / mock
    /// backend (no camera), where the view draws a placeholder instead.
    @Published private(set) var previewSession: AVCaptureSession?

    /// Flashes detected so far this session, and a token that ticks on each new one so the
    /// view can pulse a live indicator.
    @Published private(set) var flashCount = 0
    @Published private(set) var flashEventID = 0
    /// Bangs (audio transients) detected so far, with the same live-pulse token.
    @Published private(set) var bangCount = 0
    @Published private(set) var bangEventID = 0

    private var backend: UnifiedCaptureBackend?
    private var controller: UnifiedCaptureController?
    private var coordinator: CaptureCoordinator?
    // Streaming detectors + the candidates/intrinsics accumulated for end-of-session
    // pairing and estimation (wired in the next increment). Recreated each `start`.
    private var flashDetector = FlashDetector()
    private var audioDetector = AudioTransientDetector()
    private var flashes: [FlashCandidate] = []
    private var transients: [AudioTransientCandidate] = []
    private var latestIntrinsics: CameraIntrinsics?
    private let logger: StructuredLogging = AppLogger()
    private let permissions: PermissionsReading

    init(permissions: PermissionsReading = CaptureFactory.makePermissionsService()) {
        self.permissions = permissions
    }

    /// Reads current sensor authorization and updates `capability`. Called on appear so a
    /// denial degrades the mode and shows guidance instead of leaving a dead screen.
    func assessPermissions() async {
        capability = await permissions.current().capability
    }

    func start() {
        resetDetection()
        let coordinator = CaptureFactory.makeMotionLocationCoordinator(logger: logger)
        self.coordinator = coordinator
        coordinator.start()
        if AppLaunch.useMockSensors {
            seedMockMotionLocation(coordinator)
        }

        let backend = CaptureFactory.makeUnifiedBackend()
        self.backend = backend
        self.previewSession = (backend as? CameraPreviewSource)?.previewSession
        let controller = UnifiedCaptureController(backend: backend)
        self.controller = controller
        captureState = String(localized: "開始中")
        Task { @MainActor [weak self] in
            guard let self, let controller = self.controller else { return }
            do {
                try await controller.start { [weak self] event in
                    Task { @MainActor in self?.handle(event) }
                }
                self.captureState = String(localized: "測定可能")
            } catch {
                self.captureState = String(localized: "エラー")
            }
        }
        refreshMotionLocation()
    }

    func stop() {
        coordinator?.stop()
        coordinator = nil
        let controller = self.controller
        self.controller = nil
        self.backend = nil
        previewSession = nil
        captureState = String(localized: "停止")
        Task { await controller?.stop() }
        refreshMotionLocation()
    }

    private func handle(_ event: UnifiedEvent) {
        guard case .sample(let sample) = event else { return }
        switch sample.payload {
        case .video(let luminance, let metadata):
            videoFrames += 1
            latestPeakLuminance = luminance.peakLuminance
            latestIntrinsics = metadata.intrinsics
            if let flash = flashDetector.process(luminance) {
                flashes.append(flash)
                flashCount = flashes.count
                flashEventID += 1
            }
        case .audio(let features):
            audioSamples += 1
            latestAudioEnergy = features.energy
            if let transient = audioDetector.process(features) {
                transients.append(transient)
                bangCount = transients.count
                bangEventID += 1
            }
        }
    }

    /// Fresh detectors and empty accumulators for a new measurement session.
    private func resetDetection() {
        flashDetector = FlashDetector()
        audioDetector = AudioTransientDetector()
        flashes.removeAll()
        transients.removeAll()
        latestIntrinsics = nil
        flashCount = 0
        bangCount = 0
        flashEventID = 0
        bangEventID = 0
    }

    private func seedMockMotionLocation(_ coordinator: CaptureCoordinator) {
        coordinator.ingest(attitude: Timed(time: CaptureTimestamp(seconds: 0), value: .identity))
        coordinator.ingest(location: Timed(
            time: CaptureTimestamp(seconds: 0),
            value: LocationSample(
                coordinate: GeodeticCoordinate(latitude: 35.681, longitude: 139.767, altitude: 30),
                horizontalAccuracy: 8,
                verticalAccuracy: 12
            )
        ))
    }

    private func refreshMotionLocation() {
        attitudeCount = coordinator?.timeline.attitude.count ?? 0
        locationCount = coordinator?.timeline.location.count ?? 0
    }
}
