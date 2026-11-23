import SwiftUI
import UniformTypeIdentifiers
import HanabiCore

/// Developer diagnostics (§23): runs the real detection → estimation pipeline on a synthetic
/// known-truth scenario and shows whether the engine recovers the burst within tolerance.
/// Reached only from a developer-enabled entry (see `AppLaunch.diagnosticsEnabled`), so it
/// stays out of the way for ordinary users. Needs no live fireworks or physical sensors.
struct DiagnosticsView: View {
    @State private var result: DiagnosticsSelfTest.Result?
    @State private var running = false
    @State private var runCount = 0
    @State private var importing = false
    @State private var replayOutcome: ReplayOutcome?

    /// What the last imported recording produced (or why it could not be replayed).
    enum ReplayOutcome: Equatable {
        case result(distance: Double, height: Double, sightings: Int)
        case noPair
        case failed(String)
    }

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

            replaySection

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

    /// Regression replay (§23): re-run the real analysis on a recording file, and export the
    /// built-in sample so the file format can be inspected or round-tripped on a device.
    private var replaySection: some View {
        Section("録画データの再生") {
            Text("検出済みの発光・爆発音・姿勢・位置を記録した JSON を読み込み、本番と同じ解析を再実行します。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("録画ファイルを読み込む") { importing = true }
                .accessibilityIdentifier("replay-import")
            if let sample = SampleRecordingFile() {
                ShareLink(item: sample, preview: SharePreview(sample.fileName)) {
                    Label("サンプル録画を書き出す", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("replay-export-sample")
            }
            switch replayOutcome {
            case .result(let distance, let height, let sightings)?:
                row("距離") { Text(verbatim: "\(fmt(distance)) m") }
                row("高度") { Text(verbatim: "\(fmt(height)) m") }
                row("検出数") { Text(verbatim: "\(sightings)") }
            case .noPair?:
                Text("発光と爆発音のペアが見つかりませんでした。").font(.footnote)
            case .failed(let message)?:
                Text(verbatim: message).font(.footnote).foregroundStyle(.red)
            case nil:
                EmptyView()
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { picked in
            Task { await handleImport(picked) }
        }
    }

    private func handleImport(_ picked: Result<URL, Error>) async {
        switch picked {
        case .failure(let error):
            replayOutcome = .failed(error.localizedDescription)
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let measurement = try RecordedMeasurement.decode(Data(contentsOf: url))
                if let analysis = await measurement.replay() {
                    replayOutcome = .result(
                        distance: analysis.estimate.lineOfSightDistance,
                        height: analysis.estimate.burst.altitude,
                        sightings: analysis.sightingCount
                    )
                } else {
                    replayOutcome = .noPair
                }
            } catch {
                replayOutcome = .failed(error.localizedDescription)
            }
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
