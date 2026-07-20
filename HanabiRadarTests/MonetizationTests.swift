import XCTest
@testable import HanabiRadar

final class MonetizationTests: XCTestCase {

    func testMockPurchaseGrantsPremium() async throws {
        let store = MockPurchaseService(premium: false)
        var premium = await store.isPremium()
        XCTAssertFalse(premium)
        XCTAssertEqual(try await store.purchasePremium(), .purchased)
        premium = await store.isPremium()
        XCTAssertTrue(premium)
    }

    func testMockCancelledPurchaseStaysNonPremium() async throws {
        let store = MockPurchaseService(premium: false, purchaseOutcome: .cancelled)
        XCTAssertEqual(try await store.purchasePremium(), .cancelled)
        let premium = await store.isPremium()
        XCTAssertFalse(premium)
    }

    func testMockRestoreReflectsPremium() async throws {
        XCTAssertTrue(try await MockPurchaseService(premium: true).restore())
        XCTAssertFalse(try await MockPurchaseService(premium: false).restore())
    }

    func testAdPolicyPremiumNeverSeesAds() {
        let policy = AdPolicy()
        XCTAssertFalse(policy.shouldShowInterstitial(placement: .sessionEnd, isPremium: true, secondsSinceLastAd: nil))
        XCTAssertFalse(policy.shouldShowInterstitial(placement: .history, isPremium: true, secondsSinceLastAd: 9999))
    }

    func testAdPolicyBlocksMeasurementFlow() {
        let policy = AdPolicy()
        for placement in [AdPlacement.measurement, .cameraStart, .bangWaiting] {
            XCTAssertFalse(
                policy.shouldShowInterstitial(placement: placement, isPremium: false, secondsSinceLastAd: nil),
                "Ads must never show during \(placement.rawValue)"
            )
        }
    }

    func testAdPolicyFrequencyCap() {
        let policy = AdPolicy(minSecondsBetweenAds: 120)
        XCTAssertTrue(policy.shouldShowInterstitial(placement: .sessionEnd, isPremium: false, secondsSinceLastAd: nil))
        XCTAssertFalse(policy.shouldShowInterstitial(placement: .sessionEnd, isPremium: false, secondsSinceLastAd: 60))
        XCTAssertTrue(policy.shouldShowInterstitial(placement: .history, isPremium: false, secondsSinceLastAd: 121))
    }
}
