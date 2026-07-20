import XCTest

/// Smoke test that the demo result screen renders and stays alive. This exercises the
/// estimate → honest-presentation path (BurstSolver + UncertaintyEstimator + EstimateReporter
/// + Formatting + ResultView) end to end in the Simulator, so the SwiftUI layer is not
/// merely compiled but actually run.
final class ResultSmokeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testNavigateToResultDemoScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        XCTAssertTrue(element(app, "root-title").waitForExistence(timeout: 30))

        let goButton = element(app, "go-result")
        XCTAssertTrue(goButton.waitForExistence(timeout: 10), "Result entry should exist")
        goButton.tap()

        XCTAssertTrue(
            element(app, "result-view").waitForExistence(timeout: 10),
            "Result screen should appear after navigation"
        )
        XCTAssertEqual(app.state, .runningForeground)
    }
}
