import Foundation
import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// Pure mapping from the UMP/TCF values stored in `UserDefaults` (plus the ATT result) to the
/// app's `AdConsent`. Kept free of SDK types so it is unit-tested without Google's SDK state.
enum ConsentClassifier {

    /// `purposeConsents` is `IABTCF_PurposeConsents`: one "0"/"1" character per TCF purpose,
    /// where index 0 is Purpose 1 (store/access information on a device).
    ///
    /// - No TCF string (nil/empty): consent was not required for this user/region, so ads run
    ///   but non-personalized (`.notRequired`; §19.3 defaults to non-personalized).
    /// - Personalized needs Purposes 1, 3 and 4 AND ATT authorization.
    /// - Anything else that can still request ads is non-personalized.
    static func classify(purposeConsents: String?, attAuthorized: Bool) -> AdConsent {
        guard let purposeConsents, purposeConsents.isEmpty == false else { return .notRequired }
        let flags = Array(purposeConsents)
        func granted(_ purpose: Int) -> Bool { purpose - 1 < flags.count && flags[purpose - 1] == "1" }
        if granted(1) && granted(3) && granted(4) && attAuthorized { return .personalized }
        return .nonPersonalized
    }

    /// Whether the personalized path is even possible (so ATT is only requested when it matters).
    static func personalizationPossible(purposeConsents: String?) -> Bool {
        guard let purposeConsents, purposeConsents.isEmpty == false else { return false }
        let flags = Array(purposeConsents)
        return [1, 3, 4].allSatisfy { $0 - 1 < flags.count && flags[$0 - 1] == "1" }
    }
}

/// Google UMP consent + App Tracking Transparency. Resolves to `.denied` when UMP says ads
/// cannot be requested, so the coordinator never initializes the ad SDK in that case.
struct UMPConsentService: ConsentService {

    func resolveConsent() async -> AdConsent {
        await Self.gather()
    }

    @MainActor
    private static func gather() async -> AdConsent {
        let updated: Bool = await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { error in
                continuation.resume(returning: error == nil)
            }
        }
        if updated {
            // Shows the consent form only where the user's region requires it.
            try? await ConsentForm.loadAndPresentIfRequired(from: nil)
        }
        // `canRequestAds` can already be true from consent gathered in an earlier session.
        guard ConsentInformation.shared.canRequestAds else { return .denied }

        let purposes = UserDefaults.standard.string(forKey: "IABTCF_PurposeConsents")
        var attAuthorized = ATTrackingManager.trackingAuthorizationStatus == .authorized
        if ConsentClassifier.personalizationPossible(purposeConsents: purposes),
           ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            attAuthorized = await ATTrackingManager.requestTrackingAuthorization() == .authorized
        }
        return ConsentClassifier.classify(purposeConsents: purposes, attAuthorized: attAuthorized)
    }

    /// Whether the UMP "privacy options" entry point must be offered (Settings).
    @MainActor
    static var privacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    @MainActor
    static func presentPrivacyOptions() async {
        try? await ConsentForm.presentPrivacyOptionsForm(from: nil)
    }
}

/// Google Mobile Ads interstitials. Constructed only for non-premium users and started only
/// after `AdCoordinator` has a resolved, non-denied consent (so the SDK is never initialized
/// before consent). Ad unit id comes from Info.plist (build setting), never source code.
@MainActor
final class GoogleAdService: NSObject, AdService, FullScreenContentDelegate {
    private var interstitial: InterstitialAd?
    private var personalized = false
    private var started = false

    private var adUnitID: String {
        Bundle.main.object(forInfoDictionaryKey: "HanabiInterstitialAdUnitID") as? String ?? ""
    }

    func start(personalized: Bool) async {
        self.personalized = personalized
        guard started == false, adUnitID.isEmpty == false else { return }
        started = true
        await MobileAds.shared.start()
        await loadInterstitial()
    }

    func showInterstitial(placement: AdPlacement) async {
        guard started else { return }
        if interstitial == nil { await loadInterstitial() }
        guard let ad = interstitial else { return }
        ad.present(from: nil)
    }

    private func loadInterstitial() async {
        let request = Request()
        if personalized == false {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }
        do {
            let ad = try await InterstitialAd.load(with: adUnitID, request: request)
            ad.fullScreenContentDelegate = self
            interstitial = ad
        } catch {
            interstitial = nil
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.interstitial = nil
            await self.loadInterstitial()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in self.interstitial = nil }
    }
}
