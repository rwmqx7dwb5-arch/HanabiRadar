import XCTest

/// Smoke test for the manual-location path (§21): with location forced denied, the
/// measurement screen must offer a manual-location entry, present the picker, and accept a
/// choice without crashing — so a location denial degrades to manual input rather than a
/// dead screen.
final class ManualLocationSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testLocationDenialOffersManualLocationPicker() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-force-location-denied"]
        app.launch()

        XCTAssertTrue(element(app, "root-title").waitForExistence(timeout: 30))

        let goButton = element(app, "go-measurement")
        XCTAssertTrue(goButton.waitForExistence(timeout: 10))
        goButton.tap()

        XCTAssertTrue(element(app, "measurement-view").waitForExistence(timeout: 10))

        let manualButton = element(app, "set-manual-location")
        XCTAssertTrue(
            manualButton.waitForExistence(timeout: 10),
            "A manual-location entry should appear when location is denied"
        )
        manualButton.tap()

        XCTAssertTrue(
            element(app, "manual-location-view").waitForExistence(timeout: 10),
            "The manual-location picker should present"
        )

        let confirm = element(app, "confirm-manual-location")
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        confirm.tap()

        // Back on the measurement screen, still running.
        XCTAssertTrue(element(app, "measurement-view").waitForExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground)
    }
}
