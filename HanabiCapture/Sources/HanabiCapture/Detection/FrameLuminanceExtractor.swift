/// Pure luminance-feature extraction from a downsampled 8-bit luma grid.
///
/// The camera layer downsamples a video frame's Y plane into a small, contiguous grid
/// (row-major, values 0...255) and calls this. Keeping the flash-relevant math free of
/// CoreVideo makes it deterministic and unit-testable — the `FlashDetector` then consumes
/// the resulting `FrameLuminanceSample`s without ever touching raw pixels.
public enum FrameLuminanceExtractor {

    public struct Config: Sendable {
        /// Normalized luminance (0...1) at or above which a pixel counts as "bright".
        public var brightThreshold: Double

        public init(brightThreshold: Double = 0.75) {
            self.brightThreshold = brightThreshold
        }
    }

    /// Computes per-frame luminance features from a `width`×`height` luma grid.
    ///
    /// - `luma`: row-major 8-bit luminance, at least `width * height` elements.
    /// - Centroid is the brightness-thresholded region's center, normalized 0...1 with the
    ///   origin at the top-left; `(0.5, 0.5)` when nothing is bright.
    /// - `atFrameEdge` is set when the bright region touches the grid border (a possibly
    ///   clipped firework), which the detector down-weights.
    public static func features(
        luma: [UInt8],
        width: Int,
        height: Int,
        time: CaptureTimestamp,
        config: Config = Config()
    ) -> FrameLuminanceSample {
        let count = width * height
        guard width > 0, height > 0, luma.count >= count else {
            return FrameLuminanceSample(
                time: time, meanLuminance: 0, peakLuminance: 0, brightArea: 0,
                brightCentroid: NormalizedPoint(x: 0.5, y: 0.5), atFrameEdge: false
            )
        }

        let threshold = UInt8(clamping: Int((config.brightThreshold * 255).rounded()))
        var sum = 0
        var peak: UInt8 = 0
        var brightCount = 0
        var sumX = 0.0
        var sumY = 0.0
        var touchesEdge = false

        var i = 0
        for y in 0..<height {
            for x in 0..<width {
                let v = luma[i]
                sum += Int(v)
                if v > peak { peak = v }
                if v >= threshold {
                    brightCount += 1
                    sumX += Double(x)
                    sumY += Double(y)
                    if x == 0 || y == 0 || x == width - 1 || y == height - 1 {
                        touchesEdge = true
                    }
                }
                i += 1
            }
        }

        let total = Double(count)
        let centroid: NormalizedPoint
        if brightCount > 0 {
            centroid = NormalizedPoint(
                x: (sumX / Double(brightCount)) / Double(max(width - 1, 1)),
                y: (sumY / Double(brightCount)) / Double(max(height - 1, 1))
            )
        } else {
            centroid = NormalizedPoint(x: 0.5, y: 0.5)
        }

        return FrameLuminanceSample(
            time: time,
            meanLuminance: Double(sum) / total / 255.0,
            peakLuminance: Double(peak) / 255.0,
            brightArea: Double(brightCount) / total,
            brightCentroid: centroid,
            atFrameEdge: brightCount > 0 && touchesEdge
        )
    }
}
