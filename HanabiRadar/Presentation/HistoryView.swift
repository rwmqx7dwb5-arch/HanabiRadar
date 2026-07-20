import SwiftUI
import HanabiCore

/// Lists saved measurement sessions (§16.4). Thin: it renders passed-in records and
/// forwards deletes; the persistence and free-tier retention logic live in `SessionStore`
/// (unit-tested with an in-memory store).
struct HistoryView: View {
    let sessions: [MeasurementSessionRecord]
    var metric = true
    var onDelete: ((MeasurementSessionRecord) -> Void)?

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "履歴はまだありません",
                    systemImage: "sparkles",
                    description: Text("花火を測定すると、ここにセッションが保存されます。")
                )
            } else {
                List {
                    ForEach(sessions, id: \.id) { session in
                        row(session)
                    }
                    .onDelete { indexSet in
                        for index in indexSet { onDelete?(sessions[index]) }
                    }
                }
            }
        }
        .navigationTitle("履歴")
        .accessibilityIdentifier("history-view")
    }

    private func row(_ session: MeasurementSessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.startedAt, format: .dateTime.year().month().day().hour().minute())
                .font(.headline)
            Text("測定 \(session.usedBurstCount)/\(session.burstCount) 発 ・ 推定区域 \(session.launchClusterCount) 箇所")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let distance = session.representativeDistanceMeters {
                Text("代表距離 約 \(Formatting.distance(meters: distance, metric: metric))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// A demo history built from in-memory records (not persisted) for the skeleton and the
/// preview. Real history is fed by `SessionStore`.
struct DemoHistoryScreen: View {
    private let demo: [MeasurementSessionRecord] = {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return [
            MeasurementSessionRecord(
                startedAt: base, endedAt: base.addingTimeInterval(1200),
                latitude: 35.681, longitude: 139.767, deviceModel: "iPhone",
                appVersion: "0.1", calculationVersion: CoreInfo.calculationVersion,
                burstCount: 12, usedBurstCount: 10,
                representativeDistanceMeters: 1840, representativeAltitudeMeters: 320,
                launchClusterCount: 1, largestClusterRadiusMeters: 95
            ),
            MeasurementSessionRecord(
                startedAt: base.addingTimeInterval(-86_400), endedAt: base.addingTimeInterval(-85_000),
                latitude: 34.70, longitude: 135.50, deviceModel: "iPhone",
                appVersion: "0.1", calculationVersion: CoreInfo.calculationVersion,
                burstCount: 6, usedBurstCount: 4,
                representativeDistanceMeters: 2200, representativeAltitudeMeters: 280,
                launchClusterCount: 2, largestClusterRadiusMeters: 160
            )
        ]
    }()

    @AppStorage("unit.distanceMetric") private var metric = true

    var body: some View {
        HistoryView(sessions: demo, metric: metric)
    }
}

#Preview {
    NavigationStack {
        DemoHistoryScreen()
    }
}
