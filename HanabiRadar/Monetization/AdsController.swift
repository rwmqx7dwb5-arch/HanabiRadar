import Foundation

/// App-wide entry point for ads. Builds the real stack (UMP consent + Google interstitials +
/// StoreKit entitlement) in a normal run, and an inert stack in UI tests / `-mock-sensors`
/// (no consent prompt, no SDK, no network). Premium users resolve no consent and never
/// initialize the ad SDK (`AdCoordinator.configure`).
@MainActor
final class AdsController: ObservableObject {
    static let shared = AdsController()

    private let coordinator: AdCoordinator
    private let purchases: PurchaseService
    private var consent: AdConsent = .unknown
    private var lastAdAt: Date?
    private var configured = false

    init(coordinator: AdCoordinator, purchases: PurchaseService) {
        self.coordinator = coordinator
        self.purchases = purchases
    }

    convenience init() {
        if AppLaunch.useMockSensors {
            self.init(
                coordinator: AdCoordinator(consentService: DefaultConsentService(), adService: NoOpAdService()),
                purchases: MockPurchaseService(premium: false)
            )
        } else {
            self.init(
                coordinator: AdCoordinator(consentService: UMPConsentService(), adService: GoogleAdService()),
                purchases: StoreKitPurchaseService()
            )
        }
    }

    /// Resolves consent and starts the SDK once per launch (idempotent).
    func configure() async {
        guard configured == false else { return }
        configured = true
        let premium = await purchases.isPremium()
        consent = await coordinator.configure(isPremium: premium)
    }

    /// Offers an interstitial at an allowed placement. Re-checks the entitlement each time so
    /// a purchase made during the session stops ads immediately; the frequency cap is enforced
    /// by `AdPolicy` and the consent gate by `ConsentGate`.
    func show(_ placement: AdPlacement) async {
        let premium = await purchases.isPremium()
        let since = lastAdAt.map { Date().timeIntervalSince($0) }
        guard ConsentGate.adsAllowed(consent),
              coordinator.policy.shouldShowInterstitial(
                placement: placement, isPremium: premium, secondsSinceLastAd: since
              ) else { return }
        lastAdAt = Date()
        await coordinator.maybeShowInterstitial(
            placement: placement, isPremium: premium, consent: consent, secondsSinceLastAd: since
        )
    }
}
