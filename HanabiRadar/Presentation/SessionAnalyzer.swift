import Foundation
import HanabiCore
import HanabiCapture

/// Turns a session's detected candidates into an honest result. It pairs the flash/audio
/// candidates into sightings (the tested `BurstPipeline` tail), picks the most confident
/// burst, and runs `BurstSolver` + `UncertaintyEstimator` so the result screen shows a real
/// estimate with Monte Carlo error bars. Pure orchestration over the tested core.
struct SessionAnalyzer {

    struct Result {
        var estimate: BurstEstimate
        var uncertainty: UncertaintyResult
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
        guard let best = sightings.max(by: { $0.pairingConfidence < $1.pairingConfidence }) else {
            return nil
        }

        let solver = BurstSolver()
        let estimate = await solver.solve(best.sighting, observerWeather: conditions.weather)
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
        return Result(estimate: estimate, uncertainty: uncertainty, sightingCount: sightings.count)
    }
}
