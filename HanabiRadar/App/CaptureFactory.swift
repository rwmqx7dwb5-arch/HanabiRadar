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

    /// Reads sensor authorization. UI tests / `-mock-sensors` get a static reader (all
    /// authorized, so the measurement screen isn't gated); a `-force-mic-denied` UI test
    /// injects a denial to exercise the degraded-mode banner. Real builds probe the OS.
    static func makePermissionsService() -> PermissionsReading {
        if AppLaunch.useMockSensors {
            if AppLaunch.forceMicrophoneDenied {
                return StaticPermissionsService(SensorPermissions(
                    camera: .authorized, microphone: .denied, location: .authorized, motion: .authorized
                ))
            }
            return StaticPermissionsService()
        }
        return DevicePermissionsService()
    }
}
