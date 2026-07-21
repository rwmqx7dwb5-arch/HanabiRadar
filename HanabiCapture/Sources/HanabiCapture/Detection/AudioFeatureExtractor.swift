import Foundation

/// Pure audio feature extraction for the bang detector. Fed batches of mono PCM samples on
/// the capture clock, it emits one `AudioFeatureFrame` per window (overlapping by default, so
/// onset timestamps land on a finer grid) with the short-time energy, low-band energy
/// (fireworks are low-frequency-heavy), spectral flux (onset sharpness) and clipping fraction
/// the detector consumes.
///
/// Energy and low-band energy are drawn from the same Hann-windowed magnitude spectrum, so
/// their ratio is a meaningful 0...1 "boominess". A small in-Swift FFT keeps the whole thing
/// deterministic and unit-testable — the detector never touches raw audio.
public final class AudioFeatureExtractor {

    public struct Config: Sendable {
        public var sampleRate: Double
        /// FFT window length; must be a power of two.
        public var windowSize: Int
        /// Stride between consecutive windows, in samples. A hop smaller than `windowSize`
        /// overlaps the windows, so onset/peak timestamps land on a finer grid (the frame
        /// period is `hopSize / sampleRate`). Clamped to `1...windowSize` in `init`.
        public var hopSize: Int
        /// Upper edge of the low band, in hertz.
        public var lowBandCutoffHz: Double
        /// |sample| at or above this counts as clipped.
        public var clippingThreshold: Float

        /// - Parameter hopSize: pass `nil` for 50% overlap (`windowSize / 2`), the default that
        ///   halves the frame period for tighter bang timing. Pass `windowSize` for the old
        ///   non-overlapping behavior.
        public init(
            sampleRate: Double = 48_000,
            windowSize: Int = 1_024,
            hopSize: Int? = nil,
            lowBandCutoffHz: Double = 400,
            clippingThreshold: Float = 0.98
        ) {
            self.sampleRate = sampleRate
            self.windowSize = windowSize
            self.hopSize = Swift.min(Swift.max(1, hopSize ?? windowSize / 2), Swift.max(1, windowSize))
            self.lowBandCutoffHz = lowBandCutoffHz
            self.clippingThreshold = clippingThreshold
        }
    }

    private let config: Config
    private var pending: [Float] = []
    private var previousSpectrum: [Double] = []
    private var referenceTime: CaptureTimestamp?
    /// Absolute sample index (since `referenceTime`) of the next window's first sample; the
    /// window timestamp is derived from it, so it advances by the hop, not the window length.
    private var nextWindowStart = 0

    public init(config: Config = Config()) {
        self.config = config
    }

    /// Feeds a batch of mono PCM samples whose first sample is at `startTime` on the capture
    /// clock, returning one frame per complete window. Consecutive windows advance by the hop
    /// (overlapping when `hopSize < windowSize`); the samples they still share are kept
    /// buffered for the next call so the stream is windowed continuously.
    public func process(_ samples: [Float], startTime: CaptureTimestamp) -> [AudioFeatureFrame] {
        if referenceTime == nil {
            referenceTime = startTime
        }
        pending.append(contentsOf: samples)

        var frames: [AudioFeatureFrame] = []
        let n = config.windowSize
        guard n >= 2 else { return frames }
        let hop = config.hopSize
        let base = referenceTime?.seconds ?? startTime.seconds
        while pending.count >= n {
            let window = Array(pending[0..<n])
            let time = CaptureTimestamp(seconds: base + Double(nextWindowStart) / config.sampleRate)
            frames.append(makeFrame(window, time: time))
            pending.removeFirst(hop)
            nextWindowStart += hop
        }
        return frames
    }

    /// Discards buffered samples and history (call on stop / route change).
    public func reset() {
        pending.removeAll()
        previousSpectrum.removeAll()
        referenceTime = nil
        nextWindowStart = 0
    }

    private func makeFrame(_ window: [Float], time: CaptureTimestamp) -> AudioFeatureFrame {
        let n = window.count

        var clipped = 0
        var windowed = [Double](repeating: 0, count: n)
        let denom = Double(max(n - 1, 1))
        for i in 0..<n {
            let sample = window[i]
            if abs(sample) >= config.clippingThreshold { clipped += 1 }
            // Hann window to limit spectral leakage.
            let hann = 0.5 - 0.5 * cos(2.0 * Double.pi * Double(i) / denom)
            windowed[i] = Double(sample) * hann
        }

        let mags = RealFFT.magnitudes(windowed)
        guard !mags.isEmpty else {
            return AudioFeatureFrame(
                time: time, energy: 0, spectralFlux: 0, lowBandEnergy: 0,
                clippingFraction: Double(clipped) / Double(n)
            )
        }

        let binHz = config.sampleRate / Double(n)
        let cutoffBin = max(1, min(mags.count, Int((config.lowBandCutoffHz / binHz).rounded())))
        var totalPower = 0.0
        var lowPower = 0.0
        var totalMag = 0.0
        var flux = 0.0
        let comparable = previousSpectrum.count == mags.count
        for k in 0..<mags.count {
            let m = mags[k]
            totalMag += m
            totalPower += m * m
            if k < cutoffBin { lowPower += m * m }
            if comparable {
                let rise = m - previousSpectrum[k]
                if rise > 0 { flux += rise }
            }
        }
        previousSpectrum = mags

        let energy = totalPower.squareRoot()
        let lowBandEnergy = lowPower.squareRoot()
        // Normalize flux by the current spectral magnitude so it is a scale-independent
        // onset measure in ~[0, 1] rather than growing with loudness.
        let normalizedFlux = totalMag > 0 ? flux / totalMag : 0

        return AudioFeatureFrame(
            time: time,
            energy: energy,
            spectralFlux: normalizedFlux,
            lowBandEnergy: lowBandEnergy,
            clippingFraction: Double(clipped) / Double(n)
        )
    }
}
