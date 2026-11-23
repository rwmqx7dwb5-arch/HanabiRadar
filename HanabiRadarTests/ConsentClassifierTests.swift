import XCTest
@testable import HanabiRadar

final class ConsentClassifierTests: XCTestCase {

    func testNoTCFStringMeansNotRequired() {
        XCTAssertEqual(ConsentClassifier.classify(purposeConsents: nil, attAuthorized: true), .notRequired)
        XCTAssertEqual(ConsentClassifier.classify(purposeConsents: "", attAuthorized: false), .notRequired)
    }

    func testPersonalizedNeedsPurposes134AndATT() {
        // Purposes 1,3,4 granted (indexes 0,2,3).
        XCTAssertEqual(ConsentClassifier.classify(purposeConsents: "1011000000", attAuthorized: true), .personalized)
        XCTAssertEqual(ConsentClassifier.classify(purposeConsents: "1011000000", attAuthorized: false), .nonPersonalized)
    }

    func testMissingPurposeFallsBackToNonPersonalized() {
        XCTAssertEqual(ConsentClassifier.classify(purposeConsents: "1010000000", attAuthorized: true), .nonPersonalized)
        XCTAssertEqual(ConsentClassifier.classify(purposeConsents: "0000000000", attAuthorized: true), .nonPersonalized)
    }

    func testShortStringIsHandledWithoutCrashing() {
        XCTAssertEqual(ConsentClassifier.classify(purposeConsents: "10", attAuthorized: true), .nonPersonalized)
    }

    func testPersonalizationPossibleOnlyWhenPurposesGranted() {
        XCTAssertTrue(ConsentClassifier.personalizationPossible(purposeConsents: "1011"))
        XCTAssertFalse(ConsentClassifier.personalizationPossible(purposeConsents: "1001"))
        XCTAssertFalse(ConsentClassifier.personalizationPossible(purposeConsents: nil))
    }

    private actor RecordingAds: AdService {
        private(set) var started: Bool?
        private(set) var shown = 0
        func start(personalized: Bool) async { started = personalized }
        func showInterstitial(placement: AdPlacement) async { shown += 1 }
        func snapshot() -> (started: Bool?, shown: Int) { (started, shown) }
    }

    @MainActor
    func testPremiumNeverStartsOrShowsAds() async {
        let ads = RecordingAds()
        let controller = AdsController(
            coordinator: AdCoordinator(consentService: StaticConsentService(.personalized), adService: ads),
            purchases: MockPurchaseService(premium: true)
        )
        await controller.configure()
        await controller.show(.sessionEnd)
        let snapshot = await ads.snapshot()
        XCTAssertNil(snapshot.started)
        XCTAssertEqual(snapshot.shown, 0)
    }

    @MainActor
    func testFreeUserWithConsentStartsAndShowsOncePerCap() async {
        let ads = RecordingAds()
        let controller = AdsController(
            coordinator: AdCoordinator(consentService: StaticConsentService(.nonPersonalized), adService: ads),
            purchases: MockPurchaseService(premium: false)
        )
        await controller.configure()
        await controller.show(.sessionEnd)
        await controller.show(.sessionEnd)   // inside the frequency cap -> suppressed
        await controller.show(.measurement)  // never allowed
        let snapshot = await ads.snapshot()
        XCTAssertEqual(snapshot.started, false)
        XCTAssertEqual(snapshot.shown, 1)
    }

    @MainActor
    func testUnknownConsentShowsNothing() async {
        let ads = RecordingAds()
        let controller = AdsController(
            coordinator: AdCoordinator(consentService: DefaultConsentService(), adService: ads),
            purchases: MockPurchaseService(premium: false)
        )
        await controller.configure()
        await controller.show(.sessionEnd)
        let snapshot = await ads.snapshot()
        XCTAssertNil(snapshot.started)
        XCTAssertEqual(snapshot.shown, 0)
    }
}
