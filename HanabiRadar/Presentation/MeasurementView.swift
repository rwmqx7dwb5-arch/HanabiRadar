import SwiftUI

/// Skeleton measurement screen. The capture pipeline is wired via dependency injection
/// (mock services in UI tests, device services at runtime). The full measurement UX
/// (camera preview, guides, detection status) is built in later increments.
struct MeasurementView: View {
    @StateObject private var model = MeasurementViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("測定")
                .font(.title.bold())
                .accessibilityIdentifier("measurement-view")

            VStack(alignment: .leading, spacing: 6) {
                Text("状態: \(model.stateText)")
                Text("姿勢サンプル: \(model.attitudeCount)")
                Text("位置サンプル: \(model.locationCount)")
            }
            .font(.body.monospaced())
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Text("花火へカメラを向けて待つ操作に対応予定（現在は取得基盤の骨組み）。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
        .navigationTitle("測定")
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

#Preview {
    MeasurementView()
}
