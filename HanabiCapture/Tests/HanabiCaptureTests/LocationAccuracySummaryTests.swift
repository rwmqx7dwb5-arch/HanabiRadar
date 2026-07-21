import XCTest
import Foundation
import HanabiCore
@testable import HanabiCapture

final class LocationAccuracySummaryTests: XCTestCase {

    private func sample(_ horizontal: Double, _ vertical: Double) -> LocationSample {
        LocationSample(
            coordinate: GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 0),
            horizontalAccuracy: horizontal,
            verticalAccuracy: vertical
        )
    }

    func testEmptyTimelineReturnsNil() {
        let timeline = SynchronizedTimeline(capacity: 10)
        XCTAssertNil(timeline.locationAccuracySummary())
    }

    func testMedianOfOddCount() {
        var timeline = SynchronizedTimeline(capacity: 10)
        for (index, value) in [10.0, 4.0, 22.0].enumerated() {
            timeline.recordLocation(sample(value, value * 2), at: CaptureTimestamp(seconds: Double(index)))
        }
        let summary = timeline.locationAccuracySummary()
        XCTAssertEqual(summary?.horizontal ?? -1, 10, accuracy: 1e-9)
        XCTAssertEqual(summary?.vertical ?? -1, 20, accuracy: 1e-9)
    }

    func testMedianOfEvenCountAveragesMiddlePair() {
        var timeline = SynchronizedTimeline(capacity: 10)
        for (index, value) in [4.0, 8.0, 12.0, 100.0].enumerated() {
            timeline.recordLocation(sample(value, value), at: CaptureTimestamp(seconds: Double(index)))
        }
        // Median of [4, 8, 12, 100] is (8 + 12) / 2 = 10.
        XCTAssertEqual(timeline.locationAccuracySummary()?.horizontal ?? -1, 10, accuracy: 1e-9)
    }

    func testInvalidHorizontalFixesAreIgnored() {
        var timeline = SynchronizedTimeline(capacity: 10)
        // A negative horizontalAccuracy marks an invalid Core Location fix; it must not
        // drag the representative accuracy toward an absurd value.
        timeline.recordLocation(sample(-1, -1), at: CaptureTimestamp(seconds: 0))
        timeline.recordLocation(sample(6, 9), at: CaptureTimestamp(seconds: 1))
        timeline.recordLocation(sample(8, 11), at: CaptureTimestamp(seconds: 2))
        let summary = timeline.locationAccuracySummary()
        XCTAssertEqual(summary?.horizontal ?? -1, 7, accuracy: 1e-9)   // median of [6, 8]
        XCTAssertEqual(summary?.vertical ?? -1, 10, accuracy: 1e-9)    // median of [9, 11]
    }

    func testAllInvalidHorizontalReturnsNil() {
        var timeline = SynchronizedTimeline(capacity: 10)
        timeline.recordLocation(sample(-1, -1), at: CaptureTimestamp(seconds: 0))
        timeline.recordLocation(sample(0, 0), at: CaptureTimestamp(seconds: 1))
        XCTAssertNil(timeline.locationAccuracySummary())
    }

    func testValidHorizontalButInvalidVerticalFallsBackToRatio() {
        var timeline = SynchronizedTimeline(capacity: 10)
        // Core Location can return a valid horizontal fix with an invalid (negative)
        // vertical accuracy; the vertical sigma then falls back to 1.5× the horizontal.
        timeline.recordLocation(sample(12, -1), at: CaptureTimestamp(seconds: 0))
        let summary = timeline.locationAccuracySummary()
        XCTAssertEqual(summary?.horizontal ?? -1, 12, accuracy: 1e-9)
        XCTAssertEqual(summary?.vertical ?? -1, 18, accuracy: 1e-9)
    }
}
