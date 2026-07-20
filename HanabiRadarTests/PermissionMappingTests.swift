import XCTest
import AVFoundation
import AVFAudio
import CoreLocation
import HanabiCapture
@testable import HanabiRadar

/// Verifies the OS authorization-status → `PermissionStatus` mappings and that the static
/// (test) permissions service reports the capability its inputs imply. Runs in the
/// Simulator test host, where the raw iOS enums are available.
final class PermissionMappingTests: XCTestCase {

    func testCameraMapping() {
        XCTAssertEqual(DevicePermissionsService.mapCamera(.authorized), .authorized)
        XCTAssertEqual(DevicePermissionsService.mapCamera(.denied), .denied)
        XCTAssertEqual(DevicePermissionsService.mapCamera(.restricted), .restricted)
        XCTAssertEqual(DevicePermissionsService.mapCamera(.notDetermined), .notDetermined)
    }

    func testMicrophoneMapping() {
        XCTAssertEqual(DevicePermissionsService.mapMicrophone(.granted), .authorized)
        XCTAssertEqual(DevicePermissionsService.mapMicrophone(.denied), .denied)
        XCTAssertEqual(DevicePermissionsService.mapMicrophone(.undetermined), .notDetermined)
    }

    func testLocationMapping() {
        XCTAssertEqual(DevicePermissionsService.mapLocation(.authorizedWhenInUse), .authorized)
        XCTAssertEqual(DevicePermissionsService.mapLocation(.authorizedAlways), .authorized)
        XCTAssertEqual(DevicePermissionsService.mapLocation(.denied), .denied)
        XCTAssertEqual(DevicePermissionsService.mapLocation(.restricted), .restricted)
        XCTAssertEqual(DevicePermissionsService.mapLocation(.notDetermined), .notDetermined)
    }

    func testStaticServiceReportsConfiguredCapability() async {
        let service = StaticPermissionsService(SensorPermissions(
            camera: .authorized, microphone: .denied, location: .authorized, motion: .authorized
        ))
        let capability = await service.current().capability
        XCTAssertEqual(capability, .directionOnly)
    }

    func testStaticServiceDefaultsToFull() async {
        let capability = await StaticPermissionsService().current().capability
        XCTAssertEqual(capability, .full)
    }
}
