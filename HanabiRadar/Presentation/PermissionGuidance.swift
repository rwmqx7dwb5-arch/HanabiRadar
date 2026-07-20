import SwiftUI
import UIKit
import HanabiCapture

/// The measurement-screen banner to show for a degraded capability, or `nil` for `.full`
/// (no banner). Pure mapping from the core's `MeasurementCapability`, so the honesty of
/// "what still works" is unit-tested independently of any view (§21).
enum PermissionBanner: String, Equatable, CaseIterable {
    case cameraRequired       // .unavailable        — camera denied; measurement impossible
    case microphoneDenied     // .directionOnly      — no distance, direction only
    case locationDenied       // .manualLocation     — no latitude/longitude
    case motionUnavailable    // .limitedOrientation — no device attitude

    static func forCapability(_ capability: MeasurementCapability) -> PermissionBanner? {
        switch capability {
        case .full: return nil
        case .unavailable: return .cameraRequired
        case .directionOnly: return .microphoneDenied
        case .manualLocation: return .locationDenied
        case .limitedOrientation: return .motionUnavailable
        }
    }

    /// Whether the fix is a permission the user can grant in Settings (vs. a hardware
    /// limitation), which decides whether the banner offers an "Open Settings" button.
    var offersSettings: Bool {
        switch self {
        case .cameraRequired, .microphoneDenied, .locationDenied: return true
        case .motionUnavailable: return false
        }
    }
}

/// A non-blocking banner that explains the degraded measurement mode and how to fix it.
/// Shown above the measurement UI when a permission is denied, so denials guide the user
/// instead of leaving a dead screen (§21). Strings localize via the app String Catalog.
struct PermissionBannerView: View {
    let banner: PermissionBanner
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if banner.offersSettings {
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .font(.footnote.bold())
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.yellow.opacity(0.5)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("permission-banner")
    }

    private var title: LocalizedStringKey {
        switch banner {
        case .cameraRequired: return "カメラの許可が必要です"
        case .microphoneDenied: return "マイクなしモード"
        case .locationDenied: return "現在地なしモード"
        case .motionUnavailable: return "モーションを利用できません"
        }
    }

    private var message: LocalizedStringKey {
        switch banner {
        case .cameraRequired:
            return "花火を測定するにはカメラを許可してください。"
        case .microphoneDenied:
            return "マイクがないため距離は測れません。方向のみ記録します。設定でマイクを許可すると距離も測れます。"
        case .locationDenied:
            return "現在地がないため緯度・経度は算出できません。距離と方向は測れます。設定で位置情報を許可してください。"
        case .motionUnavailable:
            return "端末の姿勢を取得できないため方向を算出できません。"
        }
    }

    private var icon: String {
        switch banner {
        case .cameraRequired: return "video.slash"
        case .microphoneDenied: return "mic.slash"
        case .locationDenied: return "location.slash"
        case .motionUnavailable: return "gyroscope"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        PermissionBannerView(banner: .microphoneDenied)
        PermissionBannerView(banner: .locationDenied)
        PermissionBannerView(banner: .cameraRequired)
    }
    .padding()
}
