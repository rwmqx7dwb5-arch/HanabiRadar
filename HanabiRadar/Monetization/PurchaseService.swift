import Foundation
import StoreKit

/// The outcome of a purchase attempt.
enum PurchaseOutcome: String, Sendable, Equatable {
    case purchased
    case cancelled
    case pending
    case failed
}

/// Abstracts the store so the app (and its tests/previews) never depend on StoreKit
/// directly. Premium is a one-time non-consumable; the estimation engine is identical for
/// free and premium users — only retention / export / ads differ (§18, §19.2).
protocol PurchaseService: Sendable {
    func isPremium() async -> Bool
    func purchasePremium() async throws -> PurchaseOutcome
    func restore() async throws -> Bool
}

/// Real StoreKit 2 implementation. Entitlement is derived from
/// `Transaction.currentEntitlements` (never a cached bool, §29). This compiles in an
/// unsigned build (the iOS CI builds it), but a real purchase needs the product
/// configured in App Store Connect / a .storekit file and an Apple account (owner-side),
/// so runtime behavior is not verified here.
struct StoreKitPurchaseService: PurchaseService {
    static let premiumProductID = "com.example.hanabiradar.premium.lifetime"

    func isPremium() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.premiumProductID,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    func purchasePremium() async throws -> PurchaseOutcome {
        let products = try await Product.products(for: [Self.premiumProductID])
        guard let product = products.first else { return .failed }
        switch try await product.purchase() {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                return .purchased
            }
            return .failed        // Unverified transactions are not trusted.
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .failed
        }
    }

    func restore() async throws -> Bool {
        try await AppStore.sync()
        return await isPremium()
    }
}

/// In-memory test/preview double. Not for production use.
actor MockPurchaseService: PurchaseService {
    private var premium: Bool
    private let purchaseOutcome: PurchaseOutcome

    init(premium: Bool = false, purchaseOutcome: PurchaseOutcome = .purchased) {
        self.premium = premium
        self.purchaseOutcome = purchaseOutcome
    }

    func isPremium() async -> Bool { premium }

    func purchasePremium() async throws -> PurchaseOutcome {
        if purchaseOutcome == .purchased { premium = true }
        return purchaseOutcome
    }

    func restore() async throws -> Bool { premium }
}
