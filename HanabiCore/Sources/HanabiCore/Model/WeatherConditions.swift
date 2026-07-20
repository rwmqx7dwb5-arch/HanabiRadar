/// Atmospheric conditions used to correct the speed of sound.
public struct WeatherConditions: Equatable, Sendable {
    /// Air temperature in degrees Celsius.
    public var temperatureCelsius: Double
    /// Relative humidity as a fraction in 0...1.
    public var relativeHumidity: Double
    /// Surface pressure in hectopascals.
    public var pressureHPa: Double
    /// Wind speed in meters per second.
    public var windSpeed: Double
    /// Meteorological wind direction: the direction the wind blows FROM, in degrees
    /// clockwise from true north.
    public var windFromDirectionDegrees: Double

    public init(
        temperatureCelsius: Double,
        relativeHumidity: Double = 0.5,
        pressureHPa: Double = 1013.25,
        windSpeed: Double = 0,
        windFromDirectionDegrees: Double = 0
    ) {
        self.temperatureCelsius = temperatureCelsius
        self.relativeHumidity = relativeHumidity
        self.pressureHPa = pressureHPa
        self.windSpeed = windSpeed
        self.windFromDirectionDegrees = windFromDirectionDegrees
    }

    /// Wind as an ENU velocity vector (m/s).
    public var windVectorENU: Vector3 {
        SoundSpeedModel.windVectorENU(speed: windSpeed, fromDirectionDegrees: windFromDirectionDegrees)
    }
}

/// Supplies weather conditions for an arbitrary coordinate.
///
/// The app layer conforms this to WeatherKit. The core and its tests depend only on
/// this protocol, so estimation never imports an Apple framework and stays testable.
public protocol WeatherConditionsProviding: Sendable {
    func conditions(at coordinate: GeodeticCoordinate) async throws -> WeatherConditions
}
