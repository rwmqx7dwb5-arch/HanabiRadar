import Foundation
import HanabiCore

/// Pure, UI-independent formatting helpers (unit-tested without UIKit).
///
/// The honesty-critical decisions (how precisely a coordinate may be shown, whether a
/// height above ground exists, whether weather was fully applied) come from the core's
/// `EstimateReporter` / `BurstEstimate`; these helpers only turn those into strings, so
/// the presentation stays testable and never over-states precision (commissioning §4, §14).
enum Formatting {

    /// Language of the value strings built here. Explicit so unit tests do not depend on the
    /// simulator's language; the app uses `.current`, which follows the bundle's resolved
    /// localization (Japanese source, English translation).
    enum Language {
        case ja, en

        static var current: Language {
            Bundle.main.preferredLocalizations.first?.hasPrefix("ja") == false ? .en : .ja
        }
    }

    /// Formats a distance in meters, switching to km / miles at sensible thresholds.
    static func distance(meters: Double, metric: Bool) -> String {
        if metric {
            return meters >= 1000
                ? String(format: "%.2f km", meters / 1000)
                : String(format: "%.0f m", meters)
        } else {
            let feet = meters / 0.3048
            return feet >= 5280
                ? String(format: "%.2f mi", feet / 5280)
                : String(format: "%.0f ft", feet)
        }
    }

    /// A distance with its 95% interval, e.g. "1.84 km（1.77 km–1.91 km）".
    static func distanceLine(
        median: Double, low95: Double, high95: Double, metric: Bool, language: Language = .current
    ) -> String {
        let m = distance(meters: median, metric: metric)
        let lo = distance(meters: low95, metric: metric)
        let hi = distance(meters: high95, metric: metric)
        return language == .ja ? "\(m)（\(lo)–\(hi)）" : "\(m) (\(lo)–\(hi))"
    }

    /// Latitude/longitude formatted at the precision the uncertainty justifies — never
    /// more decimal places than `precision.latLonDecimalPlaces` (commissioning §14).
    static func coordinate(_ coord: GeodeticCoordinate, precision: CoordinatePrecision) -> String {
        let dp = precision.latLonDecimalPlaces
        return String(format: "%.\(dp)f, %.\(dp)f", coord.latitude, coord.longitude)
    }

    /// An honest height line distinguishing MSL / relative / above-ground (commissioning §13).
    /// Only claims a height above ground when the estimate actually resolved one.
    static func heightLine(estimate: BurstEstimate, metric: Bool, language: Language = .current) -> String {
        let ja = language == .ja
        let altitude = distance(meters: estimate.burst.altitude, metric: metric)
        let msl = ja ? "海抜約 \(altitude)" : "≈\(altitude) above sea level"
        if let agl = estimate.heightAboveGround {
            let ground = distance(meters: agl, metric: metric)
            return ja ? "地上高約 \(ground) / \(msl)" : "≈\(ground) above ground / \(msl)"
        }
        let rel = estimate.relativeHeight
        let sign = rel >= 0 ? "+" : "−"
        let offset = "\(sign)\(distance(meters: abs(rel), metric: metric))"
        return ja
            ? "\(msl) / 観測点から \(offset)（地上高: 標高データなし）"
            : "\(msl) / \(offset) from observer (height above ground: no elevation data)"
    }

    /// Note shown when weather correction did not run at the burst point (commissioning §5).
    static func weatherPartialNote(estimate: BurstEstimate, language: Language = .current) -> String? {
        guard estimate.iterations < 1 else { return nil }
        return language == .ja ? "気象補正: 一部未適用" : "Weather correction: partly not applied"
    }

    /// Confidence bucket label.
    static func confidenceLabel(_ category: ConfidenceCategory, language: Language = .current) -> String {
        let ja = language == .ja
        switch category {
        case .high: return ja ? "高" : "High"
        case .medium: return ja ? "中" : "Medium"
        case .low: return ja ? "低" : "Low"
        }
    }

    /// Human label for the dominant uncertainty factor (so the app can say *why*).
    static func dominantFactorLabel(_ factor: UncertaintyFactor, language: Language = .current) -> String {
        let ja = language == .ja
        switch factor {
        case .timeDifference: return ja ? "時間差" : "Flash-to-bang delay"
        case .temperature: return ja ? "気温" : "Air temperature"
        case .soundSpeed: return ja ? "音速" : "Speed of sound"
        case .heading: return ja ? "方位精度" : "Heading accuracy"
        case .elevationAngle: return ja ? "仰角" : "Elevation angle"
        case .attitude: return ja ? "姿勢" : "Device attitude"
        case .gpsHorizontal: return ja ? "GPS水平精度" : "GPS horizontal accuracy"
        case .gpsVertical: return ja ? "GPS垂直精度" : "GPS vertical accuracy"
        case .pairing: return ja ? "対応付け" : "Flash/bang pairing"
        }
    }

    /// Temperature formatted in the user's preferred unit (°C default, °F optional).
    static func temperature(celsius: Double, fahrenheit: Bool) -> String {
        fahrenheit
            ? String(format: "%.0f°F", celsius * 9 / 5 + 32)
            : String(format: "%.0f°C", celsius)
    }
}
