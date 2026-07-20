import Foundation

/// Models the speed of sound in air and its dependence on temperature, humidity,
/// and along-path wind.
public struct SoundSpeedModel: Sendable {

    public init() {}

    /// Speed of sound in dry air (m/s) for a temperature in degrees Celsius:
    /// `c(T) = 331.3 * sqrt(1 + T / 273.15)`.
    public func drySpeed(temperatureCelsius t: Double) -> Double {
        331.3 * (1.0 + t / 273.15).squareRoot()
    }

    /// First-order humidity correction (m/s) added to the dry-air speed.
    ///
    /// Humidity raises the speed of sound by roughly +0.3 to +0.4 m/s at 20-30 C and
    /// 100% relative humidity. This is a small, bounded term; its residual error is
    /// folded into the uncertainty budget rather than claimed as exact.
    public func humidityCorrection(
        temperatureCelsius t: Double,
        relativeHumidity rh: Double,
        pressureHPa p: Double
    ) -> Double {
        guard p > 0 else { return 0 }
        // Saturation vapor pressure (Tetens), hPa.
        let esat = 6.1078 * pow(10.0, (7.5 * t) / (t + 237.3))
        let clampedRH = Swift.max(0.0, Swift.min(1.0, rh))
        let e = clampedRH * esat
        let xw = e / p                       // mole fraction of water vapor
        let dry = drySpeed(temperatureCelsius: t)
        // Calibrated so that ~100% RH at 20 C (xw ~= 0.023) yields ~ +0.4 m/s.
        return dry * 0.0507 * xw
    }

    /// Converts a meteorological wind (speed + the direction it blows FROM, measured
    /// clockwise from true north) into an ENU velocity vector (m/s).
    public static func windVectorENU(speed: Double, fromDirectionDegrees fromDir: Double) -> Vector3 {
        // Wind blowing FROM `fromDir` has a velocity vector pointing toward fromDir + 180.
        let toDir = (fromDir + 180.0) * Double.pi / 180.0
        let east = speed * sin(toDir)
        let north = speed * cos(toDir)
        return Vector3(east, north, 0)
    }

    /// Effective sound speed (m/s) along the propagation path from the burst to the
    /// observer, including the along-path wind component.
    ///
    /// `pathUnitBurstToObserver` is a unit ENU vector pointing from the source
    /// (burst) to the receiver (observer); wind blowing that way speeds sound up.
    public func effectiveSpeed(
        temperatureCelsius t: Double,
        relativeHumidity rh: Double,
        pressureHPa p: Double,
        windENU: Vector3,
        pathUnitBurstToObserver path: Vector3
    ) -> Double {
        let base = drySpeed(temperatureCelsius: t)
            + humidityCorrection(temperatureCelsius: t, relativeHumidity: rh, pressureHPa: p)
        let along = windENU.dot(path.normalized())
        return base + along
    }
}
