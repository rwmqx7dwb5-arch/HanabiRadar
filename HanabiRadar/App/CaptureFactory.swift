import HanabiCapture

/// Builds capture components with either mock or real device backends.
///
/// UI tests (and `-mock-sensors`) always get mocks, so the app runs in the Simulator
/// without permission prompts or hardware. Camera + audio are captured by a single
/// `AVCaptureSession` (unified controller); motion + location go through the coordinator.
enum CaptureFactory {
    static func makeUnifiedBackend() -> UnifiedCaptureBackend {
        if AppLaunch.useMockSensors {
            return MockUnifiedCaptureBackend()
        }
        return DeviceUnifiedCaptureSession()
    }

    static func makeUnifiedController() -> UnifiedCaptureController {
        UnifiedCaptureController(backend: makeUnifiedBackend())
    }

    /// Motion + location run through the coordinator; camera + audio are handled by the
    /// unified session, so the coordinator's AV slots use no-op mocks.
    static func makeMotionLocationCoordinator(logger: StructuredLogging) -> CaptureCoordinator {
        if AppLaunch.useMockSensors {
            return CaptureCoordinator(
                capacity: 1800,
                camera: MockCameraCaptureService(),
                audio: MockAudioCaptureService(),
                motion: MockMotionCaptureService(),
                location: MockLocationCaptureService(),
                logger: logger
            )
        }
        return CaptureCoordinator(
            capacity: 1800,
            camera: MockCameraCaptureService(),
            audio: MockAudioCaptureService(),
            motion: DeviceMotionCaptureService(),
            location: DeviceLocationCaptureService(),
            logger: logger
        )
    }
}
