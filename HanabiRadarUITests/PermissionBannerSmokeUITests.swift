import XCTest

/// Smoke test for the degraded-mode path (§21): launching with a forced microphone denial
/// must still reach the measurement screen, show the guidance banner, and stay running —
/// a denial degrades the mode instead of crashing or leaving a dead screen.
final class PermissionBannerSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testMicrophoneDenialShowsBannerAndDoesNotCrash() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-force-mic-denied"]
        app.launch()

        XCTAssertTrue(element(app, "root-title").waitForExistence(timeout: 30))

        let goButton = element(app, "go-measurement")
        XCTAssertTrue(goButton.waitForExistence(timeout: 10))
        goButton.tap()

        XCTAssertTrue(
            element(app, "measurement-view").waitForExistence(timeout: 10),
            "Measurement screen should still appear when the microphone is denied"
        )
        XCTAssertTrue(
            element(app, "permission-banner").waitForExistence(timeout: 10),
            "A guidance banner should explain the degraded mode"
        )
        XCTAssertEqual(app.state, .runningForeground, "The app must not crash on a denial")
    }
}
