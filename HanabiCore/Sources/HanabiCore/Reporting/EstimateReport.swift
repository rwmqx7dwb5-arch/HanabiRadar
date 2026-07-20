import Foundation

/// How precisely it is honest to present a horizontal position, derived from the
/// horizontal 95% uncertainty. Coordinates must never be shown more precisely than the
/// uncertainty justifies, and a low-confidence fix must not be dressed up as a sharp
/// point (commissioning §14: "方位精度が悪い状態で、細かい緯度・経度を大きく表示してはいけない").
public enum CoordinatePrecision: String, Sendable, Equatable {
    /// Sharp enough to pin a point on the map (small 95% radius).
    case fine
    /// Show the point, but lead with the ± radius.
    case coarse
    /// Show an area / region, not a sharp coordinate.
    case areaOnly

    /// Recommended number of latitude/longitude fractional decimal places to display.
    /// (~1e-5° ≈ 1.1 m, ~1e-3° ≈ 111 m, ~1e-2° ≈ 1.1 km.) The view uses this so it never
    /// prints more significant digits than the uncertainty supports.
    public var latLonDecimalPlaces: Int {
        switch self {
        case .fine: return 5
        case .coarse: return 3
        case .areaOnly: return 2
        }
    }
}

/// A localization-free, unit-tested honesty summary of one burst estimate. The view
/// layer maps these fields to localized strings; the DECISIONS about what may honestly
/// be shown live here (commissioning §4, §14) rather than being trusted to the UI.
public struct BurstReport: Equatable, Sendable {
    public var confidence: Double
    public var confidenceCategory: ConfidenceCategory
    /// The dominant contributor to positional uncertainty, so the UI can name *why*
    /// confidence is what it is.
    public var dominantFactor: UncertaintyFactor
    /// Whether weather correction actually ran at the burst point (≥1 iteration). When
    /// false the UI must show "気象補正: 一部未適用" (commissioning §5, §11.2).
    public var weatherFullyApplied: Bool
    /// Whether a ground elevation was resolved. When false no height-above-ground is
    /// shown — only MSL / relative height (commissioning §13).
    public var groundHeightAvailable: Bool
    /// Honest horizontal display precision derived from the 95% ellipse.
    public var horizontalPrecision: CoordinatePrecision
    /// Semi-major axis of the horizontal 95% ellipse, meters — the number to show as ±.
    public var horizontalRadius95Meters: Double

    public init(
        confidence: Double,
        confidenceCategory: ConfidenceCategory,
        dominantFactor: UncertaintyFactor,
        weatherFullyApplied: Bool,
        groundHeightAvailable: Bool,
        horizontalPrecision: CoordinatePrecision,
        horizontalRadius95Meters: Double
    ) {
        self.confidence = confidence
        self.confidenceCategory = confidenceCategory
        self.dominantFactor = dominantFactor
        self.weatherFullyApplied = weatherFullyApplied
        self.groundHeightAvailable = groundHeightAvailable
        self.horizontalPrecision = horizontalPrecision
        self.horizontalRadius95Meters = horizontalRadius95Meters
    }
}

/// Turns a deterministic estimate and its Monte Carlo uncertainty into an honest,
/// presentation-ready summary. Pure and deterministic, so the honesty rules are
/// unit-tested rather than trusted to the view layer.
public enum EstimateReporter {

    /// Thresholds (meters) on the horizontal 95% semi-major axis that gate how sharply a
    /// position may be shown. Defaults are deliberately conservative.
    public struct Thresholds: Sendable, Equatable {
        /// At or below this radius the point may be shown at full precision.
        public var fineMaxMeters: Double
        /// Above `fineMaxMeters` and at or below this, show the point with an emphasized
        /// ± radius; beyond it, show an area rather than a sharp coordinate.
        public var coarseMaxMeters: Double

        public init(fineMaxMeters: Double = 50, coarseMaxMeters: Double = 300) {
            self.fineMaxMeters = fineMaxMeters
            self.coarseMaxMeters = coarseMaxMeters
        }
    }

    /// Builds the honest report. A low-confidence result is always demoted to `areaOnly`
    /// no matter how tight the ellipse looks, because low confidence means the ellipse
    /// itself is not trustworthy.
    public static func report(
        estimate: BurstEstimate,
        uncertainty: UncertaintyResult,
        thresholds: Thresholds = Thresholds()
    ) -> BurstReport {
        let radius = uncertainty.horizontalEllipse.semiMajorMeters
        let precision: CoordinatePrecision
        if uncertainty.confidenceCategory == .low || radius > thresholds.coarseMaxMeters {
            precision = .areaOnly
        } else if radius > thresholds.fineMaxMeters {
            precision = .coarse
        } else {
            precision = .fine
        }
        return BurstReport(
            confidence: uncertainty.confidence,
            confidenceCategory: uncertainty.confidenceCategory,
            dominantFactor: uncertainty.dominantFactor,
            weatherFullyApplied: estimate.iterations >= 1,
            groundHeightAvailable: estimate.heightAboveGround != nil,
            horizontalPrecision: precision,
            horizontalRadius95Meters: radius
        )
    }
}
