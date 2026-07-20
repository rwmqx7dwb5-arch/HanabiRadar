import XCTest
@testable import HanabiRadar

/// The attribution model must always resolve to something showable — including when the
/// WeatherKit attribution API is unavailable (unsigned CI build / mock / UI-test mode) —
/// so the required Apple Weather attribution never leaves a spinner or a dead link.
final class WeatherAttributionTests: XCTestCase {

    @MainActor
    func testMockLoadFallsBackToApplesLegalURLWithNoMark() async {
        let model = WeatherAttributionModel()
        await model.load(useMock: true)
        XCTAssertEqual(model.info?.legalURL, WeatherAttributionModel.fallbackLegalURL)
        XCTAssertNil(model.info?.lightMarkURL)
        XCTAssertNil(model.info?.darkMarkURL)
        XCTAssertTrue(model.usedFallback)
    }

    @MainActor
    func testFallbackLegalURLPointsAtApple() {
        XCTAssertEqual(WeatherAttributionModel.fallbackLegalURL.host, "weatherkit.apple.com")
    }
}
