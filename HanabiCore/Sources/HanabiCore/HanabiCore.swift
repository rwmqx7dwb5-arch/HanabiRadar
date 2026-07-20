import Foundation

/// Top-level information and versioning for the estimation core.
///
/// Named `CoreInfo` rather than the module name to avoid a type/module name clash.
public enum CoreInfo {

    /// Semantic version of the estimation math. It is persisted with every stored
    /// estimate so past results can be recomputed and compared when the algorithms
    /// change (see `BurstEstimate.calculationVersion`).
    public static let calculationVersion = "0.1.0"
}
