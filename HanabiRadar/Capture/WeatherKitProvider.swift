import Foundation
import CoreLocation
import WeatherKit
import HanabiCore

/// Supplies live atmospheric conditions from Apple WeatherKit, conforming to the core's
/// `WeatherConditionsProviding` so the estimation core never imports an Apple framework.
///
/// API surface (verified against Apple's WeatherKit documentation):
/// `WeatherService.shared.weather(for: CLLocation).currentWeather` yields a
/// `CurrentWeather` whose `temperature` / `pressure` / `wind.speed` / `wind.direction`
/// are `Measurement`s and whose `humidity` is a `Double` in 0...1. WeatherKit's wind
/// `direction` is the meteorological "from" bearing (degrees clockwise from north),
/// which is exactly what `WeatherConditions.windFromDirectionDegrees` expects.
///
/// Verification status: this file compiles in an unsigned build (the iOS CI builds it),
/// but RUNTIME calls require the WeatherKit capability + entitlement and an Apple
/// Developer account (owner-side), and Apple **requires** that its attribution
/// (`WeatherService.shared.attribution`) be shown wherever this data appears. It has not
/// been exercised on a device yet — see Docs/KNOWN_LIMITATIONS.md.
struct WeatherKitProvider: WeatherConditionsProviding {

    init() {}

    func conditions(at coordinate: GeodeticCoordinate) async throws -> WeatherConditions {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        // `WeatherService.shared` is used directly (not stored) so the provider stays a
        // trivially Sendable value type.
        let current = try await WeatherService.shared.weather(for: location).currentWeather
        return WeatherConditions(
            temperatureCelsius: current.temperature.converted(to: .celsius).value,
            relativeHumidity: current.humidity,                                    // already 0...1
            pressureHPa: current.pressure.converted(to: .hectopascals).value,
            windSpeed: current.wind.speed.converted(to: .metersPerSecond).value,
            windFromDirectionDegrees: current.wind.direction.converted(to: .degrees).value
        )
    }
}
