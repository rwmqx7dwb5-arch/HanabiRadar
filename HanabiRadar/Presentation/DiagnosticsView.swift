import SwiftUI

/// Developer diagnostics (§23): runs the real detection → estimation pipeline on a synthetic
/// known-truth scenario and shows whether the engine recovers the burst within tolerance.
/// Reached only from a developer-enabled entry (see `AppLaunch.diagnosticsEnabled`), so it
/// stays out of the way for ordinary users. Needs no live fireworks or physical sensors.
struct DiagnosticsView: View {
    @State private var result: DiagnosticsSelfTest.Result?
    @State private var running = false
    @State private var runCount = 0

    var body: some View {
        List {
            Section {
                Text("合成シナリオ（既知の真値）で検出→対応付け→推定パイプラインを実行し、復元した位置を真値と比較する開発者向け自己診断です。実際の花火や実機センサーは不要です。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(running ? "実行中…" : "セルフテストを再実行") { runCount += 1 }
                    .disabled(running)
                    .accessibilityIdentifier("run-selftest")
            }

            if let result {
                Section("結果") {
                    row("判定") {
                        Text(verbatim: result.passed ? "PASS" : "FAIL")
                            .bold()
                            .foregroundStyle(result.passed ? Color.green : Color.red)
                            .accessibilityIdentifier("selftest-verdict")
                    }
                    row("検出数") { Text(verbatim: "\(result.sightingCount)") }
                    row("距離") { Text(verbatim: "\(fmt(result.recoveredDistanceMeters)) m") }
                    row("距離誤差") { Text(verbatim: "\(fmt(result.distanceErrorMeters)) m") }
                    row("水平誤差") { Text(verbatim: "\(fmt(result.horizontalErrorMeters)) m") }
                    row("高度誤差") { Text(verbatim: "\(fmt(result.verticalErrorMeters)) m") }
                }
            }
        }
        .navigationTitle("診断")
        .accessibilityIdentifier("diagnostics-view")
        .task(id: runCount) {
            running = true
            result = await DiagnosticsSelfTest.run()
            running = false
        }
    }

    @ViewBuilder
    private func row<Value: View>(_ label: LocalizedStringKey, @ViewBuilder _ value: () -> Value) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: 12)
            value().foregroundStyle(.secondary)
        }
    }

    private func fmt(_ value: Double) -> String {
        value.isFinite ? String(format: "%.1f", value) : "—"
    }
}

#Preview {
    NavigationStack { DiagnosticsView() }
}
