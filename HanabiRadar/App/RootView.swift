import SwiftUI
import HanabiCore

/// Placeholder root screen for the app skeleton. It links the estimation core into
/// the app (proving the integration builds and runs in the Simulator). The real
/// measurement / result / map / history screens are implemented in later increments.
struct RootView: View {
    private let demo = DemoEstimate.compute()

    var body: some View {
        VStack(spacing: 16) {
            Text("Hanabi Radar")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("root-title")
            Text("Estimation core v\(CoreInfo.calculationVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("サンプル推定 (デモ)")
                    .font(.headline)
                Text(demo)
                    .font(.body.monospaced())
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Text("この画面は骨組みです。測定・結果・地図・履歴のUIは後続で実装します。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RootView()
}
