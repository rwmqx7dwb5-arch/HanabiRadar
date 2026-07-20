import Foundation

/// Pure, UI-independent formatting helpers (unit-tested without UIKit).
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
}
