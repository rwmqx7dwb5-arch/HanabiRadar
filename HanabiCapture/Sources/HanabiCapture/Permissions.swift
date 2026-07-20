/// Authorization status for a single protected sensor.
public enum PermissionStatus: Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case authorized

    public var isUsable: Bool { self == .authorized }
}

/// What measurement is possible given the current permissions. Denials degrade
/// gracefully instead of blocking the app (see the app's permission-denied handling).
public enum MeasurementCapability: Sendable, Equatable {
    /// All sensors authorized: full 3D estimate.
    case full
    /// No microphone: direction only, no distance.
    case directionOnly
    /// No location: observer position must be set manually.
    case manualLocation
    /// No motion: orientation must be entered manually.
    case limitedOrientation
    /// No camera: measurement is not possible.
    case unavailable
}

/// Aggregated sensor permissions and the capability they imply.
public struct SensorPermissions: Sendable, Equatable {
    public var camera: PermissionStatus
    public var microphone: PermissionStatus
    public var location: PermissionStatus
    public var motion: PermissionStatus

    public init(
        camera: PermissionStatus = .notDetermined,
        microphone: PermissionStatus = .notDetermined,
        location: PermissionStatus = .notDetermined,
        motion: PermissionStatus = .notDetermined
    ) {
        self.camera = camera
        self.microphone = microphone
        self.location = location
        self.motion = motion
    }

    public var allAuthorized: Bool {
        camera.isUsable && microphone.isUsable && location.isUsable && motion.isUsable
    }

    /// The best measurement mode available. Camera is essential; other denials degrade.
    public var capability: MeasurementCapability {
        if !camera.isUsable { return .unavailable }
        if !motion.isUsable { return .limitedOrientation }
        if !microphone.isUsable { return .directionOnly }
        if !location.isUsable { return .manualLocation }
        return .full
    }
}
