import Foundation
import HanabiCore
import HanabiCapture

/// Drives the measurement screen. Owns a `CaptureCoordinator`, starts it on appear and
/// releases it on disappear. In mock mode it seeds a couple of samples so the skeleton
/// screen shows live-looking state without hardware.
@MainActor
final class MeasurementViewModel: ObservableObject {
    @Published private(set) var stateText = "準備中"
    @Published private(set) var attitudeCount = 0
    @Published private(set) var locationCount = 0

    private var coordinator: CaptureCoordinator?
    private let logger: StructuredLogging = AppLogger()

    func start() {
        let coordinator = CaptureFactory.makeCoordinator(logger: logger)
        self.coordinator = coordinator
        coordinator.start()
        if AppLaunch.useMockSensors {
            seedMockSamples(into: coordinator)
        }
        refresh()
    }

    func stop() {
        coordinator?.stop()
        coordinator = nil
        refresh()
    }

    private func seedMockSamples(into coordinator: CaptureCoordinator) {
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

    private func refresh() {
        guard let coordinator else {
            stateText = "停止"
            attitudeCount = 0
            locationCount = 0
            return
        }
        switch coordinator.state {
        case .running: stateText = "測定可能"
        case .starting: stateText = "準備中"
        case .stopping: stateText = "停止中"
        case .idle: stateText = "停止"
        case .failed: stateText = "エラー"
        }
        attitudeCount = coordinator.timeline.attitude.count
        locationCount = coordinator.timeline.location.count
    }
}
