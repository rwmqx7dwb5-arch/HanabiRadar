import Foundation
@testable import HanabiCore

/// Generates a full sighting from a known observer and a KNOWN true burst so the
/// solver output can be checked against ground truth (Section 24.2, synthetic data).
struct SyntheticScene {
    var observer: GeodeticCoordinate
    var trueBurst: GeodeticCoordinate
    var temperatureCelsius: Double

    /// True ENU ray from observer to burst.
    var trueRay: Vector3 { Geodesy.enuOffset(of: trueBurst, from: observer).normalized() }

    /// True slant distance from observer to burst, meters.
    var trueDistance: Double { Geodesy.enuOffset(of: trueBurst, from: observer).length }

    /// Builds a centered sighting: the burst sits at the principal point, and the
    /// attitude points the camera straight at it. Dry air, no wind, so the sound
    /// delay is exactly `distance / drySpeed(temperature)`.
    func sighting(intrinsics: CameraIntrinsics) -> BurstSolver.Sighting {
        let deviceToENU = Quaternion(from: Vector3(0, 0, 1), to: trueRay)
        let delay = trueDistance / SoundSpeedModel().drySpeed(temperatureCelsius: temperatureCelsius)
        return BurstSolver.Sighting(
            observer: observer,
            imagePoint: ImagePoint(u: intrinsics.cx, v: intrinsics.cy),
            intrinsics: intrinsics,
            deviceToENU: deviceToENU,
            deltaT: delay
        )
    }

    var observerWeather: WeatherConditions {
        WeatherConditions(temperatureCelsius: temperatureCelsius, relativeHumidity: 0, pressureHPa: 1013.25, windSpeed: 0)
    }

    /// A burst built from azimuth/elevation/distance relative to an observer.
    static func burst(
        from observer: GeodeticCoordinate,
        azimuthDegrees az: Double,
        elevationDegrees el: Double,
        distance: Double
    ) -> GeodeticCoordinate {
        let a = az * .pi / 180
        let e = el * .pi / 180
        let ray = Vector3(cos(e) * sin(a), cos(e) * cos(a), sin(e))
        return Geodesy.coordinate(from: observer, enuOffset: ray * distance)
    }
}
