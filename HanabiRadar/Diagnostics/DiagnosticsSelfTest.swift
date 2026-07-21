import Foundation
import HanabiCore
import HanabiCapture

/// Runs the real detection → pairing → estimation pipeline on a synthetic firework scenario
/// with a known ground truth, so the full engine can be exercised end-to-end in the app
/// without a live show or physical sensors (§23 diagnostics / regression aid). It builds
/// synthetic luminance frames (a localized flash), audio feature frames (a delayed bang),
/// and a sensor timeline, feeds them through `BurstPipeline` + `BurstSolver`, and compares
/// the recovered burst to the known truth. Pure and testable.
enum DiagnosticsSelfTest {

    struct Result {
        var sightingCount: Int
        var trueDistanceMeters: Double
        var recoveredDistanceMeters: Double
        var distanceErrorMeters: Double
        var horizontalErrorMeters: Double
        var verticalErrorMeters: Double
        var trueBurst: GeodeticCoordinate
        var recoveredBurst: GeodeticCoordinate
        var passed: Bool
    }

    static func run() async -> Result {
        // Known scenario: observer, look direction (azimuth/elevation), and slant distance.
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

        // Video: baseline frames, then a localized flash at the principal point.
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

        // Audio: baseline, then a boomy bang at the expected delay.
        var audio: [AudioFeatureFrame] = []
        for i in 0..<30 {
            audio.append(AudioFeatureFrame(time: CaptureTimestamp(seconds: bangOnset - 0.30 + Double(i) * 0.01), energy: 0.01, spectralFlux: 0.01, lowBandEnergy: 0.005))
        }
        audio.append(AudioFeatureFrame(time: CaptureTimestamp(seconds: bangOnset), energy: 0.5, spectralFlux: 0.3, lowBandEnergy: 0.3))
        audio.append(AudioFeatureFrame(time: CaptureTimestamp(seconds: bangOnset + 0.01), energy: 0.7, spectralFlux: 0.2, lowBandEnergy: 0.42))
        audio.append(AudioFeatureFrame(time: CaptureTimestamp(seconds: bangOnset + 0.02), energy: 0.2, spectralFlux: 0.05, lowBandEnergy: 0.1))

        let sightings = BurstPipeline().process(frames: frames, audio: audio, timeline: timeline, intrinsics: intrinsics)

        guard let first = sightings.first else {
            return Result(
                sightingCount: 0, trueDistanceMeters: distance, recoveredDistanceMeters: 0,
                distanceErrorMeters: .infinity, horizontalErrorMeters: .infinity, verticalErrorMeters: .infinity,
                trueBurst: trueBurst, recoveredBurst: observer, passed: false
            )
        }

        let estimate = await BurstSolver().solve(
            first.sighting,
            observerWeather: WeatherConditions(temperatureCelsius: 20, relativeHumidity: 0, pressureHPa: 1013.25, windSpeed: 0)
        )

        let offset = Geodesy.enuOffset(of: estimate.burst, from: trueBurst)
        let horizontalError = (offset.x * offset.x + offset.y * offset.y).squareRoot()
        let verticalError = abs(offset.z)
        let distanceError = abs(estimate.lineOfSightDistance - distance)

        let passed = sightings.count == 1
            && distanceError < 3.0
            && horizontalError < 8.0
            && verticalError < 8.0

        return Result(
            sightingCount: sightings.count,
            trueDistanceMeters: distance,
            recoveredDistanceMeters: estimate.lineOfSightDistance,
            distanceErrorMeters: distanceError,
            horizontalErrorMeters: horizontalError,
            verticalErrorMeters: verticalError,
            trueBurst: trueBurst,
            recoveredBurst: estimate.burst,
            passed: passed
        )
    }
}
