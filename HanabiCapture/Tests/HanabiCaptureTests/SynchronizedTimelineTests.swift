import XCTest
import Foundation
import HanabiCore
@testable import HanabiCapture

final class SynchronizedTimelineTests: XCTestCase {

    func testAttitudeInterpolation() {
        var timeline = SynchronizedTimeline(capacity: 100)
        timeline.recordAttitude(.identity, at: CaptureTimestamp(seconds: 0))
        timeline.recordAttitude(
            Quaternion(axis: Vector3(0, 0, 1), angle: .pi / 2),
            at: CaptureTimestamp(seconds: 2)
        )
        let q = timeline.interpolatedAttitude(at: CaptureTimestamp(seconds: 1))
        let r = q!.act(on: Vector3(1, 0, 0))
        XCTAssertEqual(r.x, cos(Double.pi / 4), accuracy: 1e-6)
        XCTAssertEqual(r.y, sin(Double.pi / 4), accuracy: 1e-6)
    }

    func testNearestLocationWithLag() {
        var timeline = SynchronizedTimeline(capacity: 100)
        let a = LocationSample(
            coordinate: GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 0),
            horizontalAccuracy: 5, verticalAccuracy: 8
        )
        let b = LocationSample(
            coordinate: GeodeticCoordinate(latitude: 36, longitude: 140, altitude: 0),
            horizontalAccuracy: 5, verticalAccuracy: 8
        )
        timeline.recordLocation(a, at: CaptureTimestamp(seconds: 0))
        timeline.recordLocation(b, at: CaptureTimestamp(seconds: 10))

        let near = timeline.nearestLocation(at: CaptureTimestamp(seconds: 2))
        XCTAssertEqual(near?.sample, a)
        XCTAssertEqual(near?.lagSeconds ?? -1, 2, accuracy: 1e-9)

        let near2 = timeline.nearestLocation(at: CaptureTimestamp(seconds: 8))
        XCTAssertEqual(near2?.sample, b)
        XCTAssertEqual(near2?.lagSeconds ?? -1, 2, accuracy: 1e-9)
    }

    func testHeadingAndPrune() {
        var timeline = SynchronizedTimeline(capacity: 100)
        timeline.recordHeading(HeadingSample(trueHeadingDegrees: 90, accuracyDegrees: 3), at: CaptureTimestamp(seconds: 0))
        timeline.recordHeading(HeadingSample(trueHeadingDegrees: 100, accuracyDegrees: 3), at: CaptureTimestamp(seconds: 5))

        XCTAssertEqual(timeline.nearestHeading(at: CaptureTimestamp(seconds: 4))?.sample.trueHeadingDegrees, 100)

        timeline.prune(olderThan: CaptureTimestamp(seconds: 3))
        XCTAssertEqual(timeline.heading.count, 1)
        XCTAssertEqual(timeline.heading.oldest?.time.seconds, 5)
    }
}
