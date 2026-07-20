import Foundation

/// Errors thrown when a hardware capture service cannot start.
enum CaptureError: Error {
    case unavailable(String)
}
