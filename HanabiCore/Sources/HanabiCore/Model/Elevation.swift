/// Terrain (ground) elevation at a coordinate, carrying enough provenance that the
/// UI can cite the source, its resolution, and its age — as required when any
/// height-above-ground is shown (commissioning §13). The value is expressed in the
/// SAME vertical datum the caller uses for observer altitude; see the datum
/// discussion in SCIENCE_AND_MATH.md §6.
public struct ElevationSample: Equatable, Sendable {
    /// Ground elevation in meters.
    public var elevation: Double
    /// Human-readable data source, shown for attribution (e.g. a dataset name).
    public var source: String
    /// Nominal horizontal resolution of the source grid in meters, if known.
    public var resolutionMeters: Double?
    /// Data version or retrieval identifier, if known.
    public var dataVersion: String?

    public init(
        elevation: Double,
        source: String,
        resolutionMeters: Double? = nil,
        dataVersion: String? = nil
    ) {
        self.elevation = elevation
        self.source = source
        self.resolutionMeters = resolutionMeters
        self.dataVersion = dataVersion
    }
}

/// Supplies ground elevation for an arbitrary coordinate.
///
/// The app layer conforms this to a digital-elevation source. The core and its tests
/// depend only on this protocol, so estimation never imports an Apple framework and
/// stays testable. Returning `nil` means "no ground elevation available here"; the
/// core then reports MSL / relative height only and never fabricates a height above
/// ground (commissioning §13, §21). A thrown error is treated the same way, so a
/// failing elevation service never blocks the core measurement.
public protocol ElevationProviding: Sendable {
    func elevation(at coordinate: GeodeticCoordinate) async throws -> ElevationSample?
}
