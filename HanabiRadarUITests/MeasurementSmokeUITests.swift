import XCTest

/// Smoke test for reaching the measurement screen with mocked sensors (no permission
/// prompts). The `-uitest` argument makes the app build a mock capture coordinator.
final class MeasurementSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testNavigateToMeasurementScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        XCTAssertTrue(element(app, "root-title").waitForExistence(timeout: 30))

        let goButton = element(app, "go-measurement")
        XCTAssertTrue(goButton.waitForExistence(timeout: 10), "Measurement entry should exist")
        goButton.tap()

        XCTAssertTrue(
            element(app, "measurement-view").waitForExistence(timeout: 10),
            "Measurement screen should appear after navigation"
        )
        // Reached the measurement screen with mock sensors, still foreground, no crash.
        XCTAssertEqual(app.state, .runningForeground)
    }
}
