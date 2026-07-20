import Foundation

/// Where an interstitial might be shown. The measurement flow is deliberately ad-free.
enum AdPlacement: String, Sendable, Equatable {
    case measurement    // during measurement — never
    case cameraStart    // before the camera opens — never
    case bangWaiting    // while waiting for the bang — never
    case sessionEnd     // after a session finishes — allowed
    case history        // on the history screen — allowed
}

/// Pure, testable ad-placement policy encoding the commissioning rules (§19.3): premium
/// users never see ads; the measurement screen / camera start / bang-waiting never show
/// ads; interstitials are limited to session end / history and are frequency-capped.
struct AdPolicy: Sendable, Equatable {
    var minSecondsBetweenAds: Double

    init(minSecondsBetweenAds: Double = 120) {
        self.minSecondsBetweenAds = minSecondsBetweenAds
    }

    func shouldShowInterstitial(
        placement: AdPlacement,
        isPremium: Bool,
        secondsSinceLastAd: Double?
    ) -> Bool {
        if isPremium { return false }
        switch placement {
        case .measurement, .cameraStart, .bangWaiting:
            return false
        case .sessionEnd, .history:
            guard let since = secondsSinceLastAd else { return true }
            return since >= minSecondsBetweenAds
        }
    }
}

/// Isolates any ad SDK behind a protocol (§19.3). The real Google Mobile Ads + UMP
/// consent implementation is owner-side (needs the SDK, production ad unit IDs, ATT/UMP,
/// and App Privacy answers); the app links only this protocol so it stays testable and
/// so premium builds can avoid initializing an ad SDK at all.
protocol AdService: Sendable {
    /// Configure the SDK (consent, non-personalized default). No-op when unused.
    func start(personalized: Bool) async
    /// Show an interstitial for a placement the policy has already approved.
    func showInterstitial(placement: AdPlacement) async
}

/// Default no-op ad service — used for premium, tests, and until a real SDK is wired.
struct NoOpAdService: AdService {
    func start(personalized: Bool) async {}
    func showInterstitial(placement: AdPlacement) async {}
}
