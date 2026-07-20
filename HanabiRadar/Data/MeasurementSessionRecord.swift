import Foundation
import SwiftData
import HanabiCore

/// A persisted summary of one measurement session — enough for the history screen
/// (§16.4) without storing the full per-burst graph. The estimation-core version is kept
/// so a record can be reconciled when the algorithms change (§17 `calculationVersion`).
@Model
final class MeasurementSessionRecord {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    /// Observer location summary (a single representative fix for the session).
    var latitude: Double
    var longitude: Double
    var deviceModel: String
    var appVersion: String
    var calculationVersion: String
    var burstCount: Int
    var usedBurstCount: Int
    /// Robust representative distance / altitude across the session's used bursts.
    var representativeDistanceMeters: Double?
    var representativeAltitudeMeters: Double?
    var launchClusterCount: Int
    /// 95% radius of the most-populous launch-area cluster, if any.
    var largestClusterRadiusMeters: Double?

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        latitude: Double,
        longitude: Double,
        deviceModel: String,
        appVersion: String,
        calculationVersion: String,
        burstCount: Int,
        usedBurstCount: Int,
        representativeDistanceMeters: Double?,
        representativeAltitudeMeters: Double?,
        launchClusterCount: Int,
        largestClusterRadiusMeters: Double?
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.latitude = latitude
        self.longitude = longitude
        self.deviceModel = deviceModel
        self.appVersion = appVersion
        self.calculationVersion = calculationVersion
        self.burstCount = burstCount
        self.usedBurstCount = usedBurstCount
        self.representativeDistanceMeters = representativeDistanceMeters
        self.representativeAltitudeMeters = representativeAltitudeMeters
        self.launchClusterCount = launchClusterCount
        self.largestClusterRadiusMeters = largestClusterRadiusMeters
    }
}

extension MeasurementSessionRecord {

    /// Builds a persistable summary from an aggregated session and its metadata. Keeps
    /// persistence decoupled from the pure core (`SessionSummary` stays framework-free).
    static func from(
        summary: SessionSummary,
        observer: GeodeticCoordinate,
        startedAt: Date,
        endedAt: Date,
        deviceModel: String,
        appVersion: String
    ) -> MeasurementSessionRecord {
        MeasurementSessionRecord(
            startedAt: startedAt,
            endedAt: endedAt,
            latitude: observer.latitude,
            longitude: observer.longitude,
            deviceModel: deviceModel,
            appVersion: appVersion,
            calculationVersion: CoreInfo.calculationVersion,
            burstCount: summary.burstCount,
            usedBurstCount: summary.usedBurstCount,
            representativeDistanceMeters: summary.representativeDistance,
            representativeAltitudeMeters: summary.representativeAltitude,
            launchClusterCount: summary.clusters.count,
            largestClusterRadiusMeters: summary.clusters.first?.confidenceRadiusMeters
        )
    }
}
