import XCTest

/// Smoke test that the Settings screen shows the required Apple Weather attribution
/// (§27). Runs with mock sensors, so the attribution resolves to its offline fallback
/// (no network / entitlement needed).
final class WeatherAttributionSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testSettingsShowsWeatherAttribution() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        XCTAssertTrue(element(app, "root-title").waitForExistence(timeout: 30))

        let settings = element(app, "go-settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()

        XCTAssertTrue(element(app, "settings-view").waitForExistence(timeout: 10))

        // The weather-data section may sit below the fold on shorter devices; scroll if so.
        if !element(app, "weather-attribution").waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(
            element(app, "weather-attribution").waitForExistence(timeout: 5),
            "Settings should show the Apple Weather attribution"
        )
    }
}
