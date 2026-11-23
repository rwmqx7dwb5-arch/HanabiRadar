import XCTest
import HanabiCore
import HanabiCapture
@testable import HanabiRadar

final class SessionAnalyzerTests: XCTestCase {

    private func makeScenario() -> (
        flashes: [FlashCandidate],
        transients: [AudioTransientCandidate],
        timeline: SynchronizedTimeline,
        intrinsics: CameraIntrinsics,
        trueDistance: Double
    ) {
        let observer = GeodeticCoordinate(latitude: 35.681, longitude: 139.767, altitude: 30)
        let azimuth = 60.0 * .pi / 180
        let elevation = 42.0 * .pi / 180
        let distance = 1800.0
        let ray = Vector3(cos(elevation) * sin(azimuth), cos(elevation) * cos(azimuth), sin(elevation))
        let deviceToENU = Quaternion(from: Vector3(0, 0, 1), to: ray)
        let intrinsics = CameraIntrinsics(fx: 1600, fy: 1600, cx: 960, cy: 540, width: 1920, height: 1080)

        let soundSpeed = SoundSpeedModel().drySpeed(temperatureCelsius: 20)
        let flashOnset = 100.0
        let deltaT = distance / soundSpeed

        var timeline = SynchronizedTimeline(capacity: 50)
        timeline.recordAttitude(deviceToENU, at: CaptureTimestamp(seconds: flashOnset - 0.1))
        timeline.recordAttitude(deviceToENU, at: CaptureTimestamp(seconds: flashOnset + 0.1))
        timeline.recordLocation(
            LocationSample(coordinate: observer, horizontalAccuracy: 5, verticalAccuracy: 8),
            at: CaptureTimestamp(seconds: flashOnset)
        )

        let flash = FlashCandidate(
            onsetTime: CaptureTimestamp(seconds: flashOnset),
            peakTime: CaptureTimestamp(seconds: flashOnset + 0.01),
            centroid: NormalizedPoint(x: 0.5, y: 0.5),
            peakLuminance: 0.9, brightArea: 0.05, visualConfidence: 0.9, atFrameEdge: false
        )
        let transient = AudioTransientCandidate(
            onsetTime: CaptureTimestamp(seconds: flashOnset + deltaT),
            peakTime: CaptureTimestamp(seconds: flashOnset + deltaT + 0.01),
            peakEnergy: 0.7, transientConfidence: 0.8
        )
        return ([flash], [transient], timeline, intrinsics, distance)
    }

    private let conditions = SessionAnalyzer.Conditions(
        weather: WeatherConditions(temperatureCelsius: 20),
        horizontalAccuracy: 8, verticalAccuracy: 12, headingAccuracyDegrees: 6, frameRate: 30
    )

    func testAnalyzeRecoversBurstWithErrorBars() async {
        let scene = makeScenario()
        let result = await SessionAnalyzer().analyze(
            flashes: scene.flashes, transients: scene.transients,
            timeline: scene.timeline, intrinsics: scene.intrinsics, conditions: conditions
        )
        guard let result else { return XCTFail("expected a result") }

        XCTAssertEqual(result.sightingCount, 1)
        XCTAssertEqual(result.estimate.lineOfSightDistance, scene.trueDistance, accuracy: 2.0)
        // The uncertainty interval is populated and brackets the estimate.
        XCTAssertGreaterThan(result.uncertainty.distanceHigh95, result.uncertainty.distanceLow95)
        XCTAssertGreaterThan(result.uncertainty.sampleCount, 0)
        // The session summary aggregates every paired burst and carries the observer.
        XCTAssertEqual(result.summary.burstCount, 1)
        XCTAssertEqual(result.observer.latitude, 35.681, accuracy: 1e-6)
        XCTAssertEqual(result.observer.longitude, 139.767, accuracy: 1e-6)
    }

    func testAnalyzeReturnsNilWithoutPairableCandidates() async {
        let scene = makeScenario()
        // Flash only, no audio transient → nothing to pair.
        let result = await SessionAnalyzer().analyze(
            flashes: scene.flashes, transients: [],
            timeline: scene.timeline, intrinsics: scene.intrinsics, conditions: conditions
        )
        XCTAssertNil(result)
    }

    private struct LiveWeather: WeatherConditionsProviding {
        func conditions(at coordinate: GeodeticCoordinate) async throws -> WeatherConditions {
            WeatherConditions(temperatureCelsius: 30, relativeHumidity: 0.6, pressureHPa: 1010)
        }
    }

    private struct BrokenWeather: WeatherConditionsProviding {
        func conditions(at coordinate: GeodeticCoordinate) async throws -> WeatherConditions {
            throw URLError(.notConnectedToInternet)
        }
    }

    private struct GroundAt10m: ElevationProviding {
        func elevation(at coordinate: GeodeticCoordinate) async throws -> ElevationSample? {
            ElevationSample(elevation: 10, source: "test DEM")
        }
    }

    func testLiveWeatherIsAppliedAndFlagged() async {
        let scene = makeScenario()
        let result = await SessionAnalyzer().analyze(
            flashes: scene.flashes, transients: scene.transients,
            timeline: scene.timeline, intrinsics: scene.intrinsics, conditions: conditions,
            weatherProvider: LiveWeather()
        )
        XCTAssertEqual(result?.weatherLive, true)
    }

    func testWeatherFailureFallsBackWithoutFlag() async {
        let scene = makeScenario()
        let result = await SessionAnalyzer().analyze(
            flashes: scene.flashes, transients: scene.transients,
            timeline: scene.timeline, intrinsics: scene.intrinsics, conditions: conditions,
            weatherProvider: BrokenWeather()
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.weatherLive, false)
    }

    func testElevationProviderYieldsHeightAboveGround() async {
        let scene = makeScenario()
        let result = await SessionAnalyzer().analyze(
            flashes: scene.flashes, transients: scene.transients,
            timeline: scene.timeline, intrinsics: scene.intrinsics, conditions: conditions,
            elevationProvider: GroundAt10m()
        )
        XCTAssertEqual(result?.estimate.groundElevation, 10)
        XCTAssertNotNil(result?.estimate.heightAboveGround)
        XCTAssertEqual(result?.estimate.elevationSource, "test DEM")
    }

    func testWithTimeoutReturnsNilWhenOperationIsSlow() async {
        let value: Int? = await SessionAnalyzer.withTimeout(seconds: 0.05) {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return 1
        }
        XCTAssertNil(value)
        let fast: Int? = await SessionAnalyzer.withTimeout(seconds: 2) { 7 }
        XCTAssertEqual(fast, 7)
    }
}
