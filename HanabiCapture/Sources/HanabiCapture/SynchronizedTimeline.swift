import HanabiCore

/// Aggregates time-ordered sensor histories on the common capture axis and answers
/// "what was the state at the flash time?" queries. Attitude is slerp-interpolated;
/// location and heading return the nearest sample together with the time lag so the
/// estimator can down-weight stale fixes.
public struct SynchronizedTimeline: Sendable {
    public private(set) var attitude: TimedRingBuffer<Quaternion>
    public private(set) var location: TimedRingBuffer<LocationSample>
    public private(set) var heading: TimedRingBuffer<HeadingSample>

    public init(capacity: Int) {
        self.attitude = TimedRingBuffer(capacity: capacity)
        self.location = TimedRingBuffer(capacity: capacity)
        self.heading = TimedRingBuffer(capacity: capacity)
    }

    public mutating func recordAttitude(_ quaternion: Quaternion, at time: CaptureTimestamp) {
        attitude.append(Timed(time: time, value: quaternion))
    }

    public mutating func recordLocation(_ sample: LocationSample, at time: CaptureTimestamp) {
        location.append(Timed(time: time, value: sample))
    }

    public mutating func recordHeading(_ sample: HeadingSample, at time: CaptureTimestamp) {
        heading.append(Timed(time: time, value: sample))
    }

    /// Slerp-interpolated attitude at `time`.
    public func interpolatedAttitude(at time: CaptureTimestamp) -> Quaternion? {
        AttitudeInterpolator.attitude(at: time, in: attitude)
    }

    /// Nearest location fix to `time`, with the absolute time lag in seconds.
    public func nearestLocation(at time: CaptureTimestamp) -> (sample: LocationSample, lagSeconds: Double)? {
        nearest(in: location, at: time)
    }

    /// Nearest heading reading to `time`, with the absolute time lag in seconds.
    public func nearestHeading(at time: CaptureTimestamp) -> (sample: HeadingSample, lagSeconds: Double)? {
        nearest(in: heading, at: time)
    }

    public mutating func prune(olderThan time: CaptureTimestamp) {
        attitude.prune(olderThan: time)
        location.prune(olderThan: time)
        heading.prune(olderThan: time)
    }

    private func nearest<V>(in buffer: TimedRingBuffer<V>, at time: CaptureTimestamp) -> (sample: V, lagSeconds: Double)? {
        let bracket = buffer.bracketing(time)
        switch (bracket.before, bracket.after) {
        case let (before?, after?):
            let lagBefore = abs(time.seconds - before.time.seconds)
            let lagAfter = abs(after.time.seconds - time.seconds)
            return lagBefore <= lagAfter ? (before.value, lagBefore) : (after.value, lagAfter)
        case let (before?, nil):
            return (before.value, abs(time.seconds - before.time.seconds))
        case let (nil, after?):
            return (after.value, abs(after.time.seconds - time.seconds))
        case (nil, nil):
            return nil
        }
    }
}

extension SynchronizedTimeline {

    /// A representative observer-fix accuracy for the whole session, so the position error
    /// bars reflect the ACTUAL GPS fixes rather than a fixed default (§14). It takes the
    /// median reported accuracy across the session's location samples (robust to a single
    /// wild fix) and ignores invalid fixes — Core Location reports a negative accuracy for
    /// those. Returns `nil` when no valid horizontal fix was recorded, so the caller can
    /// fall back to a default. When only the vertical accuracy is invalid, it falls back to
    /// 1.5× the horizontal accuracy (the typical GPS vertical:horizontal ratio).
    public func locationAccuracySummary() -> (horizontal: Double, vertical: Double)? {
        let samples = location.orderedItems.map(\.value)
        let horizontals = samples.map(\.horizontalAccuracy).filter { $0 > 0 }
        guard horizontals.isEmpty == false else { return nil }
        let verticals = samples.map(\.verticalAccuracy).filter { $0 > 0 }
        let horizontal = Self.median(horizontals)
        let vertical = verticals.isEmpty ? horizontal * 1.5 : Self.median(verticals)
        return (horizontal: horizontal, vertical: vertical)
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        guard count > 0 else { return 0 }
        if count.isMultiple(of: 2) {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        }
        return sorted[count / 2]
    }
}
