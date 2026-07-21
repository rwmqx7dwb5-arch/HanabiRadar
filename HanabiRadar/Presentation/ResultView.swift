import Foundation
import SwiftUI
import HanabiCore

/// Renders a burst estimate honestly: every value is labelled an estimate, the coordinate
/// precision is gated by the uncertainty, MSL / relative / above-ground heights are
/// distinguished, and the launch site is explicitly not claimed from one burst
/// (commissioning §4, §13, §14, §15).
///
/// This is a thin view over the tested core: `EstimateReporter` makes the honesty
/// decisions and `Formatting` turns them into strings, both unit-tested, so the view only
/// lays out text. Written on Windows without Xcode — this SwiftUI layer is build-verified
/// by the iOS CI, not compiled in the authoring environment.
struct ResultView: View {
    let estimate: BurstEstimate
    let uncertainty: UncertaintyResult
    var metric = true

    private var report: BurstReport {
        EstimateReporter.report(estimate: estimate, uncertainty: uncertainty)
    }

    var body: some View {
        List {
            Section("推定（すべて推定値）") {
                row("距離", Formatting.distanceLine(
                    median: uncertainty.distanceMedian,
                    low95: uncertainty.distanceLow95,
                    high95: uncertainty.distanceHigh95,
                    metric: metric))
                row("高さ", Formatting.heightLine(estimate: estimate, metric: metric))
                row("方位", String(format: "%.0f°", estimate.azimuthDegrees))
                row("仰角", String(format: "%.0f°", estimate.elevationDegrees))
                if let note = Formatting.weatherPartialNote(estimate: estimate) {
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("信頼度") {
                row("総合", "\(localized(Formatting.confidenceLabel(report.confidenceCategory)))（\(Int((report.confidence * 100).rounded()))%）")
                row("主な誤差要因", localized(Formatting.dominantFactorLabel(report.dominantFactor)))
            }

            Section("爆発地点の直下（推定）") {
                row("緯度経度", Formatting.coordinate(estimate.subpoint, precision: report.horizontalPrecision))
                row("95%範囲", String(localized: "半径約 \(Formatting.distance(meters: report.horizontalRadius95Meters, metric: metric))"))
                if report.horizontalPrecision == .areaOnly {
                    Text("信頼度が低い / 範囲が広いため、鋭い点ではなく区域として表示しています。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section {
                Text("実際の発射筒位置は 1 台の iPhone では確定できません。複数発の測定から「推定打ち上げ区域」として提示します。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("結果")
        .accessibilityIdentifier("result-view")
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    /// Localizes a source-language label produced by the tested `Formatting` enum by
    /// looking it up as a key in the string catalog. This keeps `Formatting` (and its
    /// exact-string unit tests) unchanged while the categorical labels still translate.
    private func localized(_ sourceKey: String) -> String {
        NSLocalizedString(sourceKey, comment: "")
    }
}

/// Computes a demo sample once and shows it in `ResultView` (used by the root screen and
/// the preview). The sample runs the real core, so this proves the estimate → honest
/// presentation path builds and renders.
struct DemoResultScreen: View {
    @AppStorage("unit.distanceMetric") private var metric = true
    private let sample = DemoEstimate.sample()

    var body: some View {
        ResultView(estimate: sample.estimate, uncertainty: sample.uncertainty, metric: metric)
    }
}

#Preview {
    NavigationStack {
        DemoResultScreen()
    }
}
