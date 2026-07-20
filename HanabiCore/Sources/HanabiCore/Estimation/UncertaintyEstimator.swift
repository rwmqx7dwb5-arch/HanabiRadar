import Foundation

/// Propagates input uncertainty into the burst position via Monte Carlo sampling.
///
/// Each draw perturbs the flash-to-bang delay, temperature, wind, sound-speed model,
/// pointing (heading + tilt), and observer location, re-runs the deterministic solver,
/// and the ensemble yields distance/altitude 95% intervals, a horizontal 95% ellipse,
/// an overall confidence, and the dominant contributing factor.
public struct UncertaintyEstimator: Sendable {

    /// One-sigma input uncertainties plus sampling controls. Defaults are typical
    /// hand-held values; the app overrides them from live sensor accuracies.
    public struct Inputs: Sendable {
        public var deltaTSigma: Double        // s
        public var temperatureSigma: Double    // C
        public var headingSigma: Double        // deg, rotation about vertical
        public var elevationSigma: Double      // deg, ray tilt
        public var attitudeSigma: Double       // deg, general tilt
        public var horizontalAccuracy: Double  // m, GPS radial
        public var verticalAccuracy: Double    // m
        public var soundSpeedSigma: Double     // m/s, model error
        public var windSpeedSigma: Double      // m/s
        public var pairingConfidence: Double   // 0...1
        public var sampleCount: Int
        public var seed: UInt64

        public init(
            deltaTSigma: Double = 0.03,
            temperatureSigma: Double = 2.0,
            headingSigma: Double = 5.0,
            elevationSigma: Double = 1.5,
            attitudeSigma: Double = 1.0,
            horizontalAccuracy: Double = 10.0,
            verticalAccuracy: Double = 15.0,
            soundSpeedSigma: Double = 1.0,
            windSpeedSigma: Double = 1.5,
            pairingConfidence: Double = 1.0,
            sampleCount: Int = 2000,
            seed: UInt64 = 0x484D_4152_4144_4152
        ) {
            self.deltaTSigma = deltaTSigma
            self.temperatureSigma = temperatureSigma
            self.headingSigma = headingSigma
            self.elevationSigma = elevationSigma
            self.attitudeSigma = attitudeSigma
            self.horizontalAccuracy = horizontalAccuracy
            self.verticalAccuracy = verticalAccuracy
            self.soundSpeedSigma = soundSpeedSigma
            self.windSpeedSigma = windSpeedSigma
            self.pairingConfidence = pairingConfidence
            self.sampleCount = sampleCount
            self.seed = seed
        }
    }

    private let solver = BurstSolver()
    private let soundModel = SoundSpeedModel()

    public init() {}

    public func evaluate(
        observer: GeodeticCoordinate,
        enuRay ray: Vector3,
        deltaT: Double,
        weather: WeatherConditions,
        inputs: Inputs
    ) -> UncertaintyResult {
        let unit = ray.normalized()
        let pathBurstToObserver = -unit

        let nominalSpeed = soundModel.effectiveSpeed(
            temperatureCelsius: weather.temperatureCelsius,
            relativeHumidity: weather.relativeHumidity,
            pressureHPa: weather.pressureHPa,
            windENU: weather.windVectorENU,
            pathUnitBurstToObserver: pathBurstToObserver
        )
        let nominal = solver.estimate(
            observer: observer,
            enuRay: unit,
            deltaT: deltaT,
            effectiveSoundSpeed: nominalSpeed,
            iterations: 0
        )
        let originBurst = nominal.burst

        var rng = SplitMix64(seed: inputs.seed)
        let deg2rad = Double.pi / 180.0
        let sqrt2 = 2.0.squareRoot()
        let headingSigmaRad = inputs.headingSigma * deg2rad
        let tiltSigmaRad = (inputs.elevationSigma * inputs.elevationSigma
            + inputs.attitudeSigma * inputs.attitudeSigma).squareRoot() * deg2rad
        let perAxisTilt = tiltSigmaRad / sqrt2
        let upAxis = Vector3(0, 0, 1)
        let eastAxis = Vector3(1, 0, 0)
        let northAxis = Vector3(0, 1, 0)

        let n = Swift.max(1, inputs.sampleCount)
        var distances = [Double](); distances.reserveCapacity(n)
        var easts = [Double](); easts.reserveCapacity(n)
        var norths = [Double](); norths.reserveCapacity(n)
        var altitudes = [Double](); altitudes.reserveCapacity(n)

        for _ in 0..<n {
            let dt = deltaT + Gaussian.sample(mean: 0, standardDeviation: inputs.deltaTSigma, using: &rng)
            let temp = weather.temperatureCelsius
                + Gaussian.sample(mean: 0, standardDeviation: inputs.temperatureSigma, using: &rng)

            let windE = weather.windVectorENU.x
                + Gaussian.sample(mean: 0, standardDeviation: inputs.windSpeedSigma / sqrt2, using: &rng)
            let windN = weather.windVectorENU.y
                + Gaussian.sample(mean: 0, standardDeviation: inputs.windSpeedSigma / sqrt2, using: &rng)
            let windENU = Vector3(windE, windN, 0)

            let base = soundModel.drySpeed(temperatureCelsius: temp)
                + soundModel.humidityCorrection(
                    temperatureCelsius: temp,
                    relativeHumidity: weather.relativeHumidity,
                    pressureHPa: weather.pressureHPa
                )
            let modelNoise = Gaussian.sample(mean: 0, standardDeviation: inputs.soundSpeedSigma, using: &rng)

            let yaw = Gaussian.sample(mean: 0, standardDeviation: headingSigmaRad, using: &rng)
            let tiltE = Gaussian.sample(mean: 0, standardDeviation: perAxisTilt, using: &rng)
            let tiltN = Gaussian.sample(mean: 0, standardDeviation: perAxisTilt, using: &rng)
            var perturbedRay = Quaternion(axis: upAxis, angle: yaw).act(on: unit)
            perturbedRay = Quaternion(axis: eastAxis, angle: tiltE).act(on: perturbedRay)
            perturbedRay = Quaternion(axis: northAxis, angle: tiltN).act(on: perturbedRay)
            perturbedRay = perturbedRay.normalized()

            let along = windENU.dot((-perturbedRay).normalized())
            let speed = base + modelNoise + along

            let offsetE = Gaussian.sample(mean: 0, standardDeviation: inputs.horizontalAccuracy / sqrt2, using: &rng)
            let offsetN = Gaussian.sample(mean: 0, standardDeviation: inputs.horizontalAccuracy / sqrt2, using: &rng)
            let offsetU = Gaussian.sample(mean: 0, standardDeviation: inputs.verticalAccuracy, using: &rng)
            let perturbedObserver = Geodesy.coordinate(
                from: observer,
                enuOffset: Vector3(offsetE, offsetN, offsetU)
            )

            let estimate = solver.estimate(
                observer: perturbedObserver,
                enuRay: perturbedRay,
                deltaT: dt,
                effectiveSoundSpeed: speed,
                iterations: 0
            )
            distances.append(estimate.lineOfSightDistance)
            let offset = Geodesy.enuOffset(of: estimate.burst, from: originBurst)
            easts.append(offset.x)
            norths.append(offset.y)
            altitudes.append(estimate.burst.altitude)
        }

        let sortedDistances = distances.sorted()
        let distanceMedian = Statistics.percentileSorted(sortedDistances, 0.5)
        let distanceLow = Statistics.percentileSorted(sortedDistances, 0.025)
        let distanceHigh = Statistics.percentileSorted(sortedDistances, 0.975)

        let altitudeMedian = Statistics.percentile(altitudes, 0.5)
        let altitudeLow = Statistics.percentile(altitudes, 0.025)
        let altitudeHigh = Statistics.percentile(altitudes, 0.975)

        let meanE = Statistics.mean(easts)
        let meanN = Statistics.mean(norths)
        var sxx = 0.0, syy = 0.0, sxy = 0.0
        for i in 0..<easts.count {
            let de = easts[i] - meanE
            let dn = norths[i] - meanN
            sxx += de * de
            syy += dn * dn
            sxy += de * dn
        }
        let denom = Double(Swift.max(1, easts.count - 1))
        sxx /= denom; syy /= denom; sxy /= denom

        let axes = Statistics.ellipse2D(covXX: sxx, covXY: sxy, covYY: syy, chiSquare: 5.991)
        var orientation = atan2(axes.majorAxisEast, axes.majorAxisNorth) * 180.0 / .pi
        orientation = orientation.truncatingRemainder(dividingBy: 180)
        if orientation < 0 { orientation += 180 }
        let ellipse = ErrorEllipse(
            semiMajorMeters: axes.semiMajor,
            semiMinorMeters: axes.semiMinor,
            orientationDegrees: orientation
        )

        let center = Geodesy.coordinate(from: originBurst, enuOffset: Vector3(meanE, meanN, 0))

        let (confidence, category) = confidenceScore(
            distanceMedian: distanceMedian,
            distanceLow: distanceLow,
            distanceHigh: distanceHigh,
            semiMajor: axes.semiMajor,
            pairing: inputs.pairingConfidence
        )
        let dominant = dominantFactor(
            distance: distanceMedian,
            effectiveSoundSpeed: nominalSpeed,
            deltaT: deltaT,
            inputs: inputs
        )

        return UncertaintyResult(
            distanceMedian: distanceMedian,
            distanceLow95: distanceLow,
            distanceHigh95: distanceHigh,
            centerLatitude: center.latitude,
            centerLongitude: center.longitude,
            horizontalEllipse: ellipse,
            altitudeMedian: altitudeMedian,
            altitudeLow95: altitudeLow,
            altitudeHigh95: altitudeHigh,
            confidence: confidence,
            confidenceCategory: category,
            dominantFactor: dominant,
            sampleCount: n
        )
    }

    private func confidenceScore(
        distanceMedian: Double,
        distanceLow: Double,
        distanceHigh: Double,
        semiMajor: Double,
        pairing: Double
    ) -> (Double, ConfidenceCategory) {
        let relativeError = distanceMedian > 0 ? (distanceHigh - distanceLow) / (2.0 * distanceMedian) : 1.0
        let rangeScore = 1.0 / (1.0 + pow(relativeError / 0.08, 2))
        let horizontalScore = 1.0 / (1.0 + pow(semiMajor / 200.0, 2))
        let pairingScore = Swift.max(0, Swift.min(1, pairing))
        let score = pow(rangeScore, 0.4) * pow(horizontalScore, 0.4) * pow(pairingScore, 0.2)
        let category: ConfidenceCategory = score >= 0.66 ? .high : (score >= 0.33 ? .medium : .low)
        return (score, category)
    }

    private func dominantFactor(
        distance: Double,
        effectiveSoundSpeed: Double,
        deltaT: Double,
        inputs: Inputs
    ) -> UncertaintyFactor {
        let deg2rad = Double.pi / 180.0
        let deltaTMeters = effectiveSoundSpeed * inputs.deltaTSigma
        let temperatureMeters = deltaT * 0.6 * inputs.temperatureSigma       // dc/dT ~ 0.6 m/s per C
        let soundSpeedMeters = deltaT * (inputs.soundSpeedSigma * inputs.soundSpeedSigma
            + inputs.windSpeedSigma * inputs.windSpeedSigma).squareRoot()
        let headingMeters = distance * inputs.headingSigma * deg2rad
        let elevationMeters = distance * inputs.elevationSigma * deg2rad
        let attitudeMeters = distance * inputs.attitudeSigma * deg2rad
        let pairingMeters = distance * (1.0 - Swift.max(0, Swift.min(1, inputs.pairingConfidence))) * 0.5

        let table: [(UncertaintyFactor, Double)] = [
            (.timeDifference, deltaTMeters),
            (.temperature, temperatureMeters),
            (.soundSpeed, soundSpeedMeters),
            (.heading, headingMeters),
            (.elevationAngle, elevationMeters),
            (.attitude, attitudeMeters),
            (.gpsHorizontal, inputs.horizontalAccuracy),
            (.gpsVertical, inputs.verticalAccuracy),
            (.pairing, pairingMeters)
        ]
        return table.max(by: { $0.1 < $1.1 })?.0 ?? .timeDifference
    }
}
