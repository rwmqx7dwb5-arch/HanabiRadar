import Foundation

/// Presentation state for the premium purchase screen. It talks only to the
/// `PurchaseService` protocol, so it is fully testable with `MockPurchaseService` and never
/// touches StoreKit directly. The estimation engine is identical for free and premium users
/// (§18, §19.2); premium only affects ads / retention / export / detailed uncertainty.
@MainActor
final class PurchaseViewModel: ObservableObject {

    /// The user's current entitlement. Starts `.unknown` until the first `refresh()`.
    enum Entitlement: Equatable { case unknown, free, premium }

    /// Outcome of the last action, kept as cases so tests assert intent rather than
    /// localized text, and the view maps each to a localized message.
    enum Message: Equatable {
        case purchased, cancelled, pending, failed
        case restored, nothingToRestore, restoreFailed
    }

    @Published private(set) var entitlement: Entitlement = .unknown
    @Published private(set) var isWorking = false
    @Published private(set) var message: Message?

    private let service: PurchaseService

    init(service: PurchaseService) {
        self.service = service
    }

    var isPremium: Bool { entitlement == .premium }

    /// Reads the current entitlement from the store (never a cached bool, §29).
    func refresh() async {
        entitlement = await service.isPremium() ? .premium : .free
    }

    func buy() async {
        guard !isWorking else { return }
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            switch try await service.purchasePremium() {
            case .purchased:
                entitlement = .premium
                message = .purchased
            case .cancelled:
                message = .cancelled
            case .pending:
                message = .pending
            case .failed:
                message = .failed
            }
        } catch {
            message = .failed
        }
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            let restored = try await service.restore()
            entitlement = restored ? .premium : .free
            message = restored ? .restored : .nothingToRestore
        } catch {
            message = .restoreFailed
        }
    }
}
