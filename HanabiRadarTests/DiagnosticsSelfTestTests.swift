import XCTest
import HanabiCore
@testable import HanabiRadar

/// The in-app self-test must actually recover the known synthetic burst — it's the
/// engine's end-to-end regression check (detection → pairing → estimation), not a stub.
final class DiagnosticsSelfTestTests: XCTestCase {

    func testSelfTestRecoversKnownBurst() async {
        let result = await DiagnosticsSelfTest.run()
        XCTAssertEqual(result.sightingCount, 1, "one flash/bang pair should be detected and paired")
        XCTAssertLessThan(result.distanceErrorMeters, 3.0)
        XCTAssertLessThan(result.horizontalErrorMeters, 8.0)
        XCTAssertLessThan(result.verticalErrorMeters, 8.0)
        XCTAssertTrue(result.passed)
    }
}
