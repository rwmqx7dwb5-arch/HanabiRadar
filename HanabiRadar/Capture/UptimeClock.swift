import Foundation
import HanabiCapture

/// The common capture axis is the monotonic system uptime clock (the same base as
/// `CMDeviceMotion.timestamp`). Wall-clock sources (Core Location) are normalized onto
/// it with a calibration captured at start.
enum UptimeClock {
    static func now() -> Double {
        ProcessInfo.processInfo.systemUptime
    }

    /// A normalizer mapping wall-clock (`timeIntervalSinceReferenceDate`) onto the uptime
    /// axis, calibrated from a simultaneous read of both clocks.
    static func wallClockNormalizer() -> TimelineNormalizer {
        let uptime = ProcessInfo.processInfo.systemUptime
        let wall = Date().timeIntervalSinceReferenceDate
        return TimelineNormalizer.calibrated(sourceReference: wall, commonReference: uptime)
    }
}
