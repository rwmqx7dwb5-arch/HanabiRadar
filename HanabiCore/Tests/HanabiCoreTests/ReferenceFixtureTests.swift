import XCTest
import Foundation
@testable import HanabiCore

/// Cross-language validation against an INDEPENDENT reference implementation.
///
/// `tools/reference/hanabi_reference.py` implements the same equations in Python and
/// emits `Fixtures/reference_scenes.json`. These tests assert that the Swift core
/// agrees with that independent oracle for sound speed, the optical ray, and full
/// burst recovery from mathematically generated ground truth (commissioning §24.2).
/// Regenerate the fixture with `python tools/reference/hanabi_reference.py`.
final class ReferenceFixtureTests: XCTestCase {

    // MARK: Fixture schema (unknown JSON keys are ignored by the decoder)

    private struct Fixture: Decodable {
        let scenes: [SceneRow]
        let soundSpeed: [SoundRow]
        let cameraRay: [CameraRow]
    }

    private struct SceneRow: Decodable {
        let name: String
        let observerLat, observerLon, observerAlt: Double
        let azimuth, elevation, distance, temperature, groundElevation: Double
        let expectedBurstLat, expectedBurstLon, expectedBurstAlt: Double
        let expectedLosDistance, expectedHorizontalDistance: Double
        let expectedAzimuth, expectedElevation: Double
        let expectedHeightAboveGround, expectedSubpointAlt: Double
    }

    private struct SoundRow: Decodable {
        let t, rh, p, windSpeed, windFromDeg, rayAz, rayEl: Double
        let drySpeed, humidityCorrection, effectiveSpeed: Double
    }

    private struct CameraRow: Decodable {
        let fx, fy, cx, cy, u, v: Double
        let rayX, rayY, rayZ, azimuth, elevation: Double
    }

    private let intrinsics = CameraIntrinsics(fx: 1600, fy: 1600, cx: 960, cy: 540, width: 1920, height: 1080)

    // MARK: Loading

    private func loadFixture() throws -> Fixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("reference_scenes.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Fixture.self, from: data)
    }

    private func angularDelta(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return abs(d)
    }

    // MARK: Tests

    func testSoundSpeedMatchesReference() throws {
        let model = SoundSpeedModel()
        let fixture = try loadFixture()
        XCTAssertFalse(fixture.soundSpeed.isEmpty)
        for row in fixture.soundSpeed {
            XCTAssertEqual(model.drySpeed(temperatureCelsius: row.t), row.drySpeed, accuracy: 1e-9)
            XCTAssertEqual(
                model.humidityCorrection(temperatureCelsius: row.t, relativeHumidity: row.rh, pressureHPa: row.p),
                row.humidityCorrection, accuracy: 1e-9
            )
            let wind = WeatherConditions(
                temperatureCelsius: row.t, relativeHumidity: row.rh, pressureHPa: row.p,
                windSpeed: row.windSpeed, windFromDirectionDegrees: row.windFromDeg
            ).windVectorENU
            let a = row.rayAz * .pi / 180, e = row.rayEl * .pi / 180
            let ray = Vector3(cos(e) * sin(a), cos(e) * cos(a), sin(e))
            let effective = model.effectiveSpeed(
                temperatureCelsius: row.t, relativeHumidity: row.rh, pressureHPa: row.p,
                windENU: wind, pathUnitBurstToObserver: -ray
            )
            XCTAssertEqual(effective, row.effectiveSpeed, accuracy: 1e-9)
        }
    }

    func testCameraRayMatchesReference() throws {
        let fixture = try loadFixture()
        XCTAssertFalse(fixture.cameraRay.isEmpty)
        for row in fixture.cameraRay {
            let k = CameraIntrinsics(fx: row.fx, fy: row.fy, cx: row.cx, cy: row.cy, width: row.cx * 2, height: row.cy * 2)
            let ray = CameraRaySolver.cameraRay(from: ImagePoint(u: row.u, v: row.v), intrinsics: k)
            XCTAssertEqual(ray.x, row.rayX, accuracy: 1e-9)
            XCTAssertEqual(ray.y, row.rayY, accuracy: 1e-9)
            XCTAssertEqual(ray.z, row.rayZ, accuracy: 1e-9)
            XCTAssertEqual(LineOfSight.azimuthDegrees(enuRay: ray), row.azimuth, accuracy: 1e-7)
            XCTAssertEqual(LineOfSight.elevationDegrees(enuRay: ray), row.elevation, accuracy: 1e-7)
        }
    }

    func testBurstRecoveryMatchesReference() async throws {
        let solver = BurstSolver()
        let fixture = try loadFixture()
        XCTAssertFalse(fixture.scenes.isEmpty)
        for row in fixture.scenes {
            let observer = GeodeticCoordinate(latitude: row.observerLat, longitude: row.observerLon, altitude: row.observerAlt)
            let trueBurst = SyntheticScene.burst(
                from: observer, azimuthDegrees: row.azimuth, elevationDegrees: row.elevation, distance: row.distance
            )
            let scene = SyntheticScene(observer: observer, trueBurst: trueBurst, temperatureCelsius: row.temperature)
            let est = await solver.solve(scene.sighting(intrinsics: intrinsics), observerWeather: scene.observerWeather)

            XCTAssertEqual(est.burst.latitude, row.expectedBurstLat, accuracy: 1e-6, row.name)
            XCTAssertEqual(est.burst.longitude, row.expectedBurstLon, accuracy: 1e-6, row.name)
            XCTAssertEqual(est.burst.altitude, row.expectedBurstAlt, accuracy: 0.1, row.name)
            XCTAssertEqual(est.lineOfSightDistance, row.expectedLosDistance, accuracy: 0.1, row.name)
            XCTAssertEqual(est.horizontalDistance, row.expectedHorizontalDistance, accuracy: 0.5, row.name)
            XCTAssertEqual(est.elevationDegrees, row.expectedElevation, accuracy: 0.01, row.name)
            XCTAssertLessThan(angularDelta(est.azimuthDegrees, row.expectedAzimuth), 0.01, row.name)

            let withGround = est.applyingGroundElevation(
                ElevationSample(elevation: row.groundElevation, source: "reference-fixture")
            )
            XCTAssertEqual(withGround.heightAboveGround ?? .nan, row.expectedHeightAboveGround, accuracy: 0.1, row.name)
            XCTAssertEqual(withGround.subpoint.altitude, row.expectedSubpointAlt, accuracy: 1e-6, row.name)
        }
    }
}
