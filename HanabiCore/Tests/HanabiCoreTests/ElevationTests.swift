import XCTest
import Foundation
@testable import HanabiCore

private struct StubElevation: ElevationProviding {
    let sample: ElevationSample?
    func elevation(at coordinate: GeodeticCoordinate) async throws -> ElevationSample? { sample }
}

private struct FailingElevation: ElevationProviding {
    struct Failure: Error {}
    func elevation(at coordinate: GeodeticCoordinate) async throws -> ElevationSample? { throw Failure() }
}

final class ElevationTests: XCTestCase {

    private let intrinsics = CameraIntrinsics(fx: 1600, fy: 1600, cx: 960, cy: 540, width: 1920, height: 1080)

    /// A vertical burst 340 m above an observer 20 m up. With ground at 15 m the
    /// height above ground is (20 + 340) - 15 = 345 m and the subpoint sits on the
    /// ground, not at the observer's altitude.
    private func verticalScene() -> BurstSolver.Sighting {
        let observer = GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 20)
        let trueBurst = SyntheticScene.burst(from: observer, azimuthDegrees: 0, elevationDegrees: 90, distance: 340)
        return SyntheticScene(observer: observer, trueBurst: trueBurst, temperatureCelsius: 20)
            .sighting(intrinsics: intrinsics)
    }

    private var observerWeather: WeatherConditions {
        WeatherConditions(temperatureCelsius: 20, relativeHumidity: 0, pressureHPa: 1013.25)
    }

    func testHeightAboveGroundResolvedFromSample() async {
        let provider = StubElevation(
            sample: ElevationSample(elevation: 15, source: "test-dem", resolutionMeters: 30, dataVersion: "v1")
        )
        let est = await BurstSolver().solve(
            verticalScene(),
            observerWeather: observerWeather,
            elevationProvider: provider
        )
        XCTAssertNotNil(est.groundElevation)
        XCTAssertEqual(est.groundElevation ?? .nan, 15, accuracy: 1e-6)
        XCTAssertEqual(est.heightAboveGround ?? .nan, est.burst.altitude - 15, accuracy: 1e-6)
        XCTAssertEqual(est.subpoint.altitude, 15, accuracy: 1e-6)
        XCTAssertEqual(est.elevationSource, "test-dem")
        // Sanity: burst ~360 m MSL, so ~345 m above the 15 m ground.
        XCTAssertEqual(est.burst.altitude, 360, accuracy: 1.0)
        XCTAssertEqual(est.heightAboveGround ?? .nan, 345, accuracy: 1.0)
    }

    func testNoElevationProviderLeavesGroundUnknown() async {
        let est = await BurstSolver().solve(verticalScene(), observerWeather: observerWeather)
        XCTAssertNil(est.groundElevation)
        XCTAssertNil(est.heightAboveGround)
        XCTAssertNil(est.elevationSource)
        // The MSL / relative-height result is still fully populated.
        XCTAssertEqual(est.relativeHeight, 340, accuracy: 1.0)
    }

    func testElevationFailureLeavesGroundUnknownButKeepsMSL() async {
        let est = await BurstSolver().solve(
            verticalScene(),
            observerWeather: observerWeather,
            elevationProvider: FailingElevation()
        )
        XCTAssertNil(est.groundElevation)
        XCTAssertNil(est.heightAboveGround)
        XCTAssertEqual(est.burst.altitude, 360, accuracy: 1.0)   // MSL estimate preserved
    }

    func testNilSampleLeavesGroundUnknown() async {
        let est = await BurstSolver().solve(
            verticalScene(),
            observerWeather: observerWeather,
            elevationProvider: StubElevation(sample: nil)
        )
        XCTAssertNil(est.groundElevation)
        XCTAssertNil(est.heightAboveGround)
    }

    func testApplyingNilGroundElevationReturnsUnchanged() async {
        let est = await BurstSolver().solve(verticalScene(), observerWeather: observerWeather)
        XCTAssertEqual(est.applyingGroundElevation(nil), est)
    }
}
