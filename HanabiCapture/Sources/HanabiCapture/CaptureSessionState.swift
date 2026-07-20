/// Lifecycle state of a capture session.
public enum CaptureSessionState: Sendable, Equatable {
    case idle
    case starting
    case running
    case stopping
    case failed(String)
}
