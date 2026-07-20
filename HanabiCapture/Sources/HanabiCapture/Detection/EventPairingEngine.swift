public struct PairingConfig: Sendable {
    /// The flash-to-bang delay must be at least this (0.25 s ~ 85 m).
    public var minDeltaT: Double
    /// ...and at most this.
    public var maxDeltaT: Double

    public init(minDeltaT: Double = 0.25, maxDeltaT: Double = 30.0) {
        self.minDeltaT = minDeltaT
        self.maxDeltaT = maxDeltaT
    }
}

/// One flash paired with one audio transient.
public struct BurstPairing: Sendable, Equatable {
    public var flash: FlashCandidate
    public var audio: AudioTransientCandidate
    public var deltaT: Double
    public var pairingConfidence: Double
    public var isUserCorrected: Bool

    public init(
        flash: FlashCandidate,
        audio: AudioTransientCandidate,
        deltaT: Double,
        pairingConfidence: Double,
        isUserCorrected: Bool = false
    ) {
        self.flash = flash
        self.audio = audio
        self.deltaT = deltaT
        self.pairingConfidence = pairingConfidence
        self.isUserCorrected = isUserCorrected
    }
}

/// The best pairing for a flash plus the other plausible audio matches (kept so the user
/// can pick a different one when the choice is ambiguous).
public struct PairedBurst: Sendable {
    public var best: BurstPairing
    public var alternatives: [BurstPairing]

    public init(best: BurstPairing, alternatives: [BurstPairing]) {
        self.best = best
        self.alternatives = alternatives
    }
}

/// Pairs flashes with audio transients, keeping multiple hypotheses. It never assumes the
/// "next" sound is the match: candidates are scored by flash quality, audio quality, and
/// (1 - echo probability), within the physically plausible delay window.
public struct EventPairingEngine: Sendable {

    public init() {}

    public func pair(
        flashes: [FlashCandidate],
        audio: [AudioTransientCandidate],
        config: PairingConfig = PairingConfig()
    ) -> [PairedBurst] {
        var results: [PairedBurst] = []
        for flash in flashes.sorted(by: { $0.onsetTime.seconds < $1.onsetTime.seconds }) {
            var pairings: [BurstPairing] = []
            for transient in audio {
                let deltaT = transient.onsetTime.seconds - flash.onsetTime.seconds
                guard deltaT >= config.minDeltaT, deltaT <= config.maxDeltaT else { continue }
                pairings.append(BurstPairing(
                    flash: flash,
                    audio: transient,
                    deltaT: deltaT,
                    pairingConfidence: confidence(flash: flash, audio: transient)
                ))
            }
            guard !pairings.isEmpty else { continue }
            pairings.sort { lhs, rhs in
                if lhs.pairingConfidence != rhs.pairingConfidence {
                    return lhs.pairingConfidence > rhs.pairingConfidence
                }
                return lhs.deltaT < rhs.deltaT
            }
            results.append(PairedBurst(best: pairings[0], alternatives: Array(pairings.dropFirst())))
        }
        return results
    }

    /// Rebuilds a pairing with a user-chosen audio transient (manual correction).
    public func override(flash: FlashCandidate, with audio: AudioTransientCandidate) -> BurstPairing {
        BurstPairing(
            flash: flash,
            audio: audio,
            deltaT: audio.onsetTime.seconds - flash.onsetTime.seconds,
            pairingConfidence: confidence(flash: flash, audio: audio),
            isUserCorrected: true
        )
    }

    private func confidence(flash: FlashCandidate, audio: AudioTransientCandidate) -> Double {
        let value = flash.visualConfidence * audio.transientConfidence * (1.0 - audio.echoProbability)
        return Swift.max(0.0, Swift.min(1.0, value))
    }
}
