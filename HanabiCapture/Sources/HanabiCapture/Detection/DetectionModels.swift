/// A point in normalized frame coordinates (0...1 in each axis, origin top-left).
public struct NormalizedPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Per-frame luminance features extracted from a video frame by the camera layer. The
/// detector is deterministic and testable because it consumes these features rather than
/// raw pixels.
public struct FrameLuminanceSample: Sendable, Equatable {
    public var time: CaptureTimestamp
    /// Mean luminance over the frame, 0...1.
    public var meanLuminance: Double
    /// Peak luminance in the frame, 0...1.
    public var peakLuminance: Double
    /// Fraction of the frame above the bright threshold, 0...1.
    public var brightArea: Double
    /// Centroid of the bright region.
    public var brightCentroid: NormalizedPoint
    /// The bright region touches the frame border (possible clipped firework).
    public var atFrameEdge: Bool

    public init(
        time: CaptureTimestamp,
        meanLuminance: Double,
        peakLuminance: Double,
        brightArea: Double,
        brightCentroid: NormalizedPoint,
        atFrameEdge: Bool = false
    ) {
        self.time = time
        self.meanLuminance = meanLuminance
        self.peakLuminance = peakLuminance
        self.brightArea = brightArea
        self.brightCentroid = brightCentroid
        self.atFrameEdge = atFrameEdge
    }
}

/// A detected flash: the light onset of a firework burst.
public struct FlashCandidate: Sendable, Equatable {
    public var onsetTime: CaptureTimestamp
    public var peakTime: CaptureTimestamp
    public var centroid: NormalizedPoint
    public var peakLuminance: Double
    public var brightArea: Double
    /// Visual confidence 0...1 (sharpness, localization; reduced for global brightening or edge clipping).
    public var visualConfidence: Double
    public var atFrameEdge: Bool

    public init(
        onsetTime: CaptureTimestamp,
        peakTime: CaptureTimestamp,
        centroid: NormalizedPoint,
        peakLuminance: Double,
        brightArea: Double,
        visualConfidence: Double,
        atFrameEdge: Bool
    ) {
        self.onsetTime = onsetTime
        self.peakTime = peakTime
        self.centroid = centroid
        self.peakLuminance = peakLuminance
        self.brightArea = brightArea
        self.visualConfidence = visualConfidence
        self.atFrameEdge = atFrameEdge
    }
}
