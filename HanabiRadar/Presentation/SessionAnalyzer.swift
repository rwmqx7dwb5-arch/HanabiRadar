import Foundation
import HanabiCore
import HanabiCapture

/// Turns a session's detected candidates into an honest result. It pairs the flash/audio
/// candidates into sightings (the tested `BurstPipeline` tail), picks the most confident
/// burst, and runs `BurstSolver` + `UncertaintyEstimator` so the result screen shows a real
/// estimate with Monte Carlo error bars. Pure orchestration over the tested core.
struct SessionAnalyzer {

    struct Result {
        /// The most confident burst, shown on the result screen.
        var estimate: BurstEstimate
        var uncertainty: UncertaintyResult
        /// Representative observer for the session (the best burst's observer), used when
        /// persisting the session summary.
        var observer: GeodeticCoordinate
        /// Session-level launch-area summary aggregated over every paired burst — the input
        /// to the saved history record (§16.4).
        var summary: SessionSummary
        /// Total sightings paired this session (the result shows the most confident one).
        var sightingCount: Int
    }

    /// Live conditions used to size the error bars honestly (§14): the observer's weather
    /// plus the sensor accuracies in effect during the measurement.
    struct Conditions {
        var weather: WeatherConditions
        var horizontalAccuracy: Double
        var verticalAccuracy: Double
        var headingAccuracyDegrees: Double
        var frameRate: Double
    }

    /// Returns the best burst's estimate + uncertainty, or `nil` when no flash/audio pair
    /// could be formed (nothing to show honestly).
    func analyze(
        flashes: [FlashCandidate],
        transients: [AudioTransientCandidate],
        timeline: SynchronizedTimeline,
        intrinsics: CameraIntrinsics,
        conditions: Conditions
    ) async -> Result? {
        let sightings = BurstPipeline().sightings(
            flashes: flashes, transients: transients, timeline: timeline, intrinsics: intrinsics
        )
        guard sightings.isEmpty == false else { return nil }

        let solver = BurstSolver()

        // Deterministic estimate for every burst (cheap: no weather/elevation providers),
        // aggregated into the session's launch-area summary.
        var sessionBursts: [SessionBurst] = []
        var estimateBySightingIndex: [Int: BurstEstimate] = [:]
        for (index, detected) in sightings.enumerated() {
            let estimate = await solver.solve(detected.sighting, observerWeather: conditions.weather)
            estimateBySightingIndex[index] = estimate
            sessionBursts.append(SessionBurst(
                id: "\(index)",
                subpoint: estimate.subpoint,
                confidence: burstConfidence(detected),
                lineOfSightDistance: estimate.lineOfSightDistance,
                burstAltitude: estimate.burst.altitude
            ))
        }
        let summary = SessionAggregator().summarize(sessionBursts)

        // The result screen shows the single most confident burst, with full uncertainty.
        let bestIndex = sightings.indices.max(by: {
            sightings[$0].pairingConfidence < sightings[$1].pairingConfidence
        }) ?? sightings.startIndex
        let best = sightings[bestIndex]
        let estimate = estimateBySightingIndex[bestIndex] ?? await solver.solve(best.sighting, observerWeather: conditions.weather)
        let ray = solver.enuRay(for: best.sighting)
        let inputs = UncertaintyEstimator.Inputs.fromMeasurement(
            horizontalAccuracy: conditions.horizontalAccuracy,
            verticalAccuracy: conditions.verticalAccuracy,
            headingAccuracyDegrees: conditions.headingAccuracyDegrees,
            frameRate: conditions.frameRate,
            pairingConfidence: best.pairingConfidence
        )
        let uncertainty = UncertaintyEstimator().evaluate(
            observer: best.sighting.observer,
            enuRay: ray,
            deltaT: best.sighting.deltaT,
            weather: conditions.weather,
            inputs: inputs
        )
        return Result(
            estimate: estimate,
            uncertainty: uncertainty,
            observer: best.sighting.observer,
            summary: summary,
            sightingCount: sightings.count
        )
    }

    /// A cheap per-burst confidence for clustering weight / gating: the product of the
    /// pairing, flash and audio confidences (all 0...1), so a weak flash, a weak bang, or a
    /// weak pairing each pulls the burst's influence down without a per-burst Monte Carlo run.
    private func burstConfidence(_ detected: DetectedSighting) -> Double {
        detected.pairingConfidence * detected.flashConfidence * detected.audioConfidence
    }
}
