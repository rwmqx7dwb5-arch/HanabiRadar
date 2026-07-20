import Foundation

/// Serializes saved sessions to CSV / JSON / GeoJSON (§18, premium export). Pure and
/// deterministic (fixed field order, UTC ISO-8601 dates, sorted JSON keys), so the output
/// is unit-tested. Reads only the record's stored properties, so it needs no ModelContext.
enum SessionExporter {

    // MARK: CSV

    private static let csvColumns = [
        "id", "startedAt", "endedAt", "latitude", "longitude",
        "burstCount", "usedBurstCount", "representativeDistanceMeters",
        "representativeAltitudeMeters", "launchClusterCount",
        "largestClusterRadiusMeters", "calculationVersion"
    ]

    static func csv(_ records: [MeasurementSessionRecord]) -> String {
        var lines = [csvColumns.joined(separator: ",")]
        for record in records {
            let fields: [String] = [
                record.id.uuidString,
                iso(record.startedAt),
                iso(record.endedAt),
                String(format: "%.6f", record.latitude),
                String(format: "%.6f", record.longitude),
                String(record.burstCount),
                String(record.usedBurstCount),
                optNumber(record.representativeDistanceMeters),
                optNumber(record.representativeAltitudeMeters),
                String(record.launchClusterCount),
                optNumber(record.largestClusterRadiusMeters),
                record.calculationVersion
            ]
            lines.append(fields.map(csvEscape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: JSON / GeoJSON

    static func json(_ records: [MeasurementSessionRecord]) throws -> String {
        try encode(records.map(SessionDTO.init(record:)))
    }

    static func geoJSON(_ records: [MeasurementSessionRecord]) throws -> String {
        let features = records.map { record in
            GeoFeature(
                geometry: .init(coordinates: [record.longitude, record.latitude]),   // GeoJSON = [lon, lat]
                properties: SessionDTO(record: record)
            )
        }
        return try encode(GeoFeatureCollection(features: features))
    }

    // MARK: - Helpers

    private static let isoFormatter = ISO8601DateFormatter()

    private static func iso(_ date: Date) -> String { isoFormatter.string(from: date) }

    private static func optNumber(_ value: Double?) -> String {
        value.map { String(format: "%.2f", $0) } ?? ""
    }

    private static func csvEscape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}

/// A flat, Codable projection of a session record for JSON/GeoJSON export.
private struct SessionDTO: Encodable {
    let id: String
    let startedAt: String
    let endedAt: String
    let latitude: Double
    let longitude: Double
    let burstCount: Int
    let usedBurstCount: Int
    let representativeDistanceMeters: Double?
    let representativeAltitudeMeters: Double?
    let launchClusterCount: Int
    let largestClusterRadiusMeters: Double?
    let calculationVersion: String

    init(record: MeasurementSessionRecord) {
        let iso = ISO8601DateFormatter()
        self.id = record.id.uuidString
        self.startedAt = iso.string(from: record.startedAt)
        self.endedAt = iso.string(from: record.endedAt)
        self.latitude = record.latitude
        self.longitude = record.longitude
        self.burstCount = record.burstCount
        self.usedBurstCount = record.usedBurstCount
        self.representativeDistanceMeters = record.representativeDistanceMeters
        self.representativeAltitudeMeters = record.representativeAltitudeMeters
        self.launchClusterCount = record.launchClusterCount
        self.largestClusterRadiusMeters = record.largestClusterRadiusMeters
        self.calculationVersion = record.calculationVersion
    }
}

private struct GeoFeatureCollection: Encodable {
    let type = "FeatureCollection"
    let features: [GeoFeature]
}

private struct GeoFeature: Encodable {
    let type = "Feature"
    let geometry: GeoPoint
    let properties: SessionDTO
}

private struct GeoPoint: Encodable {
    let type = "Point"
    let coordinates: [Double]
}
