/// The deterministic single-burst estimate produced by `BurstSolver`.
public struct BurstEstimate: Equatable, Sendable {
    /// Burst position: latitude, longitude, and (ellipsoidal) altitude from geometry.
    public var burst: GeodeticCoordinate
    /// The ground projection directly below the burst (the "subpoint").
    public var subpoint: GeodeticCoordinate
    /// Straight-line (slant) distance from observer to burst, meters.
    public var lineOfSightDistance: Double
    /// Horizontal ground distance from observer to subpoint, meters.
    public var horizontalDistance: Double
    /// Azimuth to the burst, degrees clockwise from true north.
    public var azimuthDegrees: Double
    /// Elevation angle to the burst, degrees above horizontal.
    public var elevationDegrees: Double
    /// Burst height relative to the observer, meters.
    public var relativeHeight: Double
    /// Effective sound speed used (m/s), after temperature/humidity/wind correction.
    public var effectiveSoundSpeed: Double
    /// Number of weather-correction iterations performed.
    public var iterations: Int
    /// The estimation-core version that produced this result.
    public var calculationVersion: String
    /// Terrain elevation directly below the burst, meters, if a ground-elevation
    /// source was available. `nil` means the ground is unknown here — in which case
    /// no height-above-ground is claimed (commissioning §13).
    public var groundElevation: Double?
    /// Burst height above the terrain below it (`burst.altitude - groundElevation`),
    /// meters. `nil` whenever `groundElevation` is `nil`.
    public var heightAboveGround: Double?
    /// Attribution for the ground elevation used, if any.
    public var elevationSource: String?

    public init(
        burst: GeodeticCoordinate,
        subpoint: GeodeticCoordinate,
        lineOfSightDistance: Double,
        horizontalDistance: Double,
        azimuthDegrees: Double,
        elevationDegrees: Double,
        relativeHeight: Double,
        effectiveSoundSpeed: Double,
        iterations: Int,
        calculationVersion: String,
        groundElevation: Double? = nil,
        heightAboveGround: Double? = nil,
        elevationSource: String? = nil
    ) {
        self.burst = burst
        self.subpoint = subpoint
        self.lineOfSightDistance = lineOfSightDistance
        self.horizontalDistance = horizontalDistance
        self.azimuthDegrees = azimuthDegrees
        self.elevationDegrees = elevationDegrees
        self.relativeHeight = relativeHeight
        self.effectiveSoundSpeed = effectiveSoundSpeed
        self.iterations = iterations
        self.calculationVersion = calculationVersion
        self.groundElevation = groundElevation
        self.heightAboveGround = heightAboveGround
        self.elevationSource = elevationSource
    }

    /// Returns a copy with terrain-relative height resolved from a ground-elevation
    /// sample taken at the subpoint. Passing `nil` returns the estimate unchanged: the
    /// ground fields stay `nil` and the caller must present MSL / relative height only,
    /// never a fabricated height above ground (commissioning §13).
    public func applyingGroundElevation(_ sample: ElevationSample?) -> BurstEstimate {
        guard let sample else { return self }
        var copy = self
        copy.groundElevation = sample.elevation
        copy.heightAboveGround = burst.altitude - sample.elevation
        copy.elevationSource = sample.source
        copy.subpoint = GeodeticCoordinate(
            latitude: subpoint.latitude,
            longitude: subpoint.longitude,
            altitude: sample.elevation
        )
        return copy
    }
}

/// A 95% confidence ellipse for a horizontal position.
public struct ErrorEllipse: Equatable, Sendable {
    public var semiMajorMeters: Double
    public var semiMinorMeters: Double
    /// Orientation of the major axis, degrees clockwise from north, in [0, 180).
    public var orientationDegrees: Double

    public init(semiMajorMeters: Double, semiMinorMeters: Double, orientationDegrees: Double) {
        self.semiMajorMeters = semiMajorMeters
        self.semiMinorMeters = semiMinorMeters
        self.orientationDegrees = orientationDegrees
    }
}

/// A coarse, user-facing confidence bucket.
public enum ConfidenceCategory: String, Sendable, Equatable {
    case high
    case medium
    case low
}

/// The dominant contributor to positional uncertainty, so the result can honestly
/// name *why* confidence is what it is.
public enum UncertaintyFactor: String, Sendable, Equatable {
    case timeDifference
    case temperature
    case soundSpeed
    case heading
    case elevationAngle
    case attitude
    case gpsHorizontal
    case gpsVertical
    case pairing
}

/// The output of Monte Carlo uncertainty estimation for one burst.
public struct UncertaintyResult: Equatable, Sendable {
    public var distanceMedian: Double
    public var distanceLow95: Double
    public var distanceHigh95: Double
    public var centerLatitude: Double
    public var centerLongitude: Double
    public var horizontalEllipse: ErrorEllipse
    public var altitudeMedian: Double
    public var altitudeLow95: Double
    public var altitudeHigh95: Double
    /// Overall confidence in 0...1.
    public var confidence: Double
    public var confidenceCategory: ConfidenceCategory
    public var dominantFactor: UncertaintyFactor
    public var sampleCount: Int

    public init(
        distanceMedian: Double,
        distanceLow95: Double,
        distanceHigh95: Double,
        centerLatitude: Double,
        centerLongitude: Double,
        horizontalEllipse: ErrorEllipse,
        altitudeMedian: Double,
        altitudeLow95: Double,
        altitudeHigh95: Double,
        confidence: Double,
        confidenceCategory: ConfidenceCategory,
        dominantFactor: UncertaintyFactor,
        sampleCount: Int
    ) {
        self.distanceMedian = distanceMedian
        self.distanceLow95 = distanceLow95
        self.distanceHigh95 = distanceHigh95
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.horizontalEllipse = horizontalEllipse
        self.altitudeMedian = altitudeMedian
        self.altitudeLow95 = altitudeLow95
        self.altitudeHigh95 = altitudeHigh95
        self.confidence = confidence
        self.confidenceCategory = confidenceCategory
        self.dominantFactor = dominantFactor
        self.sampleCount = sampleCount
    }
}
