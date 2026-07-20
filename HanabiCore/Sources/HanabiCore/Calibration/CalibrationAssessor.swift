import Foundation

/// A snapshot of live sensor quality just before / during a measurement. The capture
/// layer fills this from Core Location / Core Motion / the camera format / the audio
/// route; the core turns it into a readiness verdict so the "測定可能 / 精度低下 /
/// 測定困難" decision is unit-tested rather than trusted to the UI (commissioning §22).
public struct SensorQuality: Sendable, Equatable {
    /// GPS horizontal accuracy (meters). `nil` means no usable location fix.
    public var horizontalAccuracyMeters: Double?
    /// True heading accuracy (degrees). `nil` or negative means heading is unavailable.
    public var headingAccuracyDegrees: Double?
    /// Whether Core Motion is producing a device attitude.
    public var hasAttitude: Bool
    /// Whether camera intrinsics are available for the active format.
    public var hasCameraIntrinsics: Bool
    /// Active capture frame rate (fps).
    public var frameRate: Double
    /// Recent audio input peak in 0...1. `nil` means unknown (not penalized).
    public var audioInputLevel: Double?
    /// Whether the audio route is the built-in mic (external / Bluetooth mics warn; §7.3).
    public var audioRouteIsBuiltIn: Bool

    public init(
        horizontalAccuracyMeters: Double?,
        headingAccuracyDegrees: Double?,
        hasAttitude: Bool,
        hasCameraIntrinsics: Bool,
        frameRate: Double,
        audioInputLevel: Double? = nil,
        audioRouteIsBuiltIn: Bool = true
    ) {
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.headingAccuracyDegrees = headingAccuracyDegrees
        self.hasAttitude = hasAttitude
        self.hasCameraIntrinsics = hasCameraIntrinsics
        self.frameRate = frameRate
        self.audioInputLevel = audioInputLevel
        self.audioRouteIsBuiltIn = audioRouteIsBuiltIn
    }
}

/// Overall measurement readiness (§22 の3段階).
public enum MeasurementQuality: String, Sendable, Equatable {
    case ready       // 測定可能
    case degraded    // 精度低下
    case blocked     // 測定困難
}

/// A specific, machine-readable readiness problem. The UI maps each to localized advice
/// (e.g. `poorHeadingAccuracy` → "金属・スピーカーから離れてください"); the core only
/// decides which problems apply so the mapping stays tested and localizable.
public enum ReadinessIssue: String, Sendable, Equatable {
    case locationUnavailable
    case poorHorizontalAccuracy
    case headingUnavailable
    case poorHeadingAccuracy
    case attitudeUnavailable
    case cameraIntrinsicsUnavailable
    case lowFrameRate
    case noAudioInput
    case externalMicrophone
}

/// The readiness verdict plus the issues behind it, worst-blocking first.
public struct ReadinessAssessment: Equatable, Sendable {
    public var quality: MeasurementQuality
    public var issues: [ReadinessIssue]

    public init(quality: MeasurementQuality, issues: [ReadinessIssue]) {
        self.quality = quality
        self.issues = issues
    }
}

/// Turns a `SensorQuality` snapshot into a `ReadinessAssessment`. Pure and deterministic.
///
/// Blocking issues (missing location / heading / attitude, or accuracy beyond the usable
/// maximum) yield `.blocked`; softer problems (marginal accuracy, missing intrinsics, low
/// frame rate, no/weak audio, external mic) yield `.degraded`; otherwise `.ready`. Issues
/// are returned blocking-first so the UI can lead with the real obstacle.
public struct CalibrationAssessor: Sendable {

    public struct Thresholds: Sendable, Equatable {
        /// At or below this horizontal accuracy the fix is "good"; above it degrades.
        public var goodHorizontalAccuracyMeters: Double
        /// Above this horizontal accuracy the fix is too poor to measure with (blocks).
        public var maxHorizontalAccuracyMeters: Double
        /// At or below this heading accuracy heading is "good"; above it degrades.
        public var goodHeadingAccuracyDegrees: Double
        /// Above this heading accuracy the azimuth is too poor to measure with (blocks).
        public var maxHeadingAccuracyDegrees: Double
        /// Below this frame rate flash timing degrades.
        public var minFrameRate: Double

        public init(
            goodHorizontalAccuracyMeters: Double = 15,
            maxHorizontalAccuracyMeters: Double = 50,
            goodHeadingAccuracyDegrees: Double = 10,
            maxHeadingAccuracyDegrees: Double = 25,
            minFrameRate: Double = 30
        ) {
            self.goodHorizontalAccuracyMeters = goodHorizontalAccuracyMeters
            self.maxHorizontalAccuracyMeters = maxHorizontalAccuracyMeters
            self.goodHeadingAccuracyDegrees = goodHeadingAccuracyDegrees
            self.maxHeadingAccuracyDegrees = maxHeadingAccuracyDegrees
            self.minFrameRate = minFrameRate
        }
    }

    public init() {}

    public func assess(_ quality: SensorQuality, thresholds: Thresholds = Thresholds()) -> ReadinessAssessment {
        var blocking: [ReadinessIssue] = []
        var degrading: [ReadinessIssue] = []

        // Location.
        if let h = quality.horizontalAccuracyMeters {
            if h > thresholds.maxHorizontalAccuracyMeters {
                blocking.append(.poorHorizontalAccuracy)
            } else if h > thresholds.goodHorizontalAccuracyMeters {
                degrading.append(.poorHorizontalAccuracy)
            }
        } else {
            blocking.append(.locationUnavailable)
        }

        // Heading (negative accuracy is Core Location's "invalid" sentinel).
        if let hd = quality.headingAccuracyDegrees, hd >= 0 {
            if hd > thresholds.maxHeadingAccuracyDegrees {
                blocking.append(.poorHeadingAccuracy)
            } else if hd > thresholds.goodHeadingAccuracyDegrees {
                degrading.append(.poorHeadingAccuracy)
            }
        } else {
            blocking.append(.headingUnavailable)
        }

        // Attitude is required to turn the camera ray into an ENU ray.
        if !quality.hasAttitude {
            blocking.append(.attitudeUnavailable)
        }

        // Softer problems.
        if !quality.hasCameraIntrinsics { degrading.append(.cameraIntrinsicsUnavailable) }
        if quality.frameRate < thresholds.minFrameRate { degrading.append(.lowFrameRate) }
        if let level = quality.audioInputLevel, level <= 0 { degrading.append(.noAudioInput) }
        if !quality.audioRouteIsBuiltIn { degrading.append(.externalMicrophone) }

        let verdict: MeasurementQuality = !blocking.isEmpty ? .blocked : (degrading.isEmpty ? .ready : .degraded)
        return ReadinessAssessment(quality: verdict, issues: blocking + degrading)
    }
}
