import Foundation

/// Estimates a single burst position from a flash-to-bang measurement.
///
/// The pipeline is: pixel + intrinsics -> camera ray -> ENU ray -> slant distance
/// (from the sound delay and effective sound speed) -> ECEF -> geodetic. Weather is
/// applied by iterating: the first pass uses the observer's temperature; each further
/// pass re-queries conditions at the current burst estimate and blends them along the
/// path until the distance stops changing.
public struct BurstSolver: Sendable {

    /// The measured inputs for one burst.
    public struct Sighting: Sendable {
        public var observer: GeodeticCoordinate
        public var imagePoint: ImagePoint
        public var intrinsics: CameraIntrinsics
        /// Mounting rotation: camera axes -> device axes (device-verified).
        public var cameraToDevice: Quaternion
        /// Attitude rotation: device axes -> local ENU at the flash time.
        public var deviceToENU: Quaternion
        /// Flash-to-bang delay in seconds.
        public var deltaT: Double

        public init(
            observer: GeodeticCoordinate,
            imagePoint: ImagePoint,
            intrinsics: CameraIntrinsics,
            cameraToDevice: Quaternion = .identity,
            deviceToENU: Quaternion,
            deltaT: Double
        ) {
            self.observer = observer
            self.imagePoint = imagePoint
            self.intrinsics = intrinsics
            self.cameraToDevice = cameraToDevice
            self.deviceToENU = deviceToENU
            self.deltaT = deltaT
        }
    }

    public struct Options: Sendable {
        public var maxIterations: Int
        public var convergenceMeters: Double

        public init(maxIterations: Int = 4, convergenceMeters: Double = 5.0) {
            self.maxIterations = maxIterations
            self.convergenceMeters = convergenceMeters
        }
    }

    private let soundModel = SoundSpeedModel()

    public init() {}

    /// The ENU line-of-sight unit ray for a sighting.
    public func enuRay(for sighting: Sighting) -> Vector3 {
        let cameraRay = CameraRaySolver.cameraRay(from: sighting.imagePoint, intrinsics: sighting.intrinsics)
        return LineOfSight.enuRay(
            cameraRay: cameraRay,
            cameraToDevice: sighting.cameraToDevice,
            deviceToENU: sighting.deviceToENU
        )
    }

    /// Deterministic estimate for a KNOWN effective sound speed and ENU ray. This is
    /// the pure, synchronous kernel reused by Monte Carlo estimation.
    public func estimate(
        observer: GeodeticCoordinate,
        enuRay ray: Vector3,
        deltaT: Double,
        effectiveSoundSpeed c: Double,
        iterations: Int
    ) -> BurstEstimate {
        let unit = ray.normalized()
        let distance = c * deltaT
        let burst = Geodesy.coordinate(from: observer, enuOffset: unit * distance)
        let azimuth = LineOfSight.azimuthDegrees(enuRay: unit)
        let elevation = LineOfSight.elevationDegrees(enuRay: unit)
        let horizontal = distance * cos(elevation * Double.pi / 180.0)
        let subpoint = GeodeticCoordinate(
            latitude: burst.latitude,
            longitude: burst.longitude,
            altitude: observer.altitude
        )
        return BurstEstimate(
            burst: burst,
            subpoint: subpoint,
            lineOfSightDistance: distance,
            horizontalDistance: horizontal,
            azimuthDegrees: azimuth,
            elevationDegrees: elevation,
            relativeHeight: burst.altitude - observer.altitude,
            effectiveSoundSpeed: c,
            iterations: iterations,
            calculationVersion: CoreInfo.calculationVersion
        )
    }

    /// Full pipeline with iterative weather correction. When `weatherProvider` is nil,
    /// or a fetch fails, the result uses the observer-only conditions and reports how
    /// many iterations actually ran.
    public func solve(
        _ sighting: Sighting,
        observerWeather: WeatherConditions,
        weatherProvider: WeatherConditionsProviding? = nil,
        options: Options = Options()
    ) async -> BurstEstimate {
        let ray = enuRay(for: sighting)
        // Sound travels burst -> observer, i.e. along -ray.
        let pathBurstToObserver = -ray

        var speed = soundModel.effectiveSpeed(
            temperatureCelsius: observerWeather.temperatureCelsius,
            relativeHumidity: observerWeather.relativeHumidity,
            pressureHPa: observerWeather.pressureHPa,
            windENU: observerWeather.windVectorENU,
            pathUnitBurstToObserver: pathBurstToObserver
        )
        var current = estimate(
            observer: sighting.observer,
            enuRay: ray,
            deltaT: sighting.deltaT,
            effectiveSoundSpeed: speed,
            iterations: 0
        )

        guard let provider = weatherProvider else { return current }

        for iteration in 1...Swift.max(1, options.maxIterations) {
            let burstWeather: WeatherConditions
            do {
                burstWeather = try await provider.conditions(at: current.burst)
            } catch {
                break   // Fetch failed: keep the last good estimate.
            }
            let temperature = 0.5 * (observerWeather.temperatureCelsius + burstWeather.temperatureCelsius)
            let humidity = 0.5 * (observerWeather.relativeHumidity + burstWeather.relativeHumidity)
            let pressure = 0.5 * (observerWeather.pressureHPa + burstWeather.pressureHPa)
            let windMean = (observerWeather.windVectorENU + burstWeather.windVectorENU) * 0.5

            speed = soundModel.effectiveSpeed(
                temperatureCelsius: temperature,
                relativeHumidity: humidity,
                pressureHPa: pressure,
                windENU: windMean,
                pathUnitBurstToObserver: pathBurstToObserver
            )
            let next = estimate(
                observer: sighting.observer,
                enuRay: ray,
                deltaT: sighting.deltaT,
                effectiveSoundSpeed: speed,
                iterations: iteration
            )
            let moved = abs(next.lineOfSightDistance - current.lineOfSightDistance)
            current = next
            if moved < options.convergenceMeters { break }
        }
        return current
    }
}
