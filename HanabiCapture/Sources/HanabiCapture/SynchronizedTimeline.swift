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
