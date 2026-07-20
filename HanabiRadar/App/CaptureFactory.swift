import HanabiCapture

/// Builds a `CaptureCoordinator` with either mock or real device services.
///
/// UI tests (and `-mock-sensors`) always get mocks, so the app runs in the Simulator
/// without permission prompts or hardware. Otherwise the concrete AVFoundation /
/// CoreMotion / CoreLocation services are used.
enum CaptureFactory {
    static func makeCoordinator(logger: StructuredLogging) -> CaptureCoordinator {
        if AppLaunch.useMockSensors {
            return CaptureCoordinator(
                capacity: 1800,               // ~30 s at 60 Hz
                camera: MockCameraCaptureService(),
                audio: MockAudioCaptureService(),
                motion: MockMotionCaptureService(),
                location: MockLocationCaptureService(),
                logger: logger
            )
        }
        return CaptureCoordinator(
            capacity: 1800,
            camera: DeviceCameraCaptureService(),
            audio: DeviceAudioCaptureService(),
            motion: DeviceMotionCaptureService(),
            location: DeviceLocationCaptureService(),
            logger: logger
        )
    }
}
