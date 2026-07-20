import Foundation
import HanabiCore
import HanabiCapture

/// Drives the measurement screen. Camera + audio are captured by one AVCaptureSession
/// (the unified controller, async start/stop); motion + location run through the
/// coordinator. Everything is released on `stop`.
@MainActor
final class MeasurementViewModel: ObservableObject {
    @Published private(set) var captureState = "準備中"
    @Published private(set) var videoFrames = 0
    @Published private(set) var audioSamples = 0
    @Published private(set) var attitudeCount = 0
    @Published private(set) var locationCount = 0

    private var controller: UnifiedCaptureController?
    private var coordinator: CaptureCoordinator?
    private let logger: StructuredLogging = AppLogger()

    func start() {
        let coordinator = CaptureFactory.makeMotionLocationCoordinator(logger: logger)
        self.coordinator = coordinator
        coordinator.start()
        if AppLaunch.useMockSensors {
            seedMockMotionLocation(coordinator)
        }

        let controller = CaptureFactory.makeUnifiedController()
        self.controller = controller
        captureState = "開始中"
        Task { @MainActor [weak self] in
            guard let self, let controller = self.controller else { return }
            do {
                try await controller.start { [weak self] event in
                    Task { @MainActor in self?.handle(event) }
                }
                self.captureState = "測定可能"
            } catch {
                self.captureState = "エラー"
            }
        }
        refreshMotionLocation()
    }

    func stop() {
        coordinator?.stop()
        coordinator = nil
        let controller = self.controller
        self.controller = nil
        captureState = "停止"
        Task { await controller?.stop() }
        refreshMotionLocation()
    }

    private func handle(_ event: UnifiedEvent) {
        guard case .sample(let sample) = event else { return }
        if sample.isVideo {
            videoFrames += 1
        } else if sample.isAudio {
            audioSamples += 1
        }
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
