import SwiftUI
import SwiftData

/// Settings: unit preferences (§16.5, §26 の km/mi・℃/℉ 切替), a privacy summary, and an
/// optional destructive "delete all data" action (§20). Unit toggles are stored in
/// `@AppStorage` and read by the result / history screens, so changing them updates the
/// displayed values app-wide. Data deletion is wired via `onDeleteAllData` only when a
/// store is available, so the row never appears as a dead button.
struct SettingsView: View {
    @AppStorage("unit.distanceMetric") private var distanceMetric = true
    @AppStorage("unit.temperatureFahrenheit") private var temperatureFahrenheit = false

    /// Provided by the host once a persistent store exists; nil hides the deletion row.
    var onDeleteAllData: (() -> Void)?

    @State private var confirmingDelete = false

    var body: some View {
        List {
            Section("単位") {
                Toggle("距離をメートル法 (km/m) で表示", isOn: $distanceMetric)
                Toggle("気温を華氏 (°F) で表示", isOn: $temperatureFahrenheit)
                LabeledContent("プレビュー") {
                    Text("\(Formatting.distance(meters: 1840, metric: distanceMetric)) ・ "
                        + Formatting.temperature(celsius: 22, fahrenheit: temperatureFahrenheit))
                        .foregroundStyle(.secondary)
                }
            }

            Section("プライバシー") {
                Text("計算はすべて端末内で行い、生の映像・音声・正確な位置を外部へ送信しません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("気象データ") {
                Text("音速補正のため、観測地点の現在の気象条件を Apple WeatherKit から取得します。取得時刻とデータ提供元は結果にも併記します。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                WeatherAttributionView()
            }

            if let onDeleteAllData {
                Section {
                    Button("すべての履歴を削除", role: .destructive) { confirmingDelete = true }
                        .accessibilityIdentifier("delete-all-data")
                } footer: {
                    Text("端末内に保存した測定履歴をすべて削除します。")
                }
                .confirmationDialog(
                    "すべての履歴を削除しますか？",
                    isPresented: $confirmingDelete,
                    titleVisibility: .visible
                ) {
                    Button("削除", role: .destructive) { onDeleteAllData() }
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text("この操作は取り消せません。")
                }
            }
        }
        .navigationTitle("設定")
        .accessibilityIdentifier("settings-view")
    }
}

/// The live settings screen: wires "delete all data" to the SwiftData store so the row
/// appears and actually clears saved history.
struct SettingsScreen: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        SettingsView(onDeleteAllData: {
            try? SessionStore(context: context, retentionLimit: nil).deleteAll()
        })
    }
}

#Preview {
    NavigationStack {
        SettingsView(onDeleteAllData: {})
    }
}
