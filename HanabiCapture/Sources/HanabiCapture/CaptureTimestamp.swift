/// A timestamp on the common, monotonic capture time axis (seconds).
///
/// All sensor samples (video PTS, audio PTS, Core Motion, Core Location, heading) are
/// normalized onto this single axis. Samples are timed by their OWN source timestamp,
/// never by the moment their callback was received.
public struct CaptureTimestamp: Comparable, Hashable, Sendable {
    public var seconds: Double

    public init(seconds: Double) {
        self.seconds = seconds
    }

    public static func < (lhs: CaptureTimestamp, rhs: CaptureTimestamp) -> Bool {
        lhs.seconds < rhs.seconds
    }
}

/// Maps timestamps from one source domain onto the common monotonic axis via an affine
/// offset: `common = source + offset`. The app layer calibrates the offset (for example
/// by sampling a wall-clock `Date` and the monotonic host clock at the same instant).
public struct TimelineNormalizer: Sendable {
    public var offsetSeconds: Double

    public init(offsetSeconds: Double = 0) {
        self.offsetSeconds = offsetSeconds
    }

    public func normalize(sourceSeconds: Double) -> CaptureTimestamp {
        CaptureTimestamp(seconds: sourceSeconds + offsetSeconds)
    }

    /// Builds a normalizer from a pair of timestamps sampled at the same instant in the
    /// source domain and the common domain.
    public static func calibrated(sourceReference: Double, commonReference: Double) -> TimelineNormalizer {
        TimelineNormalizer(offsetSeconds: commonReference - sourceReference)
    }
}
