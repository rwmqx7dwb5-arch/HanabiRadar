import XCTest
import Foundation
import HanabiCore
@testable import HanabiCapture

final class BurstPipelineTests: XCTestCase {

    func testEndToEndRecoversKnownBurst() async {
        let observer = GeodeticCoordinate(latitude: 35.681, longitude: 139.767, altitude: 30)
        let azimuth = 60.0 * .pi / 180
        let elevation = 42.0 * .pi / 180
        let distance = 1800.0
        let trueRay = Vector3(cos(elevation) * sin(azimuth), cos(elevation) * cos(azimuth), sin(elevation))
        let trueBurst = Geodesy.coordinate(from: observer, enuOffset: trueRay * distance)
        let deviceToENU = Quaternion(from: Vector3(0, 0, 1), to: trueRay)

        let intrinsics = CameraIntrinsics(fx: 1600, fy: 1600, cx: 960, cy: 540, width: 1920, height: 1080)
        let soundSpeed = SoundSpeedModel().drySpeed(temperatureCelsius: 20)
        let flashOnset = 100.0
        let deltaT = distance / soundSpeed
        let bangOnset = flashOnset + deltaT

        var timeline = SynchronizedTimeline(capacity: 200)
        timeline.recordAttitude(deviceToENU, at: CaptureTimestamp(seconds: flashOnset - 0.1))
        timeline.recordAttitude(deviceToENU, at: CaptureTimestamp(seconds: flashOnset + 0.1))
        timeline.recordLocation(
            LocationSample(coordinate: observer, horizontalAccuracy: 5, verticalAccuracy: 8),
            at: CaptureTimestamp(seconds: flashOnset)
        )

        // Video: baseline then a localized flash at the principal point, onset == flashOnset.
        var frames: [FrameLuminanceSample] = []
        for i in 0..<15 {
            frames.append(FrameLuminanceSample(
                time: CaptureTimestamp(seconds: flashOnset - 0.15 + Double(i) * 0.01),
                meanLuminance: 0.1, peakLuminance: 0.2, brightArea: 0.02,
                brightCentroid: NormalizedPoint(x: 0.5, y: 0.5)
            ))
        }
        frames.append(FrameLuminanceSample(time: CaptureTimestamp(seconds: flashOnset), meanLuminance: 0.12, peakLuminance: 0.7, brightArea: 0.05, brightCentroid: NormalizedPoint(x: 0.5, y: 0.5)))
        frames.append(FrameLuminanceSample(time: CaptureTimestamp(seconds: flashOnset + 0.01), meanLuminance: 0.13, peakLuminance: 0.9, brightArea: 0.06, brightCentroid: NormalizedPoint(x: 0.5, y: 0.5)))
        frames.append(FrameLuminanceSample(time: CaptureTimestamp(seconds: flashOnset + 0.02), meanLuminance: 0.11, peakLuminance: 0.4, brightArea: 0.03, brightCentroid: NormalizedPoint(x: 0.5, y: 0.5)))

        // Audio: baseline then a boomy bang, onset == bangOnset.
        var audio: [AudioFeatureFrame] = []
        for i in 0..<30 {
            audio.append(AudioFeatureFrame(time: CaptureTimestamp(seconds: bangOnset - 0.30 + Double(i) * 0.01), energy: 0.01, spectralFlux: 0.01, lowBandEnergy: 0.005))
        }
        audio.append(AudioFeatureFrame(time: CaptureTimestamp(seconds: bangOnset), energy: 0.5, spectralFlux: 0.3, lowBandEnergy: 0.3))
        audio.append(AudioFeatureFrame(time: CaptureTimestamp(seconds: bangOnset + 0.01), energy: 0.7, spectralFlux: 0.2, lowBandEnergy: 0.42))
        audio.append(AudioFeatureFrame(time: CaptureTimestamp(seconds: bangOnset + 0.02), energy: 0.2, spectralFlux: 0.05, lowBandEnergy: 0.1))

        let sightings = BurstPipeline().process(
            frames: frames, audio: audio, timeline: timeline, intrinsics: intrinsics
        )
        XCTAssertEqual(sightings.count, 1)
        XCTAssertEqual(sightings[0].sighting.deltaT, deltaT, accuracy: 1e-9)

        let estimate = await BurstSolver().solve(
            sightings[0].sighting,
            observerWeather: WeatherConditions(temperatureCelsius: 20, relativeHumidity: 0, pressureHPa: 1013.25, windSpeed: 0)
        )
        XCTAssertEqual(estimate.lineOfSightDistance, distance, accuracy: 1.0)
        XCTAssertEqual(estimate.burst.latitude, trueBurst.latitude, accuracy: 1e-5)
        XCTAssertEqual(estimate.burst.longitude, trueBurst.longitude, accuracy: 1e-5)
        XCTAssertEqual(estimate.burst.altitude, trueBurst.altitude, accuracy: 1.5)
    }

    /// The candidate-based `sightings(...)` tail (used by the live measurement screen) pairs
    /// pre-detected flash/audio candidates and recovers the same burst as the full pipeline.
    func testSightingsFromCandidatesRecoversBurst() async {
        let observer = GeodeticCoordinate(latitude: 35.681, longitude: 139.767, altitude: 30)
        let azimuth = 60.0 * .pi / 180
        let elevation = 42.0 * .pi / 180
        let distance = 1800.0
        let trueRay = Vector3(cos(elevation) * sin(azimuth), cos(elevation) * cos(azimuth), sin(elevation))
        let trueBurst = Geodesy.coordinate(from: observer, enuOffset: trueRay * distance)
        let deviceToENU = Quaternion(from: Vector3(0, 0, 1), to: trueRay)
        let intrinsics = CameraIntrinsics(fx: 1600, fy: 1600, cx: 960, cy: 540, width: 1920, height: 1080)

        let soundSpeed = SoundSpeedModel().drySpeed(temperatureCelsius: 20)
        let flashOnset = 100.0
        let deltaT = distance / soundSpeed
        let bangOnset = flashOnset + deltaT

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
            onsetTime: CaptureTimestamp(seconds: bangOnset),
            peakTime: CaptureTimestamp(seconds: bangOnset + 0.01),
            peakEnergy: 0.7, transientConfidence: 0.8
        )

        let sightings = BurstPipeline().sightings(
            flashes: [flash], transients: [transient], timeline: timeline, intrinsics: intrinsics
        )
        XCTAssertEqual(sightings.count, 1)
        XCTAssertEqual(sightings[0].sighting.deltaT, deltaT, accuracy: 1e-9)

        let estimate = await BurstSolver().solve(
            sightings[0].sighting,
            observerWeather: WeatherConditions(temperatureCelsius: 20, relativeHumidity: 0, pressureHPa: 1013.25, windSpeed: 0)
        )
        XCTAssertEqual(estimate.lineOfSightDistance, distance, accuracy: 1.0)
        XCTAssertEqual(estimate.burst.latitude, trueBurst.latitude, accuracy: 1e-5)
        XCTAssertEqual(estimate.burst.longitude, trueBurst.longitude, accuracy: 1e-5)
    }
}
