/// The active audio input route.
public struct AudioRoute: Sendable, Equatable {
    public var portName: String
    public var isBuiltIn: Bool

    public init(portName: String, isBuiltIn: Bool) {
        self.portName = portName
        self.isBuiltIn = isBuiltIn
    }

    /// Non-built-in routes (AirPods, Bluetooth, external mics) degrade timing accuracy
    /// and should warn the user; the built-in mic is recommended for measurement.
    public var warrantsWarning: Bool { !isBuiltIn }
}

/// A change of audio input route. During an active measurement this invalidates the
/// in-flight event, because the microphone position/latency changed.
public struct AudioRouteChange: Sendable, Equatable {
    public var route: AudioRoute
    public var reason: String

    public init(route: AudioRoute, reason: String) {
        self.route = route
        self.reason = reason
    }
}
