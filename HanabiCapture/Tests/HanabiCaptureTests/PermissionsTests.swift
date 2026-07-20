import XCTest
@testable import HanabiCapture

final class PermissionsTests: XCTestCase {

    func testFullWhenAllAuthorized() {
        let permissions = SensorPermissions(camera: .authorized, microphone: .authorized, location: .authorized, motion: .authorized)
        XCTAssertTrue(permissions.allAuthorized)
        XCTAssertEqual(permissions.capability, .full)
    }

    func testCameraDeniedIsUnavailable() {
        let permissions = SensorPermissions(camera: .denied, microphone: .authorized, location: .authorized, motion: .authorized)
        XCTAssertEqual(permissions.capability, .unavailable)
    }

    func testMotionDeniedIsLimitedOrientation() {
        let permissions = SensorPermissions(camera: .authorized, microphone: .authorized, location: .authorized, motion: .denied)
        XCTAssertEqual(permissions.capability, .limitedOrientation)
    }

    func testMicrophoneDeniedIsDirectionOnly() {
        let permissions = SensorPermissions(camera: .authorized, microphone: .denied, location: .authorized, motion: .authorized)
        XCTAssertEqual(permissions.capability, .directionOnly)
    }

    func testLocationDeniedIsManualLocation() {
        let permissions = SensorPermissions(camera: .authorized, microphone: .authorized, location: .denied, motion: .authorized)
        XCTAssertEqual(permissions.capability, .manualLocation)
    }
}
