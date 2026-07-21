import Foundation

/// Launch-time configuration derived from process arguments / environment.
///
/// UI tests pass `-uitest` (and, in later increments, mock-selection flags) so the
/// app can run in the Simulator without triggering real permission prompts or
/// touching physical sensors.
enum AppLaunch {

    /// True when the app is launched by a UI test.
    static var isUITest: Bool {
        CommandLine.arguments.contains("-uitest")
            || ProcessInfo.processInfo.environment["UITEST_MODE"] == "1"
    }

    /// True when sensor access should be replaced by mocks (no permission prompts).
    /// Implied by UI-test mode; also settable explicitly for integration tests.
    static var useMockSensors: Bool {
        isUITest || CommandLine.arguments.contains("-mock-sensors")
    }

    /// UI-test hook: forces a microphone denial so the degraded-mode permission banner
    /// (§21) can be smoke-tested in the Simulator. Only honored with mock sensors.
    static var forceMicrophoneDenied: Bool {
        useMockSensors && CommandLine.arguments.contains("-force-mic-denied")
    }

    /// Whether the developer diagnostics entry (§23 self-test) is shown. Always on in DEBUG;
    /// in Release it's hidden from ordinary users unless a UI test or `-diagnostics` enables it.
    static var diagnosticsEnabled: Bool {
        #if DEBUG
        return true
        #else
        return isUITest || CommandLine.arguments.contains("-diagnostics")
        #endif
    }
}
