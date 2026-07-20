import XCTest

/// Verifies the app's UI actually launches in the Simulator (not merely that a hosted
/// unit-test bundle links). Uses the `-uitest` launch argument so no permission prompts
/// are triggered.
final class AppLaunchUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testAppLaunchesToRootScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        // The identified root title element must appear -> the UI rendered.
        XCTAssertTrue(
            app.staticTexts["root-title"].waitForExistence(timeout: 30),
            "Root screen title should be visible after launch"
        )
    }

    func testAppIsForegroundAndDoesNotCrash() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        XCTAssertTrue(app.staticTexts["root-title"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.state, .runningForeground, "App should be in the foreground")

        // A benign interaction; if the app had crashed, state would no longer be
        // foreground and the identified element would be gone.
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["root-title"].exists)
        XCTAssertEqual(app.state, .runningForeground)
    }
}
