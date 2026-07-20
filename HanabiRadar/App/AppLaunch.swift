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
}
