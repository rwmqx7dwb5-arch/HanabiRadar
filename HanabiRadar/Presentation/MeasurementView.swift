import SwiftUI
import HanabiCapture

/// Measurement screen. A single `AVCaptureSession` drives both the live camera preview and
/// the capture pipeline (mock services in UI tests / Simulator, device services at
/// runtime); motion + location come from the coordinator. The preview fills the screen with
/// a translucent status overlay; live flash/bang detection and the detection → estimation →
/// save flow are layered on in the following increments.
struct MeasurementView: View {
    @StateObject private var model = MeasurementViewModel()

    var body: some View {
        ZStack {
            preview
                .ignoresSafeArea()

            VStack(spacing: 12) {
                if let banner = PermissionBanner.forCapability(model.capability) {
                    PermissionBannerView(banner: banner)
                }
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
                Text("音声サンプル: \(model.audioSamples)")
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
