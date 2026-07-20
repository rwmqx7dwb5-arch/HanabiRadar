import OSLog
import HanabiCapture

/// Routes structured capture logs to OSLog. Never logs precise location or raw audio.
final class AppLogger: StructuredLogging {
    private let logger = Logger(subsystem: "com.example.hanabiradar", category: "capture")

    func log(_ event: LogEvent) {
        let line = "[\(event.category)] \(event.message)"
        switch event.level {
        case .debug: logger.debug("\(line, privacy: .public)")
        case .info: logger.info("\(line, privacy: .public)")
        case .warning: logger.warning("\(line, privacy: .public)")
        case .error: logger.error("\(line, privacy: .public)")
        }
    }
}
