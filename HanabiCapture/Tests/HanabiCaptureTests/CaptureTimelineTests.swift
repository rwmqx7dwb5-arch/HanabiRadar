import XCTest
@testable import HanabiCapture

final class CaptureTimelineTests: XCTestCase {

    func testComparable() {
        XCTAssertLessThan(CaptureTimestamp(seconds: 1), CaptureTimestamp(seconds: 2))
    }

    func testNormalizeOffset() {
        let normalizer = TimelineNormalizer(offsetSeconds: 5)
        XCTAssertEqual(normalizer.normalize(sourceSeconds: 10).seconds, 15, accuracy: 1e-12)
    }

    func testCalibrated() {
        let normalizer = TimelineNormalizer.calibrated(sourceReference: 100, commonReference: 250)
        XCTAssertEqual(normalizer.offsetSeconds, 150, accuracy: 1e-12)
        XCTAssertEqual(normalizer.normalize(sourceSeconds: 110).seconds, 260, accuracy: 1e-12)
    }
}
