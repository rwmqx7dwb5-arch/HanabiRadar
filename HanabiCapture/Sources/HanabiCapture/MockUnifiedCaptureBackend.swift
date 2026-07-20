import Foundation

/// In-memory unified capture backend for tests and the Simulator. Acquires every
/// resource category a real session would (so teardown coverage is exercised) and lets
/// tests emit same-axis samples.
public final class MockUnifiedCaptureBackend: UnifiedCaptureBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var resources: Set<CaptureResource> = []
    private var onEvent: (@Sendable (UnifiedEvent) -> Void)?

    public init() {}

    public func start(_ onEvent: @escaping @Sendable (UnifiedEvent) -> Void) async throws {
        lock.lock()
        self.onEvent = onEvent
        resources = [.session, .videoOutput, .audioOutput, .videoDelegate, .audioDelegate, .audioTap, .task]
        lock.unlock()
    }

    public func stop() async {
        lock.lock()
        onEvent = nil
        resources = []
        lock.unlock()
    }

    public func residualResources() async -> Set<CaptureResource> {
        lock.lock()
        defer { lock.unlock() }
        return resources
    }

    /// Emits an event on the shared session axis (test helper).
    public func emit(_ event: UnifiedEvent) {
        lock.lock()
        let handler = onEvent
        lock.unlock()
        handler?(event)
    }
}
