import XCTest
import Foundation
@testable import HanabiCore

final class OpticsGeometryTests: XCTestCase {

    let intrinsics = CameraIntrinsics(fx: 1500, fy: 1500, cx: 960, cy: 540, width: 1920, height: 1080)

    func testCenterPixelRayIsForward() {
        let r = CameraRaySolver.cameraRay(from: ImagePoint(u: 960, v: 540), intrinsics: intrinsics)
        XCTAssertEqual(r.x, 0, accuracy: 1e-12)
        XCTAssertEqual(r.y, 0, accuracy: 1e-12)
        XCTAssertEqual(r.z, 1, accuracy: 1e-12)
    }

    func testRightPixelHasPositiveX() {
        let r = CameraRaySolver.cameraRay(from: ImagePoint(u: 1260, v: 540), intrinsics: intrinsics)
        XCTAssertGreaterThan(r.x, 0)
        XCTAssertEqual(r.y, 0, accuracy: 1e-12)
    }

    func testAzimuthElevationWithAlignedFrame() {
        // Camera forward(+z) -> north, right(+x) -> east, down(+y) -> -up.
        let m = Matrix3.rows(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
        let deviceToENU = Quaternion(rotationMatrix: m)
        let solver = BurstSolver()
        let observer = GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 0)

        // Pixel 300 px right of center -> dx = 0.2 -> azimuth = atan(0.2).
        let right = BurstSolver.Sighting(
            observer: observer,
            imagePoint: ImagePoint(u: 1260, v: 540),
            intrinsics: intrinsics,
            deviceToENU: deviceToENU,
            deltaT: 1
        )
        let rayRight = solver.enuRay(for: right)
        XCTAssertEqual(LineOfSight.azimuthDegrees(enuRay: rayRight), atan(0.2) * 180 / .pi, accuracy: 1e-6)
        XCTAssertEqual(LineOfSight.elevationDegrees(enuRay: rayRight), 0, accuracy: 1e-6)

        // Pixel 150 px below center -> dy = 0.1 -> elevation = -atan(0.1).
        let down = BurstSolver.Sighting(
            observer: observer,
            imagePoint: ImagePoint(u: 960, v: 690),
            intrinsics: intrinsics,
            deviceToENU: deviceToENU,
            deltaT: 1
        )
        let rayDown = solver.enuRay(for: down)
        XCTAssertEqual(LineOfSight.elevationDegrees(enuRay: rayDown), -atan(0.1) * 180 / .pi, accuracy: 1e-6)
        XCTAssertEqual(LineOfSight.azimuthDegrees(enuRay: rayDown), 0, accuracy: 1e-6)
    }
}
