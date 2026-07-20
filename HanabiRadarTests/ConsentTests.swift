import XCTest
@testable import HanabiRadar

/// The advertising-consent architecture (§19.3, §20): ads must fail closed (no ads / no
/// SDK until consent is resolved and not declined), premium must never initialize an ad
/// SDK, and personalization must follow the consent exactly. All verified on the pure
/// gating logic; the real UMP/ATT SDK is owner-side.
final class ConsentTests: XCTestCase {

    /// Records the ad SDK calls the coordinator makes.
    actor SpyAdService: AdService {
        private(set) var starts: [Bool] = []
        private(set) var shown: [AdPlacement] = []
        func start(personalized: Bool) async { starts.append(personalized) }
        func showInterstitial(placement: AdPlacement) async { shown.append(placement) }
    }

    func testAdsAllowedOnlyWhenResolvedAndNotDeclined() {
        XCTAssertFalse(AdConsent.unknown.adsAllowed)
        XCTAssertFalse(AdConsent.denied.adsAllowed)
        XCTAssertTrue(AdConsent.notRequired.adsAllowed)
        XCTAssertTrue(AdConsent.personalized.adsAllowed)
        XCTAssertTrue(AdConsent.nonPersonalized.adsAllowed)
    }

    func testPersonalizedRequiresExplicitConsent() {
        XCTAssertTrue(AdConsent.personalized.personalized)
        for consent: AdConsent in [.unknown, .notRequired, .nonPersonalized, .denied] {
            XCTAssertFalse(consent.personalized, "\(consent) must default to non-personalized")
        }
    }

    func testDefaultConsentServiceFailsClosed() async {
        let status = await DefaultConsentService().resolveConsent()
        XCTAssertEqual(status, .unknown)
    }

    func testConfigurePremiumSkipsConsentAndSDK() async {
        let spy = SpyAdService()
        let coord = AdCoordinator(consentService: StaticConsentService(.personalized), adService: spy)
        let consent = await coord.configure(isPremium: true)
        XCTAssertEqual(consent, .denied)
        let starts = await spy.starts
        XCTAssertTrue(starts.isEmpty, "premium must not initialize an ad SDK")
    }

    func testConfigureUnknownConsentDoesNotStartSDK() async {
        let spy = SpyAdService()
        let coord = AdCoordinator(consentService: DefaultConsentService(), adService: spy)
        let consent = await coord.configure(isPremium: false)
        XCTAssertEqual(consent, .unknown)
        let starts = await spy.starts
        XCTAssertTrue(starts.isEmpty, "no ad SDK until consent is resolved")
    }

    func testConfigureStartsWithConsentPersonalization() async {
        let personalizedSpy = SpyAdService()
        _ = await AdCoordinator(consentService: StaticConsentService(.personalized), adService: personalizedSpy)
            .configure(isPremium: false)
        let personalizedStarts = await personalizedSpy.starts
        XCTAssertEqual(personalizedStarts, [true])

        let limitedSpy = SpyAdService()
        _ = await AdCoordinator(consentService: StaticConsentService(.nonPersonalized), adService: limitedSpy)
            .configure(isPremium: false)
        let limitedStarts = await limitedSpy.starts
        XCTAssertEqual(limitedStarts, [false])
    }

    func testConfigureDeniedConsentDoesNotStartSDK() async {
        let spy = SpyAdService()
        _ = await AdCoordinator(consentService: StaticConsentService(.denied), adService: spy).configure(isPremium: false)
        let starts = await spy.starts
        XCTAssertTrue(starts.isEmpty)
    }

    func testMaybeShowRequiresConsentAndPolicy() async {
        let spy = SpyAdService()
        let coord = AdCoordinator(
            policy: AdPolicy(minSecondsBetweenAds: 120),
            consentService: StaticConsentService(.nonPersonalized),
            adService: spy
        )

        // Consent allows, an allowed placement, no prior ad -> shows.
        await coord.maybeShowInterstitial(placement: .sessionEnd, isPremium: false, consent: .nonPersonalized, secondsSinceLastAd: nil)
        var shown = await spy.shown
        XCTAssertEqual(shown, [.sessionEnd])

        // Declined consent blocks ads even for an otherwise-allowed placement.
        await coord.maybeShowInterstitial(placement: .sessionEnd, isPremium: false, consent: .denied, secondsSinceLastAd: nil)
        shown = await spy.shown
        XCTAssertEqual(shown, [.sessionEnd], "denied consent must block ads")

        // The measurement screen is ad-free regardless of consent.
        await coord.maybeShowInterstitial(placement: .measurement, isPremium: false, consent: .personalized, secondsSinceLastAd: nil)
        shown = await spy.shown
        XCTAssertEqual(shown, [.sessionEnd], "measurement is ad-free")
    }

    func testMaybeShowBlockedForPremium() async {
        let spy = SpyAdService()
        let coord = AdCoordinator(consentService: StaticConsentService(.personalized), adService: spy)
        await coord.maybeShowInterstitial(placement: .sessionEnd, isPremium: true, consent: .personalized, secondsSinceLastAd: nil)
        let shown = await spy.shown
        XCTAssertTrue(shown.isEmpty, "premium sees no ads")
    }
}
