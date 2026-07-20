import XCTest

/// Verifies the app's UI actually launches in the Simulator (not merely that a hosted
/// unit-test bundle links). Uses the `-uitest` launch argument so no permission prompts
/// are triggered.
final class AppLaunchUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Type-agnostic lookup by accessibility identifier (robust to how SwiftUI exposes
    /// the element's type).
    private func rootTitle(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "root-title").firstMatch
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        return app
    }

    func testAppLaunchesToRootScreen() {
        let app = launchApp()
        let title = rootTitle(in: app)
        let found = title.waitForExistence(timeout: 30)
        if !found {
            // Emit the accessibility tree so a failure is diagnosable from CI logs.
            print("ACCESSIBILITY TREE:\n\(app.debugDescription)")
        }
        XCTAssertTrue(found, "Root screen element (root-title) should be visible after launch")
    }

    func testAppIsForegroundAndDoesNotCrash() {
        let app = launchApp()
        XCTAssertTrue(rootTitle(in: app).waitForExistence(timeout: 30))
        XCTAssertEqual(app.state, .runningForeground, "App should be in the foreground")

        // A benign interaction; if the app had crashed, state would no longer be
        // foreground and the identified element would be gone.
        app.swipeUp()
        XCTAssertTrue(rootTitle(in: app).exists)
        XCTAssertEqual(app.state, .runningForeground)
    }
}
