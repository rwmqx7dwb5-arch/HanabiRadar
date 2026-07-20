/// Unit conversions for display (temperature, distance). Kept in the core so the
/// same conversions are used everywhere and can be unit-tested.
public enum Units {
    public static func celsiusToFahrenheit(_ c: Double) -> Double { c * 9.0 / 5.0 + 32.0 }
    public static func fahrenheitToCelsius(_ f: Double) -> Double { (f - 32.0) * 5.0 / 9.0 }
    public static func celsiusToKelvin(_ c: Double) -> Double { c + 273.15 }
    public static func metersToFeet(_ m: Double) -> Double { m / 0.3048 }
    public static func feetToMeters(_ ft: Double) -> Double { ft * 0.3048 }
    public static func kilometersToMiles(_ km: Double) -> Double { km / 1.609344 }
    public static func milesToKilometers(_ mi: Double) -> Double { mi * 1.609344 }
}
