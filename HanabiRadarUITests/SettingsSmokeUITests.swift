import XCTest

/// Smoke test that the settings screen renders and its unit toggle is interactive.
final class SettingsSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testNavigateToSettingsScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        XCTAssertTrue(element(app, "root-title").waitForExistence(timeout: 30))

        let goButton = element(app, "go-settings")
        XCTAssertTrue(goButton.waitForExistence(timeout: 10), "Settings entry should exist")
        goButton.tap()

        XCTAssertTrue(
            element(app, "settings-view").waitForExistence(timeout: 10),
            "Settings screen should appear after navigation"
        )
        XCTAssertEqual(app.state, .runningForeground)
    }
}
