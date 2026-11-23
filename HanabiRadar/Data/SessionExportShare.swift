import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable

/// The export formats offered from the history screen (§18).
enum SessionExportFormat: String, CaseIterable, Identifiable {
    case csv, json, geojson

    var id: String { rawValue }

    var title: String {
        switch self {
        case .csv: return "CSV"
        case .json: return "JSON"
        case .geojson: return "GeoJSON"
        }
    }

    var fileExtension: String { rawValue }

    var contentType: UTType {
        switch self {
        case .csv: return .commaSeparatedText
        case .json: return .json
        case .geojson: return UTType(filenameExtension: "geojson", conformingTo: .json) ?? .json
        }
    }

    /// Renders `records` in this format via the tested `SessionExporter`.
    func render(_ records: [MeasurementSessionRecord]) throws -> String {
        switch self {
        case .csv: return SessionExporter.csv(records)
        case .json: return try SessionExporter.json(records)
        case .geojson: return try SessionExporter.geoJSON(records)
        }
    }

    /// e.g. `hanabi-radar-sessions-20260723.csv` (UTC date, so the name is deterministic).
    func fileName(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd"
        return "hanabi-radar-sessions-\(formatter.string(from: date)).\(fileExtension)"
    }
}

/// A shareable export file. The content is rendered up front (it is a small summary table),
/// then written to a temp file when the share sheet asks for it.
struct SessionExportFile: Transferable {
    let format: SessionExportFormat
    let contents: String
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .data) { file in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.fileName)
            try Data(file.contents.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }

    init?(format: SessionExportFormat, records: [MeasurementSessionRecord], date: Date = Date()) {
        guard let text = try? format.render(records) else { return nil }
        self.format = format
        self.contents = text
        self.fileName = format.fileName(date: date)
    }
}

/// Toolbar menu that shares the given sessions as CSV / JSON / GeoJSON.
struct SessionExportMenu: View {
    let sessions: [MeasurementSessionRecord]

    var body: some View {
        Menu {
            ForEach(SessionExportFormat.allCases) { format in
                if let file = SessionExportFile(format: format, records: sessions) {
                    ShareLink(item: file, preview: SharePreview(file.fileName)) {
                        Label(format.title, systemImage: "square.and.arrow.up")
                    }
                }
            }
        } label: {
            Label("書き出し", systemImage: "square.and.arrow.up")
        }
        .accessibilityIdentifier("export-menu")
    }
}
