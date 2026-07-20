import XCTest

/// Smoke test that the premium purchase screen renders in the Simulator (mock store, no
/// real transactions) and its purchase / restore controls exist.
final class PurchaseSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testNavigateToPurchaseScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        XCTAssertTrue(element(app, "root-title").waitForExistence(timeout: 30))

        let goButton = element(app, "go-purchase")
        XCTAssertTrue(goButton.waitForExistence(timeout: 10), "Purchase entry should exist")
        goButton.tap()

        XCTAssertTrue(
            element(app, "purchase-view").waitForExistence(timeout: 10),
            "Purchase screen should appear after navigation"
        )
        XCTAssertTrue(element(app, "buy-premium").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "restore-premium").waitForExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground)
    }
}
