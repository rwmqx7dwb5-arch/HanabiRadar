import HanabiCapture

/// Builds a `CaptureCoordinator` with either mock or real device services.
///
/// UI tests (and `-mock-sensors`) always get mocks, so the app runs in the Simulator
/// without permission prompts or hardware. The concrete AVFoundation/CoreMotion/
/// CoreLocation services are wired into the `else` branch in the next increment.
enum CaptureFactory {
    static func makeCoordinator(logger: StructuredLogging) -> CaptureCoordinator {
        CaptureCoordinator(
            capacity: 1800,               // ~30 s at 60 Hz
            camera: MockCameraCaptureService(),
            audio: MockAudioCaptureService(),
            motion: MockMotionCaptureService(),
            location: MockLocationCaptureService(),
            logger: logger
        )
    }
}
