import SwiftUI
import HanabiCapture

/// Measurement screen. A single `AVCaptureSession` drives both the live camera preview and
/// the capture pipeline (mock services in UI tests / Simulator, device services at
/// runtime); motion + location come from the coordinator. The preview fills the screen with
/// a translucent status overlay; live flash/bang detection and the detection → estimation →
/// save flow are layered on in the following increments.
struct MeasurementView: View {
    @StateObject private var model = MeasurementViewModel()
    @State private var flashActive = false
    @State private var bangActive = false

    var body: some View {
        ZStack {
            preview
                .ignoresSafeArea()

            VStack(spacing: 12) {
                if let banner = PermissionBanner.forCapability(model.capability) {
                    PermissionBannerView(banner: banner)
                }
                detectionChips
                statusCard
                Spacer()
                Text("花火へカメラを向けて待ちます。発光と爆発音を自動で検出します。")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .shadow(radius: 3)
            }
            .padding()
        }
        .navigationTitle("測定")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.assessPermissions() }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    /// Live detection indicators: a flash chip and a bang chip, each showing the running
    /// count and pulsing when a new detection arrives.
    private var detectionChips: some View {
        HStack(spacing: 12) {
            detectionChip(symbol: "sparkles", label: "発光", count: model.flashCount,
                          active: flashActive, tint: .yellow)
                .accessibilityIdentifier("flash-chip")
            detectionChip(symbol: "waveform", label: "爆発音", count: model.bangCount,
                          active: bangActive, tint: .orange)
                .accessibilityIdentifier("bang-chip")
        }
        .frame(maxWidth: .infinity)
        .onChange(of: model.flashEventID) { _, _ in pulse($flashActive) }
        .onChange(of: model.bangEventID) { _, _ in pulse($bangActive) }
    }

    private func detectionChip(
        symbol: String, label: LocalizedStringKey, count: Int, active: Bool, tint: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(active ? tint : .white.opacity(0.7))
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.caption2).foregroundStyle(.white.opacity(0.75))
                Text(verbatim: "\(count)").font(.title3.monospacedDigit().bold())
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(active ? tint.opacity(0.35) : .black.opacity(0.45), in: Capsule())
        .overlay(Capsule().strokeBorder(active ? tint : .white.opacity(0.2), lineWidth: active ? 2 : 1))
        .scaleEffect(active ? 1.08 : 1.0)
        .animation(.easeOut(duration: 0.2), value: active)
        .accessibilityElement(children: .combine)
    }

    /// Briefly lights a chip when a detection fires, then relaxes it.
    private func pulse(_ active: Binding<Bool>) {
        active.wrappedValue = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            active.wrappedValue = false
        }
    }

    /// The live camera feed, or a placeholder when there is no session (Simulator / mock).
    private var preview: some View {
        ZStack {
            CameraPreviewView(session: model.previewSession)
            if model.previewSession == nil {
                cameraPlaceholder
            }
        }
        .accessibilityIdentifier("camera-preview")
    }

    private var cameraPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.04)],
                startPoint: .top, endPoint: .bottom
            )
            VStack(spacing: 10) {
                Image(systemName: "camera.metering.center.weighted")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.white.opacity(0.6))
                Text("カメラプレビュー（実機で表示）")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("測定")
                .font(.headline)
                .accessibilityIdentifier("measurement-view")
            Group {
                Text("AV状態: \(model.captureState)")
                Text("映像フレーム: \(model.videoFrames)")
                Text("最大輝度: \(Int((model.latestPeakLuminance * 100).rounded()))％")
                Text("音声フレーム: \(model.audioSamples)")
                Text("音圧: \(String(format: "%.3f", model.latestAudioEnergy))")
                Text("姿勢: \(model.attitudeCount) / 位置: \(model.locationCount)")
            }
            .font(.footnote.monospaced())
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        MeasurementView()
    }
}
