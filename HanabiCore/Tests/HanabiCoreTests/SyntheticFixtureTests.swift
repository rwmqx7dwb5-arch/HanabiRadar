import XCTest
import Foundation
@testable import HanabiCore

final class SyntheticFixtureTests: XCTestCase {

    let intrinsics = CameraIntrinsics(fx: 1600, fy: 1600, cx: 960, cy: 540, width: 1920, height: 1080)

    func testRecoverKnownBurst() async {
        let observer = GeodeticCoordinate(latitude: 35.681, longitude: 139.767, altitude: 30)
        let trueBurst = SyntheticScene.burst(from: observer, azimuthDegrees: 60, elevationDegrees: 42, distance: 1800)
        let scene = SyntheticScene(observer: observer, trueBurst: trueBurst, temperatureCelsius: 22)

        let est = await BurstSolver().solve(scene.sighting(intrinsics: intrinsics), observerWeather: scene.observerWeather)

        XCTAssertEqual(est.lineOfSightDistance, 1800, accuracy: 0.5)
        XCTAssertEqual(est.azimuthDegrees, 60, accuracy: 0.01)
        XCTAssertEqual(est.elevationDegrees, 42, accuracy: 0.01)
        XCTAssertEqual(est.burst.latitude, trueBurst.latitude, accuracy: 1e-6)
        XCTAssertEqual(est.burst.longitude, trueBurst.longitude, accuracy: 1e-6)
        XCTAssertEqual(est.burst.altitude, trueBurst.altitude, accuracy: 1.0)
    }

    func testRecoverAcrossManyGeometries() async {
        let observer = GeodeticCoordinate(latitude: 35.0, longitude: 139.0, altitude: 10)
        let solver = BurstSolver()

        for azimuth in stride(from: 0.0, to: 360.0, by: 45.0) {
            for elevation in [20.0, 45.0, 70.0] {
                for distance in [500.0, 1500.0, 3000.0] {
                    let trueBurst = SyntheticScene.burst(from: observer, azimuthDegrees: azimuth, elevationDegrees: elevation, distance: distance)
                    let scene = SyntheticScene(observer: observer, trueBurst: trueBurst, temperatureCelsius: 18)
                    let est = await solver.solve(scene.sighting(intrinsics: intrinsics), observerWeather: scene.observerWeather)

                    XCTAssertEqual(est.lineOfSightDistance, distance, accuracy: distance * 0.001 + 0.5)
                    XCTAssertEqual(est.burst.latitude, trueBurst.latitude, accuracy: 1e-5)
                    XCTAssertEqual(est.burst.longitude, trueBurst.longitude, accuracy: 1e-5)
                    XCTAssertEqual(est.burst.altitude, trueBurst.altitude, accuracy: 1.5)
                }
            }
        }
    }
}
