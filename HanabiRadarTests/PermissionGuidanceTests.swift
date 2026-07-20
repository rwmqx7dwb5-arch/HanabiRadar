import XCTest
import HanabiCapture
@testable import HanabiRadar

/// The honesty of "what still works when a permission is denied" (§21) lives in pure
/// mappings, so it is unit-tested independently of any view or the OS.
final class PermissionGuidanceTests: XCTestCase {

    func testFullCapabilityShowsNoBanner() {
        XCTAssertNil(PermissionBanner.forCapability(.full))
    }

    func testEachDegradedCapabilityMapsToItsBanner() {
        XCTAssertEqual(PermissionBanner.forCapability(.unavailable), .cameraRequired)
        XCTAssertEqual(PermissionBanner.forCapability(.directionOnly), .microphoneDenied)
        XCTAssertEqual(PermissionBanner.forCapability(.manualLocation), .locationDenied)
        XCTAssertEqual(PermissionBanner.forCapability(.limitedOrientation), .motionUnavailable)
    }

    func testSettingsOfferedForPermissionDenialsButNotHardware() {
        XCTAssertTrue(PermissionBanner.cameraRequired.offersSettings)
        XCTAssertTrue(PermissionBanner.microphoneDenied.offersSettings)
        XCTAssertTrue(PermissionBanner.locationDenied.offersSettings)
        XCTAssertFalse(PermissionBanner.motionUnavailable.offersSettings, "motion is availability, not a grant")
    }

    // The capability priority (camera is essential; other denials degrade) is the core's,
    // but the banner must follow it: a camera denial dominates any other denial.
    func testCameraDenialDominates() {
        let perms = SensorPermissions(camera: .denied, microphone: .denied, location: .denied, motion: .authorized)
        XCTAssertEqual(perms.capability, .unavailable)
        XCTAssertEqual(PermissionBanner.forCapability(perms.capability), .cameraRequired)
    }

    func testMicrophoneOnlyDenialIsDirectionOnly() {
        let perms = SensorPermissions(camera: .authorized, microphone: .denied, location: .authorized, motion: .authorized)
        XCTAssertEqual(perms.capability, .directionOnly)
        XCTAssertEqual(PermissionBanner.forCapability(perms.capability), .microphoneDenied)
    }
}
