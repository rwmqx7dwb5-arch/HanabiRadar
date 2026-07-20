/// A resource held by a running unified capture session. After `stop()` completes,
/// none of these may remain — verified in tests via the backend's residual set.
public enum CaptureResource: Sendable, Hashable {
    case session
    case videoOutput
    case audioOutput
    case videoDelegate
    case audioDelegate
    case audioTap
    case task
}
