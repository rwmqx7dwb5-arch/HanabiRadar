import HanabiCore

/// A detected, paired burst turned into an estimator input.
public struct DetectedSighting: Sendable {
    public var sighting: BurstSolver.Sighting
    public var pairingConfidence: Double
    public var flashConfidence: Double
    public var audioConfidence: Double
    public var echoProbability: Double

    public init(
        sighting: BurstSolver.Sighting,
        pairingConfidence: Double,
        flashConfidence: Double,
        audioConfidence: Double,
        echoProbability: Double
    ) {
        self.sighting = sighting
        self.pairingConfidence = pairingConfidence
        self.flashConfidence = flashConfidence
        self.audioConfidence = audioConfidence
        self.echoProbability = echoProbability
    }
}

/// Ties detection to estimation: runs the flash/audio/echo detectors and the pairing
/// engine over feature streams, then, at each flash onset, reads the interpolated
/// attitude (device->ENU) and nearest observer location from the timeline and builds a
/// `BurstSolver.Sighting`. The app passes each sighting to `BurstSolver.solve`.
///
/// The timeline's stored attitude is the resolved device->ENU rotation; converting Core
/// Motion attitude into device->ENU is the (device-verified) capture layer's job.
public struct BurstPipeline: Sendable {
    public var flashConfig: FlashDetectorConfig
    public var audioConfig: AudioTransientDetectorConfig
    public var echoConfig: EchoDetectorConfig
    public var pairingConfig: PairingConfig

    public init(
        flashConfig: FlashDetectorConfig = FlashDetectorConfig(),
        audioConfig: AudioTransientDetectorConfig = AudioTransientDetectorConfig(),
        echoConfig: EchoDetectorConfig = EchoDetectorConfig(),
        pairingConfig: PairingConfig = PairingConfig()
    ) {
        self.flashConfig = flashConfig
        self.audioConfig = audioConfig
        self.echoConfig = echoConfig
        self.pairingConfig = pairingConfig
    }

    public func process(
        frames: [FrameLuminanceSample],
        audio: [AudioFeatureFrame],
        timeline: SynchronizedTimeline,
        intrinsics: CameraIntrinsics,
        cameraToDevice: Quaternion = .identity
    ) -> [DetectedSighting] {
        let flashDetector = FlashDetector(config: flashConfig)
        let audioDetector = AudioTransientDetector(config: audioConfig)
        let flashes = frames.compactMap { flashDetector.process($0) }
        let transients = audio.compactMap { audioDetector.process($0) }
        let annotated = EchoDetector(config: echoConfig).annotate(transients)
        let bursts = EventPairingEngine().pair(flashes: flashes, audio: annotated, config: pairingConfig)

        var sightings: [DetectedSighting] = []
        for burst in bursts {
            let pairing = burst.best
            guard let deviceToENU = timeline.interpolatedAttitude(at: pairing.flash.onsetTime),
                  let observer = timeline.nearestLocation(at: pairing.flash.onsetTime)?.sample else {
                continue
            }
            let imagePoint = ImagePoint(
                u: pairing.flash.centroid.x * intrinsics.width,
                v: pairing.flash.centroid.y * intrinsics.height
            )
            let sighting = BurstSolver.Sighting(
                observer: observer.coordinate,
                imagePoint: imagePoint,
                intrinsics: intrinsics,
                cameraToDevice: cameraToDevice,
                deviceToENU: deviceToENU,
                deltaT: pairing.deltaT
            )
            sightings.append(DetectedSighting(
                sighting: sighting,
                pairingConfidence: pairing.pairingConfidence,
                flashConfidence: pairing.flash.visualConfidence,
                audioConfidence: pairing.audio.transientConfidence,
                echoProbability: pairing.audio.echoProbability
            ))
        }
        return sightings
    }
}
