import Foundation
import HanabiCore

/// Pure, UI-independent formatting helpers (unit-tested without UIKit).
///
/// The honesty-critical decisions (how precisely a coordinate may be shown, whether a
/// height above ground exists, whether weather was fully applied) come from the core's
/// `EstimateReporter` / `BurstEstimate`; these helpers only turn those into strings, so
/// the presentation stays testable and never over-states precision (commissioning §4, §14).
enum Formatting {

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
    static func distanceLine(median: Double, low95: Double, high95: Double, metric: Bool) -> String {
        let m = distance(meters: median, metric: metric)
        let lo = distance(meters: low95, metric: metric)
        let hi = distance(meters: high95, metric: metric)
        return "\(m)（\(lo)–\(hi)）"
    }

    /// Latitude/longitude formatted at the precision the uncertainty justifies — never
    /// more decimal places than `precision.latLonDecimalPlaces` (commissioning §14).
    static func coordinate(_ coord: GeodeticCoordinate, precision: CoordinatePrecision) -> String {
        let dp = precision.latLonDecimalPlaces
        return String(format: "%.\(dp)f, %.\(dp)f", coord.latitude, coord.longitude)
    }

    /// An honest height line distinguishing MSL / relative / above-ground (commissioning §13).
    /// Only claims a height above ground when the estimate actually resolved one.
    static func heightLine(estimate: BurstEstimate, metric: Bool) -> String {
        let msl = "海抜約 \(distance(meters: estimate.burst.altitude, metric: metric))"
        if let agl = estimate.heightAboveGround {
            return "地上高約 \(distance(meters: agl, metric: metric)) / \(msl)"
        }
        let rel = estimate.relativeHeight
        let sign = rel >= 0 ? "+" : "−"
        return "\(msl) / 観測点から \(sign)\(distance(meters: abs(rel), metric: metric))（地上高: 標高データなし）"
    }

    /// Note shown when weather correction did not run at the burst point (commissioning §5).
    static func weatherPartialNote(estimate: BurstEstimate) -> String? {
        estimate.iterations >= 1 ? nil : "気象補正: 一部未適用"
    }

    /// Confidence bucket label.
    static func confidenceLabel(_ category: ConfidenceCategory) -> String {
        switch category {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }

    /// Human label for the dominant uncertainty factor (so the app can say *why*).
    static func dominantFactorLabel(_ factor: UncertaintyFactor) -> String {
        switch factor {
        case .timeDifference: return "時間差"
        case .temperature: return "気温"
        case .soundSpeed: return "音速"
        case .heading: return "方位精度"
        case .elevationAngle: return "仰角"
        case .attitude: return "姿勢"
        case .gpsHorizontal: return "GPS水平精度"
        case .gpsVertical: return "GPS垂直精度"
        case .pairing: return "対応付け"
        }
    }
}
