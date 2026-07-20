/// Tunables for the flash detector.
public struct FlashDetectorConfig: Sendable {
    /// Minimum rise of peak luminance over the rolling baseline to trigger an onset.
    public var onsetRise: Double
    /// Frames used for the rolling baseline (updated only while idle).
    public var baselineWindow: Int
    /// Reject onsets whose bright region covers more than this fraction (global exposure).
    public var maxBrightArea: Double
    /// Reject onsets where mean luminance rose more than this ratio of the peak rise
    /// (uniform brightening rather than a localized blob).
    public var globalRiseRatio: Double
    /// Minimum absolute peak luminance for a flash.
    public var minPeakLuminance: Double
    /// Peak is considered passed once luminance falls this far below the tracked peak.
    public var decayMargin: Double
    /// Safety cap on how many frames a single flash may keep rising.
    public var maxRisingFrames: Int

    public init(
        onsetRise: Double = 0.15,
        baselineWindow: Int = 15,
        maxBrightArea: Double = 0.5,
        globalRiseRatio: Double = 0.4,
        minPeakLuminance: Double = 0.5,
        decayMargin: Double = 0.08,
        maxRisingFrames: Int = 20
    ) {
        self.onsetRise = onsetRise
        self.baselineWindow = baselineWindow
        self.maxBrightArea = maxBrightArea
        self.globalRiseRatio = globalRiseRatio
        self.minPeakLuminance = minPeakLuminance
        self.decayMargin = decayMargin
        self.maxRisingFrames = maxRisingFrames
    }
}

/// Deterministic, explainable flash detector. Fed one frame's luminance features at a
/// time, it emits a `FlashCandidate` when a localized bright onset rises sharply and then
/// peaks. Global exposure changes and gradual ramps are rejected; edge-clipped flashes
/// are kept but down-weighted.
public final class FlashDetector {
    private let config: FlashDetectorConfig
    private var basePeaks: [Double] = []
    private var baseMeans: [Double] = []
    private var rising = false
    private var onset: FrameLuminanceSample?
    private var peak: FrameLuminanceSample?
    private var risingFrames = 0

    public init(config: FlashDetectorConfig = FlashDetectorConfig()) {
        self.config = config
    }

    /// Feeds one frame; returns a `FlashCandidate` once a flash has peaked, else nil.
    public func process(_ frame: FrameLuminanceSample) -> FlashCandidate? {
        let basePeak = average(basePeaks, fallback: frame.peakLuminance)
        let baseMean = average(baseMeans, fallback: frame.meanLuminance)

        if !rising {
            let peakRise = frame.peakLuminance - basePeak
            let meanRise = frame.meanLuminance - baseMean
            let localized = frame.brightArea <= config.maxBrightArea
            let notGlobal = meanRise <= config.globalRiseRatio * Swift.max(peakRise, 1e-9)
            let brightEnough = frame.peakLuminance >= config.minPeakLuminance

            if peakRise >= config.onsetRise && localized && notGlobal && brightEnough {
                rising = true
                onset = frame
                peak = frame
                risingFrames = 0
                return nil
            }
            pushBaseline(frame)
            return nil
        }

        risingFrames += 1
        if let currentPeak = peak, frame.peakLuminance > currentPeak.peakLuminance {
            peak = frame
        }
        let trackedPeak = peak?.peakLuminance ?? frame.peakLuminance
        let peaked = frame.peakLuminance < (trackedPeak - config.decayMargin)
        if !peaked && risingFrames < config.maxRisingFrames {
            return nil
        }

        let candidate = makeCandidate(basePeak: basePeak, baseMean: baseMean)
        rising = false
        onset = nil
        peak = nil
        risingFrames = 0
        pushBaseline(frame)
        return candidate
    }

    private func makeCandidate(basePeak: Double, baseMean: Double) -> FlashCandidate {
        // `onset` and `peak` are always set while rising.
        let onset = self.onset ?? self.peak!
        let peak = self.peak ?? onset
        let peakRise = peak.peakLuminance - basePeak
        let meanRise = peak.meanLuminance - baseMean

        let sharpness = clamp01(peakRise / 0.4)
        let localization = clamp01(1.0 - peak.brightArea / Swift.max(config.maxBrightArea, 1e-9))
        let globalPenalty = (peakRise > 0 && meanRise > 0) ? clamp01(meanRise / peakRise) : 0.0
        let edgePenalty = peak.atFrameEdge ? 0.3 : 0.0
        let confidence = clamp01(0.5 * sharpness + 0.4 * localization + 0.1 - 0.3 * globalPenalty - edgePenalty)

        return FlashCandidate(
            onsetTime: onset.time,
            peakTime: peak.time,
            centroid: peak.brightCentroid,
            peakLuminance: peak.peakLuminance,
            brightArea: peak.brightArea,
            visualConfidence: confidence,
            atFrameEdge: peak.atFrameEdge
        )
    }

    private func pushBaseline(_ frame: FrameLuminanceSample) {
        basePeaks.append(frame.peakLuminance)
        baseMeans.append(frame.meanLuminance)
        if basePeaks.count > config.baselineWindow { basePeaks.removeFirst() }
        if baseMeans.count > config.baselineWindow { baseMeans.removeFirst() }
    }

    private func average(_ values: [Double], fallback: Double) -> Double {
        values.isEmpty ? fallback : values.reduce(0, +) / Double(values.count)
    }

    private func clamp01(_ value: Double) -> Double {
        Swift.max(0.0, Swift.min(1.0, value))
    }
}
