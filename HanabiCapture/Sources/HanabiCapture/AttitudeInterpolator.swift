import HanabiCore

/// Interpolates device attitude at an exact query time from bracketing samples using
/// spherical linear interpolation. Used to obtain the attitude at the flash time, which
/// generally falls between two motion samples.
public enum AttitudeInterpolator {

    public static func attitude(
        at time: CaptureTimestamp,
        before: Timed<Quaternion>?,
        after: Timed<Quaternion>?
    ) -> Quaternion? {
        switch (before, after) {
        case let (before?, after?):
            let span = after.time.seconds - before.time.seconds
            guard span > 0 else { return before.value.normalized() }
            let fraction = (time.seconds - before.time.seconds) / span
            let clamped = Swift.max(0.0, Swift.min(1.0, fraction))
            return Quaternion.slerp(before.value, after.value, clamped)
        case let (before?, nil):
            return before.value.normalized()
        case let (nil, after?):
            return after.value.normalized()
        case (nil, nil):
            return nil
        }
    }

    public static func attitude(
        at time: CaptureTimestamp,
        in buffer: TimedRingBuffer<Quaternion>
    ) -> Quaternion? {
        let bracket = buffer.bracketing(time)
        return attitude(at: time, before: bracket.before, after: bracket.after)
    }
}
