import XCTest
@testable import HanabiCapture

final class FrameLuminanceExtractorTests: XCTestCase {

    private let t = CaptureTimestamp(seconds: 1)

    func testDarkFrameHasNoBrightness() {
        let luma = [UInt8](repeating: 0, count: 8 * 6)
        let f = FrameLuminanceExtractor.features(luma: luma, width: 8, height: 6, time: t)
        XCTAssertEqual(f.meanLuminance, 0, accuracy: 1e-9)
        XCTAssertEqual(f.peakLuminance, 0, accuracy: 1e-9)
        XCTAssertEqual(f.brightArea, 0, accuracy: 1e-9)
        XCTAssertFalse(f.atFrameEdge)
        // Centroid defaults to the frame center when nothing is bright.
        XCTAssertEqual(f.brightCentroid.x, 0.5, accuracy: 1e-9)
        XCTAssertEqual(f.brightCentroid.y, 0.5, accuracy: 1e-9)
    }

    func testUniformlyBrightFrame() {
        let luma = [UInt8](repeating: 255, count: 10 * 10)
        let f = FrameLuminanceExtractor.features(luma: luma, width: 10, height: 10, time: t)
        XCTAssertEqual(f.meanLuminance, 1.0, accuracy: 1e-9)
        XCTAssertEqual(f.peakLuminance, 1.0, accuracy: 1e-9)
        XCTAssertEqual(f.brightArea, 1.0, accuracy: 1e-9)
        // A full-frame bright region touches the border.
        XCTAssertTrue(f.atFrameEdge)
        XCTAssertEqual(f.brightCentroid.x, 0.5, accuracy: 1e-9)
        XCTAssertEqual(f.brightCentroid.y, 0.5, accuracy: 1e-9)
    }

    func testCenteredBlobLocalizesToCenterWithoutEdge() {
        // 9x9 dark grid with a single bright pixel dead center (4,4).
        let width = 9, height = 9
        var luma = [UInt8](repeating: 20, count: width * height)
        luma[4 * width + 4] = 250
        let f = FrameLuminanceExtractor.features(luma: luma, width: width, height: height, time: t)

        XCTAssertEqual(f.peakLuminance, 250.0 / 255.0, accuracy: 1e-9)
        XCTAssertEqual(f.brightArea, 1.0 / Double(width * height), accuracy: 1e-9)
        XCTAssertFalse(f.atFrameEdge)
        XCTAssertEqual(f.brightCentroid.x, 0.5, accuracy: 1e-9)  // 4 / (9-1)
        XCTAssertEqual(f.brightCentroid.y, 0.5, accuracy: 1e-9)
    }

    func testCornerBlobIsFlaggedAtEdge() {
        // Bright pixel at the top-left corner (0,0).
        let width = 8, height = 8
        var luma = [UInt8](repeating: 10, count: width * height)
        luma[0] = 255
        let f = FrameLuminanceExtractor.features(luma: luma, width: width, height: height, time: t)
        XCTAssertTrue(f.atFrameEdge)
        XCTAssertEqual(f.brightCentroid.x, 0.0, accuracy: 1e-9)
        XCTAssertEqual(f.brightCentroid.y, 0.0, accuracy: 1e-9)
    }

    func testThresholdSelectsBrightPixels() {
        // Half the pixels at 200, half at 100; threshold 0.75 (=191) keeps only the 200s.
        let width = 4, height = 2
        let luma: [UInt8] = [200, 200, 200, 200, 100, 100, 100, 100]
        let f = FrameLuminanceExtractor.features(luma: luma, width: width, height: height, time: t)
        XCTAssertEqual(f.brightArea, 0.5, accuracy: 1e-9)
        // Bright row is the top row (y=0), so the region touches the edge.
        XCTAssertTrue(f.atFrameEdge)
        XCTAssertEqual(f.brightCentroid.y, 0.0, accuracy: 1e-9)
    }

    func testMalformedInputIsSafe() {
        // luma shorter than width*height returns neutral features rather than crashing.
        let f = FrameLuminanceExtractor.features(luma: [1, 2, 3], width: 10, height: 10, time: t)
        XCTAssertEqual(f.peakLuminance, 0, accuracy: 1e-9)
        XCTAssertEqual(f.brightArea, 0, accuracy: 1e-9)
    }
}
