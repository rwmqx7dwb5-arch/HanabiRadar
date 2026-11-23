import Foundation
import HanabiCore
import HanabiCapture
import CoreTransferable
import UniformTypeIdentifiers

/// A self-contained, serializable recording of what the estimator needs to reproduce a
/// measurement: the detected flash/bang candidates, the camera intrinsics, and the attitude
/// and location samples (§23 regression replay). All fields are plain numbers so the file
/// format is stable and human-inspectable; times are on the capture (uptime) axis in seconds.
struct RecordedMeasurement: Codable, Equatable {
    static let currentVersion = 1

    struct Attitude: Codable, Equatable { var t, w, x, y, z: Double }
    struct Location: Codable, Equatable { var t, latitude, longitude, altitude, horizontalAccuracy, verticalAccuracy: Double }
    struct Flash: Codable, Equatable {
        var onset, peak, centroidX, centroidY, peakLuminance, brightArea, visualConfidence: Double
        var atFrameEdge: Bool
    }
    struct Transient: Codable, Equatable {
        var onset, peak, peakEnergy, transientConfidence, echoProbability: Double
        var clippingDetected: Bool
    }
    struct Intrinsics: Codable, Equatable { var fx, fy, cx, cy, width, height: Double }

    var version = RecordedMeasurement.currentVersion
    var note: String?
    var temperatureCelsius = 20.0
    var intrinsics: Intrinsics
    var attitudes: [Attitude]
    var locations: [Location]
    var flashes: [Flash]
    var transients: [Transient]

    enum LoadError: Error, Equatable {
        case unsupportedVersion(Int)
        case empty
    }

    // MARK: Decode

    static func decode(_ data: Data) throws -> RecordedMeasurement {
        let measurement = try JSONDecoder().decode(RecordedMeasurement.self, from: data)
        guard measurement.version == currentVersion else { throw LoadError.unsupportedVersion(measurement.version) }
        guard measurement.flashes.isEmpty == false, measurement.transients.isEmpty == false,
              measurement.locations.isEmpty == false, measurement.attitudes.isEmpty == false else {
            throw LoadError.empty
        }
        return measurement
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    // MARK: Convert to engine types

    func timeline() -> SynchronizedTimeline {
        var timeline = SynchronizedTimeline(capacity: Swift.max(200, attitudes.count + locations.count + 16))
        for a in attitudes {
            timeline.recordAttitude(Quaternion(w: a.w, x: a.x, y: a.y, z: a.z), at: CaptureTimestamp(seconds: a.t))
        }
        for l in locations {
            timeline.recordLocation(
                LocationSample(
                    coordinate: GeodeticCoordinate(latitude: l.latitude, longitude: l.longitude, altitude: l.altitude),
                    horizontalAccuracy: l.horizontalAccuracy, verticalAccuracy: l.verticalAccuracy
                ),
                at: CaptureTimestamp(seconds: l.t)
            )
        }
        return timeline
    }

    func flashCandidates() -> [FlashCandidate] {
        flashes.map {
            FlashCandidate(
                onsetTime: CaptureTimestamp(seconds: $0.onset), peakTime: CaptureTimestamp(seconds: $0.peak),
                centroid: NormalizedPoint(x: $0.centroidX, y: $0.centroidY),
                peakLuminance: $0.peakLuminance, brightArea: $0.brightArea,
                visualConfidence: $0.visualConfidence, atFrameEdge: $0.atFrameEdge
            )
        }
    }

    func transientCandidates() -> [AudioTransientCandidate] {
        transients.map {
            AudioTransientCandidate(
                onsetTime: CaptureTimestamp(seconds: $0.onset), peakTime: CaptureTimestamp(seconds: $0.peak),
                peakEnergy: $0.peakEnergy, transientConfidence: $0.transientConfidence,
                echoProbability: $0.echoProbability, clippingDetected: $0.clippingDetected
            )
        }
    }

    func cameraIntrinsics() -> CameraIntrinsics {
        CameraIntrinsics(
            fx: intrinsics.fx, fy: intrinsics.fy, cx: intrinsics.cx, cy: intrinsics.cy,
            width: intrinsics.width, height: intrinsics.height
        )
    }

    /// Re-runs the production analysis (pairing → estimate → Monte Carlo) on the recording,
    /// with no network providers so the replay is deterministic.
    func replay() async -> SessionAnalyzer.Result? {
        let accuracy = timeline().locationAccuracySummary()
        let conditions = SessionAnalyzer.Conditions(
            weather: WeatherConditions(temperatureCelsius: temperatureCelsius),
            horizontalAccuracy: accuracy?.horizontal ?? 10,
            verticalAccuracy: accuracy?.vertical ?? 15,
            headingAccuracyDegrees: 6,
            frameRate: 30
        )
        return await SessionAnalyzer().analyze(
            flashes: flashCandidates(), transients: transientCandidates(),
            timeline: timeline(), intrinsics: cameraIntrinsics(), conditions: conditions
        )
    }

    // MARK: Live recording

    /// Snapshots a live session (the exact inputs `SessionAnalyzer` consumed) so it can be
    /// exported and replayed later for regression. Heading samples are not part of the format
    /// (the estimator derives orientation from the attitude quaternion).
    static func capture(
        flashes: [FlashCandidate],
        transients: [AudioTransientCandidate],
        timeline: SynchronizedTimeline,
        intrinsics: CameraIntrinsics,
        temperatureCelsius: Double,
        note: String? = nil
    ) -> RecordedMeasurement {
        RecordedMeasurement(
            note: note,
            temperatureCelsius: temperatureCelsius,
            intrinsics: Intrinsics(
                fx: intrinsics.fx, fy: intrinsics.fy, cx: intrinsics.cx, cy: intrinsics.cy,
                width: intrinsics.width, height: intrinsics.height
            ),
            attitudes: timeline.attitude.orderedItems.map {
                Attitude(t: $0.time.seconds, w: $0.value.w, x: $0.value.x, y: $0.value.y, z: $0.value.z)
            },
            locations: timeline.location.orderedItems.map {
                Location(
                    t: $0.time.seconds, latitude: $0.value.coordinate.latitude,
                    longitude: $0.value.coordinate.longitude, altitude: $0.value.coordinate.altitude,
                    horizontalAccuracy: $0.value.horizontalAccuracy, verticalAccuracy: $0.value.verticalAccuracy
                )
            },
            flashes: flashes.map {
                Flash(
                    onset: $0.onsetTime.seconds, peak: $0.peakTime.seconds,
                    centroidX: $0.centroid.x, centroidY: $0.centroid.y,
                    peakLuminance: $0.peakLuminance, brightArea: $0.brightArea,
                    visualConfidence: $0.visualConfidence, atFrameEdge: $0.atFrameEdge
                )
            },
            transients: transients.map {
                Transient(
                    onset: $0.onsetTime.seconds, peak: $0.peakTime.seconds, peakEnergy: $0.peakEnergy,
                    transientConfidence: $0.transientConfidence, echoProbability: $0.echoProbability,
                    clippingDetected: $0.clippingDetected
                )
            }
        )
    }

    // MARK: Sample recording

    /// The self-test scenario as a recording, so the file format can be exported, inspected
    /// and re-imported on a device without any real fireworks.
    static func syntheticSample() -> RecordedMeasurement {
        let azimuth = 60.0 * .pi / 180
        let elevation = 42.0 * .pi / 180
        let distance = 1800.0
        let ray = Vector3(cos(elevation) * sin(azimuth), cos(elevation) * cos(azimuth), sin(elevation))
        let q = Quaternion(from: Vector3(0, 0, 1), to: ray)
        let flashOnset = 100.0
        let deltaT = distance / SoundSpeedModel().drySpeed(temperatureCelsius: 20)
        return RecordedMeasurement(
            note: "Synthetic known-truth scenario (distance 1800 m, azimuth 60°, elevation 42°).",
            intrinsics: Intrinsics(fx: 1600, fy: 1600, cx: 960, cy: 540, width: 1920, height: 1080),
            attitudes: [
                Attitude(t: flashOnset - 0.1, w: q.w, x: q.x, y: q.y, z: q.z),
                Attitude(t: flashOnset + 0.1, w: q.w, x: q.x, y: q.y, z: q.z)
            ],
            locations: [
                Location(
                    t: flashOnset, latitude: 35.681, longitude: 139.767, altitude: 30,
                    horizontalAccuracy: 5, verticalAccuracy: 8
                )
            ],
            flashes: [
                Flash(
                    onset: flashOnset, peak: flashOnset + 0.01, centroidX: 0.5, centroidY: 0.5,
                    peakLuminance: 0.9, brightArea: 0.05, visualConfidence: 0.9, atFrameEdge: false
                )
            ],
            transients: [
                Transient(
                    onset: flashOnset + deltaT, peak: flashOnset + deltaT + 0.01, peakEnergy: 0.7,
                    transientConfidence: 0.8, echoProbability: 0, clippingDetected: false
                )
            ]
        )
    }
}

/// A shareable JSON recording file (the synthetic sample, or a live session's recording).
struct RecordingFile: Transferable {
    let fileName: String
    let data: Data

    init?(_ measurement: RecordedMeasurement, fileName: String) {
        guard let encoded = try? measurement.encoded() else { return nil }
        self.fileName = fileName
        self.data = encoded
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.fileName)
            try file.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
