import Foundation

extension UncertaintyEstimator.Inputs {

    /// Builds Monte Carlo input sigmas from the live measurement conditions, so the error
    /// bars reflect the ACTUAL sensor accuracies rather than fixed defaults (§14).
    ///
    /// - The flash-to-bang delay sigma combines the flash-onset quantization (one video
    ///   frame period — higher frame rates help) with a bang-onset detection sigma
    ///   (detection + mild reverberation; not sample-rate limited).
    /// - Heading accuracy from Core Location maps directly to the pointing yaw sigma
    ///   (floored at 1° so a wildly optimistic report never collapses the ellipse).
    /// - GPS horizontal / vertical accuracies pass through as the observer position sigmas.
    /// - `elevationSigma` / `attitudeSigma` stay conservative defaults until a live tilt
    ///   accuracy is available; residuals are folded into the ensemble either way.
    public static func fromMeasurement(
        horizontalAccuracy: Double,
        verticalAccuracy: Double,
        headingAccuracyDegrees: Double,
        frameRate: Double,
        pairingConfidence: Double,
        bangOnsetSigmaSeconds: Double = 0.003,
        temperatureSigma: Double = 2.0,
        elevationSigma: Double = 1.5,
        attitudeSigma: Double = 1.0,
        soundSpeedSigma: Double = 1.0,
        windSpeedSigma: Double = 1.5,
        sampleCount: Int = 2000
    ) -> UncertaintyEstimator.Inputs {
        let frameSigma = frameRate > 0 ? 1.0 / frameRate : 1.0 / 30.0
        let bang = Swift.max(0, bangOnsetSigmaSeconds)
        let deltaTSigma = (frameSigma * frameSigma + bang * bang).squareRoot()
        let headingSigma = Swift.max(1.0, headingAccuracyDegrees)

        return UncertaintyEstimator.Inputs(
            deltaTSigma: deltaTSigma,
            temperatureSigma: temperatureSigma,
            headingSigma: headingSigma,
            elevationSigma: elevationSigma,
            attitudeSigma: attitudeSigma,
            horizontalAccuracy: Swift.max(0, horizontalAccuracy),
            verticalAccuracy: Swift.max(0, verticalAccuracy),
            soundSpeedSigma: soundSpeedSigma,
            windSpeedSigma: windSpeedSigma,
            pairingConfidence: Swift.max(0, Swift.min(1, pairingConfidence)),
            sampleCount: sampleCount
        )
    }
}
