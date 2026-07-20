import XCTest
@testable import HanabiRadar

@MainActor
final class PurchaseViewModelTests: XCTestCase {

    func testRefreshReflectsFree() async {
        let vm = PurchaseViewModel(service: MockPurchaseService(premium: false))
        await vm.refresh()
        XCTAssertEqual(vm.entitlement, .free)
        XCTAssertFalse(vm.isPremium)
    }

    func testRefreshReflectsPremium() async {
        let vm = PurchaseViewModel(service: MockPurchaseService(premium: true))
        await vm.refresh()
        XCTAssertEqual(vm.entitlement, .premium)
        XCTAssertTrue(vm.isPremium)
    }

    func testBuyGrantsPremium() async {
        let vm = PurchaseViewModel(service: MockPurchaseService(premium: false))
        await vm.refresh()
        await vm.buy()
        XCTAssertEqual(vm.entitlement, .premium)
        XCTAssertEqual(vm.message, .purchased)
        XCTAssertFalse(vm.isWorking)
    }

    func testCancelledPurchaseStaysFree() async {
        let vm = PurchaseViewModel(service: MockPurchaseService(premium: false, purchaseOutcome: .cancelled))
        await vm.refresh()
        await vm.buy()
        XCTAssertEqual(vm.entitlement, .free)
        XCTAssertEqual(vm.message, .cancelled)
    }

    func testFailedPurchaseStaysFree() async {
        let vm = PurchaseViewModel(service: MockPurchaseService(premium: false, purchaseOutcome: .failed))
        await vm.refresh()
        await vm.buy()
        XCTAssertEqual(vm.entitlement, .free)
        XCTAssertEqual(vm.message, .failed)
    }

    func testRestoreReflectsPremium() async {
        let vm = PurchaseViewModel(service: MockPurchaseService(premium: true))
        await vm.restore()
        XCTAssertEqual(vm.entitlement, .premium)
        XCTAssertEqual(vm.message, .restored)
    }

    func testRestoreWithNothingToRestore() async {
        let vm = PurchaseViewModel(service: MockPurchaseService(premium: false))
        await vm.restore()
        XCTAssertEqual(vm.entitlement, .free)
        XCTAssertEqual(vm.message, .nothingToRestore)
    }
}
