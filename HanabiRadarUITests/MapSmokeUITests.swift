import XCTest

/// Smoke test that the (demo) result map renders in the Simulator.
final class MapSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testNavigateToMapDemoScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        XCTAssertTrue(element(app, "root-title").waitForExistence(timeout: 30))

        let goButton = element(app, "go-map")
        XCTAssertTrue(goButton.waitForExistence(timeout: 10), "Map entry should exist")
        goButton.tap()

        XCTAssertTrue(
            element(app, "map-view").waitForExistence(timeout: 15),
            "Map screen should appear after navigation"
        )
        XCTAssertEqual(app.state, .runningForeground)
    }
}
