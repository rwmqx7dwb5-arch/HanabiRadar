import Foundation

/// Small statistics helpers used by uncertainty estimation and clustering.
public enum Statistics {

    /// Linear-interpolated percentile of an unsorted array. `p` in 0...1.
    public static func percentile(_ values: [Double], _ p: Double) -> Double {
        percentileSorted(values.sorted(), p)
    }

    /// Linear-interpolated percentile of an already-sorted array. `p` in 0...1.
    public static func percentileSorted(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        if sorted.count == 1 { return sorted[0] }
        let clampedP = Swift.max(0, Swift.min(1, p))
        let rank = clampedP * Double(sorted.count - 1)
        let lo = Int(rank.rounded(.down))
        let hi = Int(rank.rounded(.up))
        let frac = rank - Double(lo)
        return sorted[lo] * (1 - frac) + sorted[hi] * frac
    }

    public static func median(_ values: [Double]) -> Double { percentile(values, 0.5) }

    public static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Median absolute deviation (unscaled), a robust spread estimator.
    public static func medianAbsoluteDeviation(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let m = median(values)
        return median(values.map { abs($0 - m) })
    }

    /// Principal axes of a 2x2 covariance matrix, scaled by `chiSquare` (use 5.991
    /// for a 95% ellipse with 2 degrees of freedom). x is treated as east, y as north.
    public static func ellipse2D(
        covXX sxx: Double,
        covXY sxy: Double,
        covYY syy: Double,
        chiSquare: Double
    ) -> (semiMajor: Double, semiMinor: Double, majorAxisEast: Double, majorAxisNorth: Double) {
        let trace = sxx + syy
        let det = sxx * syy - sxy * sxy
        let disc = Swift.max(0, (trace * trace) / 4.0 - det)
        let root = disc.squareRoot()
        let lambda1 = trace / 2.0 + root   // larger eigenvalue
        let lambda2 = trace / 2.0 - root
        let semiMajor = (Swift.max(0, lambda1) * chiSquare).squareRoot()
        let semiMinor = (Swift.max(0, lambda2) * chiSquare).squareRoot()

        // Eigenvector for lambda1: (sxy, lambda1 - sxx), with an axis-aligned fallback.
        var ex = sxy
        var ey = lambda1 - sxx
        if abs(ex) < 1e-12 && abs(ey) < 1e-12 {
            if sxx >= syy { ex = 1; ey = 0 } else { ex = 0; ey = 1 }
        }
        let norm = (ex * ex + ey * ey).squareRoot()
        return (semiMajor, semiMinor, ex / norm, ey / norm)
    }
}
