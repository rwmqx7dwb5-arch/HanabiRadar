import XCTest
@testable import HanabiCapture

final class LoggingTests: XCTestCase {

    func testInMemoryLoggerCollectsEvents() {
        let logger = InMemoryLogger()
        logger.log(LogEvent(level: .info, category: "session", message: "started"))
        logger.log(LogEvent(level: .error, category: "session", message: "boom"))
        XCTAssertEqual(logger.events.count, 2)
        XCTAssertEqual(logger.events[1].level, .error)
        XCTAssertEqual(logger.events[0].category, "session")
    }
}
