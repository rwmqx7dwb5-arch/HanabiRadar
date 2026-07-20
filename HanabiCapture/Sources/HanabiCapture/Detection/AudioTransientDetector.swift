/// Per-frame audio features extracted from the microphone buffers by the audio layer.
/// The detector consumes these features (not raw audio), so it is deterministic and
/// testable.
public struct AudioFeatureFrame: Sendable, Equatable {
    public var time: CaptureTimestamp
    /// Short-time energy / RMS, >= 0.
    public var energy: Double
    /// Positive spectral flux (onset sharpness), >= 0.
    public var spectralFlux: Double
    /// Energy in the low band (a firework boom is low-frequency-heavy), >= 0.
    public var lowBandEnergy: Double
    /// Fraction of samples clipped in this frame, 0...1.
    public var clippingFraction: Double

    public init(
        time: CaptureTimestamp,
        energy: Double,
        spectralFlux: Double,
        lowBandEnergy: Double,
        clippingFraction: Double = 0
    ) {
        self.time = time
        self.energy = energy
        self.spectralFlux = spectralFlux
        self.lowBandEnergy = lowBandEnergy
        self.clippingFraction = clippingFraction
    }
}

/// A detected audio transient (candidate firework bang).
public struct AudioTransientCandidate: Sendable, Equatable {
    public var onsetTime: CaptureTimestamp
    public var peakTime: CaptureTimestamp
    public var peakEnergy: Double
    public var transientConfidence: Double
    /// Probability this transient is an echo, filled in by `EchoDetector` (0 here).
    public var echoProbability: Double
    public var clippingDetected: Bool

    public init(
        onsetTime: CaptureTimestamp,
        peakTime: CaptureTimestamp,
        peakEnergy: Double,
        transientConfidence: Double,
        echoProbability: Double = 0,
        clippingDetected: Bool = false
    ) {
        self.onsetTime = onsetTime
        self.peakTime = peakTime
        self.peakEnergy = peakEnergy
        self.transientConfidence = transientConfidence
        self.echoProbability = echoProbability
        self.clippingDetected = clippingDetected
    }
}

public struct AudioTransientDetectorConfig: Sendable {
    /// Frames used for the dynamic noise floor (updated only while idle).
    public var floorWindow: Int
    /// Energy must exceed `floor * onsetFactor` to start a transient.
    public var onsetFactor: Double
    /// Minimum spectral flux for a sharp onset.
    public var minSpectralFlux: Double
    /// Minimum low-band / total energy ratio (firework boom).
    public var minLowBandRatio: Double
    /// Peak is passed once energy falls below `peak * decayRatio`.
    public var decayRatio: Double
    /// Clipping-fraction threshold above which clipping is flagged.
    public var clippingThreshold: Double
    /// Safety cap on rising frames.
    public var maxRisingFrames: Int

    public init(
        floorWindow: Int = 30,
        onsetFactor: Double = 3.0,
        minSpectralFlux: Double = 0.1,
        minLowBandRatio: Double = 0.2,
        decayRatio: Double = 0.5,
        clippingThreshold: Double = 0.01,
        maxRisingFrames: Int = 40
    ) {
        self.floorWindow = floorWindow
        self.onsetFactor = onsetFactor
        self.minSpectralFlux = minSpectralFlux
        self.minLowBandRatio = minLowBandRatio
        self.decayRatio = decayRatio
        self.clippingThreshold = clippingThreshold
        self.maxRisingFrames = maxRisingFrames
    }
}

/// Deterministic, explainable bang detector. A transient starts when the energy rises
/// sharply above a dynamic noise floor with low-frequency content; it completes when the
/// energy decays. Handclaps/speech (little low band) are rejected. Clipping is flagged.
public final class AudioTransientDetector {
    private let config: AudioTransientDetectorConfig
    private var floorEnergies: [Double] = []
    private var rising = false
    private var onset: AudioFeatureFrame?
    private var peak: AudioFeatureFrame?
    private var risingFrames = 0
    private var clippingSeen = false

    public init(config: AudioTransientDetectorConfig = AudioTransientDetectorConfig()) {
        self.config = config
    }

    public func process(_ frame: AudioFeatureFrame) -> AudioTransientCandidate? {
        let floor = average(floorEnergies, fallback: frame.energy) + 1e-9

        if !rising {
            let loud = frame.energy >= floor * config.onsetFactor
            let sharp = frame.spectralFlux >= config.minSpectralFlux
            let lowBandRatio = frame.energy > 0 ? frame.lowBandEnergy / frame.energy : 0
            let boomy = lowBandRatio >= config.minLowBandRatio
            if loud && sharp && boomy {
                rising = true
                onset = frame
                peak = frame
                risingFrames = 0
                clippingSeen = frame.clippingFraction >= config.clippingThreshold
                return nil
            }
            pushFloor(frame)
            return nil
        }

        risingFrames += 1
        if frame.clippingFraction >= config.clippingThreshold { clippingSeen = true }
        if let currentPeak = peak, frame.energy > currentPeak.energy { peak = frame }
        let trackedPeak = peak?.energy ?? frame.energy
        let peaked = frame.energy < trackedPeak * config.decayRatio
        if !peaked && risingFrames < config.maxRisingFrames { return nil }

        let candidate = makeCandidate(floor: floor)
        rising = false
        onset = nil
        peak = nil
        risingFrames = 0
        clippingSeen = false
        pushFloor(frame)
        return candidate
    }

    private func makeCandidate(floor: Double) -> AudioTransientCandidate {
        let onset = self.onset ?? self.peak!
        let peak = self.peak ?? onset
        let lowBandRatio = peak.energy > 0 ? peak.lowBandEnergy / peak.energy : 0
        let snr = clamp01((peak.energy / floor - config.onsetFactor) / config.onsetFactor)
        let flux = clamp01(peak.spectralFlux / 0.5)
        let boom = clamp01(lowBandRatio / 0.5)
        let confidence = clamp01(0.4 * snr + 0.3 * flux + 0.3 * boom - (clippingSeen ? 0.1 : 0.0))
        return AudioTransientCandidate(
            onsetTime: onset.time,
            peakTime: peak.time,
            peakEnergy: peak.energy,
            transientConfidence: confidence,
            echoProbability: 0,
            clippingDetected: clippingSeen
        )
    }

    private func pushFloor(_ frame: AudioFeatureFrame) {
        floorEnergies.append(frame.energy)
        if floorEnergies.count > config.floorWindow { floorEnergies.removeFirst() }
    }

    private func average(_ values: [Double], fallback: Double) -> Double {
        values.isEmpty ? fallback : values.reduce(0, +) / Double(values.count)
    }

    private func clamp01(_ value: Double) -> Double {
        Swift.max(0.0, Swift.min(1.0, value))
    }
}
