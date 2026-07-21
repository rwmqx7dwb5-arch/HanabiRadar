import XCTest

/// Smoke test that the developer diagnostics screen (§23) runs the self-test in-app and
/// reports PASS — the engine recovers the synthetic burst on the Simulator, end to end.
final class DiagnosticsSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testSelfTestRunsAndPasses() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        XCTAssertTrue(element(app, "root-title").waitForExistence(timeout: 30))

        let entry = element(app, "go-diagnostics")
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "diagnostics entry should be visible in test builds")
        if !entry.isHittable { app.swipeUp() }   // reach it if it's below the fold
        entry.tap()

        XCTAssertTrue(element(app, "diagnostics-view").waitForExistence(timeout: 10))

        let verdict = element(app, "selftest-verdict")
        XCTAssertTrue(verdict.waitForExistence(timeout: 15), "the self-test verdict should appear")
        XCTAssertEqual(verdict.label, "PASS", "the engine should recover the synthetic burst")
    }
}
