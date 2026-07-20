public struct EchoDetectorConfig: Sendable {
    /// Echoes arrive at least this long after the direct sound.
    public var minDelay: Double
    /// ...and at most this long after.
    public var maxDelay: Double
    /// An echo is at most this fraction as loud as the direct sound.
    public var quieterRatio: Double

    public init(minDelay: Double = 0.03, maxDelay: Double = 2.0, quieterRatio: Double = 0.8) {
        self.minDelay = minDelay
        self.maxDelay = maxDelay
        self.quieterRatio = quieterRatio
    }
}

/// Assigns each audio transient an echo probability: a transient that shortly follows a
/// louder one, and is quieter, is likely a reflection rather than a new bang.
public struct EchoDetector: Sendable {
    private let config: EchoDetectorConfig

    public init(config: EchoDetectorConfig = EchoDetectorConfig()) {
        self.config = config
    }

    public func annotate(_ transients: [AudioTransientCandidate]) -> [AudioTransientCandidate] {
        var result = transients.sorted { $0.peakTime.seconds < $1.peakTime.seconds }
        for i in result.indices {
            var echoProbability = 0.0
            for j in 0..<i {
                let delay = result[i].peakTime.seconds - result[j].peakTime.seconds
                guard delay >= config.minDelay, delay <= config.maxDelay else { continue }
                guard result[i].peakEnergy <= result[j].peakEnergy * config.quieterRatio else { continue }
                let quietness = clamp01(1.0 - result[i].peakEnergy / Swift.max(result[j].peakEnergy, 1e-9))
                let recency = clamp01(1.0 - delay / config.maxDelay)
                echoProbability = Swift.max(echoProbability, clamp01(0.5 * quietness + 0.5 * recency))
            }
            result[i].echoProbability = echoProbability
        }
        return result
    }

    private func clamp01(_ value: Double) -> Double {
        Swift.max(0.0, Swift.min(1.0, value))
    }
}
