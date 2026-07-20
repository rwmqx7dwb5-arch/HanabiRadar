/// Severity of a structured log event.
public enum LogLevel: String, Sendable, Equatable {
    case debug
    case info
    case warning
    case error
}

/// A structured log event. Never carries precise location or raw audio (see the
/// security notes); it is a category + message pair with a level.
public struct LogEvent: Sendable, Equatable {
    public var level: LogLevel
    public var category: String
    public var message: String

    public init(level: LogLevel, category: String, message: String) {
        self.level = level
        self.category = category
        self.message = message
    }
}

/// A sink for structured logs. The app conforms this to OSLog; tests use `InMemoryLogger`.
public protocol StructuredLogging: AnyObject {
    func log(_ event: LogEvent)
}

/// Collects log events in memory for tests and diagnostics.
public final class InMemoryLogger: StructuredLogging {
    public private(set) var events: [LogEvent] = []

    public init() {}

    public func log(_ event: LogEvent) {
        events.append(event)
    }
}
