import XCTest

/// Smoke test for the manual-location path (§21): with location forced denied, the
/// measurement screen must offer a manual-location entry and survive interacting with it —
/// a location denial degrades to manual input rather than a dead screen. The MapKit picker's
/// internals (pan, confirm) are exercised on a physical device via TestFlight, since driving
/// a `Map` in a headless Simulator is unreliable.
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
        // Opening the picker must not crash the app (degraded mode stays usable).
        manualButton.tap()
        XCTAssertEqual(app.state, .runningForeground)
    }
}
