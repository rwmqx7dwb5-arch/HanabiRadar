import SwiftUI

/// The premium (one-time, non-consumable) purchase screen (§16.5, §19.2). It is bound to a
/// `PurchaseService` via `PurchaseViewModel`; the actual price comes from StoreKit's own
/// purchase sheet, so it is never hard-coded (§19.2). No ads appear on this screen.
struct PurchaseView: View {
    @StateObject private var model: PurchaseViewModel

    init(service: PurchaseService) {
        _model = StateObject(wrappedValue: PurchaseViewModel(service: service))
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Label("プレミアム", systemImage: "sparkles")
                    Spacer()
                    Text(statusText).foregroundStyle(.secondary)
                }
            }

            Section("プレミアムでできること") {
                feature("rectangle.slash", "広告を非表示")
                feature("tray.full", "履歴を無制限に保存")
                feature("square.and.arrow.up", "CSV / JSON / GeoJSON エクスポート")
                feature("plus.magnifyingglass", "詳細な誤差情報")
            }

            Section {
                if model.isPremium {
                    Label("プレミアムをご利用中です。", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        Task { await model.buy() }
                    } label: {
                        HStack {
                            Text("プレミアムを購入")
                            if model.isWorking {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(model.isWorking)
                    .accessibilityIdentifier("buy-premium")
                }

                Button("購入を復元") {
                    Task { await model.restore() }
                }
                .disabled(model.isWorking)
                .accessibilityIdentifier("restore-premium")
            } footer: {
                if let messageKey {
                    Text(messageKey)
                }
            }

            Section {
                Text("推定エンジンは無料版と同一です。プレミアムは広告・保存・エクスポート・詳細な誤差情報にのみ影響します。価格は購入時に表示されます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("プレミアム")
        .accessibilityIdentifier("purchase-view")
        .task { await model.refresh() }
    }

    private var statusText: LocalizedStringKey {
        switch model.entitlement {
        case .unknown: return "確認中…"
        case .free: return "未購入"
        case .premium: return "購入済み"
        }
    }

    private var messageKey: LocalizedStringKey? {
        switch model.message {
        case .none: return nil
        case .purchased: return "購入が完了しました。ありがとうございます。"
        case .cancelled: return "購入をキャンセルしました。"
        case .pending: return "購入は保留中です。承認をお待ちください。"
        case .failed: return "購入を完了できませんでした。"
        case .restored: return "購入を復元しました。"
        case .nothingToRestore: return "復元できる購入はありませんでした。"
        case .restoreFailed: return "復元を完了できませんでした。"
        }
    }

    private func feature(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        Label(text, systemImage: symbol)
    }
}

/// Demo purchase screen backed by an in-memory mock — for the launcher, previews, and UI
/// smoke tests. No StoreKit, no real transactions.
struct DemoPurchaseScreen: View {
    private let service: PurchaseService = MockPurchaseService(premium: false)

    var body: some View {
        PurchaseView(service: service)
    }
}

#Preview {
    NavigationStack {
        DemoPurchaseScreen()
    }
}
