import Foundation

/// The resolved advertising-consent state (§19.3, §20). Kept separate from any SDK so the
/// gating logic is pure and testable; a real Google UMP + ATT implementation is owner-side.
enum AdConsent: String, Sendable, Equatable, CaseIterable {
    /// Not yet requested/resolved. Fail closed: show no ads and initialize no ad SDK.
    case unknown
    /// Consent isn't required for this user/region. Ads allowed, non-personalized by default.
    case notRequired
    /// User consented to personalized ads.
    case personalized
    /// User allows non-personalized ads only.
    case nonPersonalized
    /// User declined. No ads.
    case denied

    /// Ads may run only once consent is resolved and not declined.
    var adsAllowed: Bool {
        switch self {
        case .notRequired, .personalized, .nonPersonalized: return true
        case .unknown, .denied: return false
        }
    }

    /// Personalized ads are permitted only with explicit personalized consent; every other
    /// allowed state defaults to non-personalized (§19.3 "初期設定は非パーソナライズ広告を優先").
    var personalized: Bool { self == .personalized }
}

/// Requests advertising consent (UMP) and, where applicable, App Tracking Transparency, and
/// returns the resolved state. The real implementation is owner-side (Google UMP SDK +
/// `ATTrackingManager`); the app depends only on this protocol so the flow stays testable
/// and premium builds can skip it entirely.
protocol ConsentService: Sendable {
    func resolveConsent() async -> AdConsent
}

/// Default until a real UMP SDK is wired: resolves to `.unknown`, so the app shows no ads
/// and never initializes a personalized ad SDK. Privacy-first / fail-closed.
struct DefaultConsentService: ConsentService {
    func resolveConsent() async -> AdConsent { .unknown }
}

/// Fixed consent for tests/previews.
struct StaticConsentService: ConsentService {
    let status: AdConsent
    init(_ status: AdConsent = .nonPersonalized) { self.status = status }
    func resolveConsent() async -> AdConsent { status }
}

/// Pure consent gate composed with `AdPolicy`. Keeping this separate means `AdPolicy`'s
/// placement/frequency rules and the consent rules are each tested in isolation.
enum ConsentGate {
    /// Ads may show only when consent is resolved and not declined.
    static func adsAllowed(_ consent: AdConsent) -> Bool { consent.adsAllowed }
    /// Whether personalized ads are permitted (else non-personalized).
    static func personalized(_ consent: AdConsent) -> Bool { consent.personalized }
}

/// Ties consent + placement policy + ad SDK together. Premium users never resolve consent
/// or initialize an ad SDK; non-premium users initialize only after consent is resolved and
/// only with the personalization consent allows. Interstitials require BOTH the consent gate
/// and the placement/frequency policy to pass.
struct AdCoordinator {
    var policy: AdPolicy
    var consentService: ConsentService
    var adService: AdService

    init(policy: AdPolicy = AdPolicy(), consentService: ConsentService, adService: AdService) {
        self.policy = policy
        self.consentService = consentService
        self.adService = adService
    }

    /// Resolves consent (skipping it for premium) and initializes the ad SDK only when ads
    /// are allowed. Returns the resolved consent (`.denied` for premium — no ads either way).
    @discardableResult
    func configure(isPremium: Bool) async -> AdConsent {
        guard !isPremium else { return .denied }
        let consent = await consentService.resolveConsent()
        if consent.adsAllowed {
            await adService.start(personalized: consent.personalized)
        }
        return consent
    }

    /// Shows an interstitial only if the consent gate AND the placement/frequency policy
    /// both allow it.
    func maybeShowInterstitial(
        placement: AdPlacement,
        isPremium: Bool,
        consent: AdConsent,
        secondsSinceLastAd: Double?
    ) async {
        guard ConsentGate.adsAllowed(consent),
              policy.shouldShowInterstitial(
                placement: placement, isPremium: isPremium, secondsSinceLastAd: secondsSinceLastAd
              )
        else { return }
        await adService.showInterstitial(placement: placement)
    }
}
