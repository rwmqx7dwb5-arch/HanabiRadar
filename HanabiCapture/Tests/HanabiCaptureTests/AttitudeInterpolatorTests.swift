import XCTest
import Foundation
import HanabiCore
@testable import HanabiCapture

final class AttitudeInterpolatorTests: XCTestCase {

    private let before = Timed(time: CaptureTimestamp(seconds: 0), value: Quaternion.identity)
    private let after = Timed(
        time: CaptureTimestamp(seconds: 2),
        value: Quaternion(axis: Vector3(0, 0, 1), angle: .pi / 2)
    )

    func testHalfwayIsFortyFiveDegrees() {
        let q = AttitudeInterpolator.attitude(at: CaptureTimestamp(seconds: 1), before: before, after: after)
        let r = q!.act(on: Vector3(1, 0, 0))
        XCTAssertEqual(r.x, cos(Double.pi / 4), accuracy: 1e-6)
        XCTAssertEqual(r.y, sin(Double.pi / 4), accuracy: 1e-6)
        XCTAssertEqual(r.z, 0, accuracy: 1e-6)
    }

    func testClampBeyondAfter() {
        let q = AttitudeInterpolator.attitude(at: CaptureTimestamp(seconds: 5), before: before, after: after)
        let r = q!.act(on: Vector3(1, 0, 0))
        XCTAssertEqual(r.x, 0, accuracy: 1e-6)
        XCTAssertEqual(r.y, 1, accuracy: 1e-6)
    }

    func testClampBeforeBefore() {
        let q = AttitudeInterpolator.attitude(at: CaptureTimestamp(seconds: -3), before: before, after: after)
        let r = q!.act(on: Vector3(1, 0, 0))
        XCTAssertEqual(r.x, 1, accuracy: 1e-6)
        XCTAssertEqual(r.y, 0, accuracy: 1e-6)
    }

    func testSingleSidedAndEmpty() {
        XCTAssertNotNil(AttitudeInterpolator.attitude(at: CaptureTimestamp(seconds: 0), before: before, after: nil))
        XCTAssertNotNil(AttitudeInterpolator.attitude(at: CaptureTimestamp(seconds: 0), before: nil, after: after))
        XCTAssertNil(AttitudeInterpolator.attitude(at: CaptureTimestamp(seconds: 0), before: nil, after: nil))
    }
}
