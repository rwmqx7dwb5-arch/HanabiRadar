import XCTest

/// Smoke test that the (demo) history screen renders and stays alive, exercising the
/// HistoryView layout in the Simulator.
final class HistorySmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testNavigateToHistoryDemoScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        XCTAssertTrue(element(app, "root-title").waitForExistence(timeout: 30))

        let goButton = element(app, "go-history")
        XCTAssertTrue(goButton.waitForExistence(timeout: 10), "History entry should exist")
        goButton.tap()

        XCTAssertTrue(
            element(app, "history-view").waitForExistence(timeout: 10),
            "History screen should appear after navigation"
        )
        XCTAssertEqual(app.state, .runningForeground)
    }
}
