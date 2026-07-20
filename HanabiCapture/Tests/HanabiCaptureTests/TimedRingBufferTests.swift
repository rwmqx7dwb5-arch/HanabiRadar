import XCTest
@testable import HanabiCapture

final class TimedRingBufferTests: XCTestCase {

    private func buffer(times: [Double], capacity: Int) -> TimedRingBuffer<Int> {
        var buffer = TimedRingBuffer<Int>(capacity: capacity)
        for (index, time) in times.enumerated() {
            buffer.append(Timed(time: CaptureTimestamp(seconds: time), value: index))
        }
        return buffer
    }

    func testAppendWithinCapacity() {
        let buffer = buffer(times: [0, 1, 2], capacity: 5)
        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer.oldest?.value, 0)
        XCTAssertEqual(buffer.newest?.value, 2)
        XCTAssertEqual(buffer.orderedItems.map { $0.value }, [0, 1, 2])
    }

    func testOverwriteOldestWhenFull() {
        let buffer = buffer(times: [0, 1, 2, 3], capacity: 3)
        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer.orderedItems.map { $0.time.seconds }, [1, 2, 3])
        XCTAssertEqual(buffer.oldest?.time.seconds, 1)
        XCTAssertEqual(buffer.newest?.time.seconds, 3)
    }

    func testBracketing() {
        let buffer = buffer(times: [0, 1, 2, 3, 4], capacity: 8)

        let mid = buffer.bracketing(CaptureTimestamp(seconds: 2.5))
        XCTAssertEqual(mid.before?.time.seconds, 2)
        XCTAssertEqual(mid.after?.time.seconds, 3)

        let exact = buffer.bracketing(CaptureTimestamp(seconds: 2))
        XCTAssertEqual(exact.before?.time.seconds, 2)
        XCTAssertEqual(exact.after?.time.seconds, 2)

        let low = buffer.bracketing(CaptureTimestamp(seconds: -1))
        XCTAssertNil(low.before)
        XCTAssertEqual(low.after?.time.seconds, 0)

        let high = buffer.bracketing(CaptureTimestamp(seconds: 5))
        XCTAssertEqual(high.before?.time.seconds, 4)
        XCTAssertNil(high.after)
    }

    func testBracketingAfterWrap() {
        let buffer = buffer(times: [0, 1, 2, 3, 4, 5], capacity: 3)   // holds 3, 4, 5
        XCTAssertEqual(buffer.orderedItems.map { $0.time.seconds }, [3, 4, 5])
        let mid = buffer.bracketing(CaptureTimestamp(seconds: 4.5))
        XCTAssertEqual(mid.before?.time.seconds, 4)
        XCTAssertEqual(mid.after?.time.seconds, 5)
    }

    func testPrune() {
        var buffer = buffer(times: [0, 1, 2, 3, 4], capacity: 8)
        buffer.prune(olderThan: CaptureTimestamp(seconds: 2))
        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer.oldest?.time.seconds, 2)
    }
}
