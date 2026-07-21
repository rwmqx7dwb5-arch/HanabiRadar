import Foundation
import AVFoundation
import UIKit
import SwiftData
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

    /// The analysis result for the result sheet, `nil` when not showing one.
    @Published private(set) var analysis: SessionAnalyzer.Result?
    /// True while the Monte Carlo analysis runs.
    @Published private(set) var analyzing = false
    /// Drives a "couldn't detect a burst" alert; settable so the alert can dismiss it.
    @Published var analysisError = false
    /// True once the current result has been saved to history (disables the save button).
    @Published private(set) var saved = false
    /// Drives a "couldn't save" alert; settable so the alert can dismiss it.
    @Published var saveError = false

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
    private var sessionStartedAt = Date()
    private let logger: StructuredLogging = AppLogger()
    private let permissions: PermissionsReading
    private let purchaseService: PurchaseService

    init(
        permissions: PermissionsReading = CaptureFactory.makePermissionsService(),
        purchaseService: PurchaseService = StoreKitPurchaseService()
    ) {
        self.permissions = permissions
        self.purchaseService = purchaseService
    }

    /// Reads current sensor authorization and updates `capability`. Called on appear so a
    /// denial degrades the mode and shows guidance instead of leaving a dead screen.
    func assessPermissions() async {
        capability = await permissions.current().capability
    }

    func start() {
        resetDetection()
        sessionStartedAt = Date()
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

    /// Pairs the accumulated candidates into sightings and estimates the most confident
    /// burst (§ detection → estimation → result). Presents the result sheet, or raises the
    /// "couldn't detect a burst" alert when nothing pairs.
    func analyze() async {
        guard let coordinator, let intrinsics = latestIntrinsics else {
            analysisError = true
            return
        }
        analyzing = true
        saved = false
        let conditions = SessionAnalyzer.Conditions(
            weather: WeatherConditions(temperatureCelsius: 20),
            horizontalAccuracy: 10,
            verticalAccuracy: 15,
            headingAccuracyDegrees: 6,
            frameRate: 30
        )
        let result = await SessionAnalyzer().analyze(
            flashes: flashes, transients: transients,
            timeline: coordinator.timeline, intrinsics: intrinsics, conditions: conditions
        )
        analyzing = false
        if let result {
            analysis = result
        } else {
            analysisError = true
        }
    }

    /// Whether there is anything to analyze (both a flash and a bang were seen).
    var canAnalyze: Bool { flashCount > 0 && bangCount > 0 }

    func dismissResult() {
        analysis = nil
    }

    /// Persists the current result's session summary to history (§16.4). Retention follows
    /// the tier: premium is unlimited, free keeps the most recent few (§18). Idempotent per
    /// result (the button disables once saved).
    func save(context: ModelContext) async {
        guard let result = analysis, !saved else { return }
        let premium = await purchaseService.isPremium()
        let store = SessionStore(context: context, retentionLimit: premium ? nil : 3)
        let record = MeasurementSessionRecord.from(
            summary: result.summary,
            observer: result.observer,
            startedAt: sessionStartedAt,
            endedAt: Date(),
            deviceModel: UIDevice.current.model,
            appVersion: Self.appVersion
        )
        do {
            try store.save(record)
            saved = true
        } catch {
            saveError = true
        }
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
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
        saved = false
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
