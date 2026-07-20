import AVFoundation
import AVFAudio
import CoreLocation
import CoreMotion
import HanabiCapture

/// Reads the current OS authorization status of each sensor, mapped to the core's
/// `SensorPermissions`. Abstracted behind a protocol so the UI and unit tests never
/// touch the real iOS authorization APIs (which don't behave in the test host).
protocol PermissionsReading: Sendable {
    func current() async -> SensorPermissions
}

/// Fixed permissions for previews / UI tests. Defaults to everything authorized so the
/// measurement flow is unobstructed when running in the Simulator with mock sensors.
struct StaticPermissionsService: PermissionsReading {
    let permissions: SensorPermissions

    init(_ permissions: SensorPermissions = SensorPermissions(
        camera: .authorized, microphone: .authorized, location: .authorized, motion: .authorized
    )) {
        self.permissions = permissions
    }

    func current() async -> SensorPermissions { permissions }
}

/// Reads live authorization status from the OS. Device attitude (Core Motion device
/// motion) needs no user permission, so `motion` reflects hardware availability rather
/// than a prompt. Every read is non-throwing and non-blocking, so a denial degrades the
/// capability instead of crashing (§21).
struct DevicePermissionsService: PermissionsReading {
    func current() async -> SensorPermissions {
        SensorPermissions(
            camera: Self.mapCamera(AVCaptureDevice.authorizationStatus(for: .video)),
            microphone: Self.mapMicrophone(AVAudioApplication.shared.recordPermission),
            location: Self.mapLocation(CLLocationManager().authorizationStatus),
            motion: CMMotionManager().isDeviceMotionAvailable ? .authorized : .denied
        )
    }

    static func mapCamera(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    static func mapMicrophone(_ status: AVAudioApplication.recordPermission) -> PermissionStatus {
        switch status {
        case .granted: return .authorized
        case .denied: return .denied
        case .undetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    static func mapLocation(_ status: CLAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }
}
