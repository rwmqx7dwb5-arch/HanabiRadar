import XCTest
@testable import HanabiRadar

final class PCMConverterTests: XCTestCase {

    private func floatBytes(_ values: [Float]) -> [UInt8] {
        var out = [UInt8]()
        for v in values { withUnsafeBytes(of: Float32(v)) { out.append(contentsOf: $0) } }
        return out
    }

    private func int16Bytes(_ values: [Int16]) -> [UInt8] {
        var out = [UInt8]()
        for v in values { withUnsafeBytes(of: v) { out.append(contentsOf: $0) } }
        return out
    }

    func testFloat32Mono() {
        let data = floatBytes([0.5, -0.25, 1.0])
        let out = PCMConverter.channelZero(data, isFloat: true, bitsPerChannel: 32, frameStride: 1)
        XCTAssertEqual(out, [0.5, -0.25, 1.0])
    }

    func testInt16MonoScalesToUnit() {
        let data = int16Bytes([16_384, -16_384, 0])
        let out = PCMConverter.channelZero(data, isFloat: false, bitsPerChannel: 16, frameStride: 1)
        XCTAssertEqual(out[0], 0.5, accuracy: 1e-6)
        XCTAssertEqual(out[1], -0.5, accuracy: 1e-6)
        XCTAssertEqual(out[2], 0.0, accuracy: 1e-6)
    }

    func testInt16InterleavedStereoTakesChannelZero() {
        // Frames: (L,R) = (16384, 30000), (-16384, -30000).
        let data = int16Bytes([16_384, 30_000, -16_384, -30_000])
        let out = PCMConverter.channelZero(data, isFloat: false, bitsPerChannel: 16, frameStride: 2)
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[0], 0.5, accuracy: 1e-6)
        XCTAssertEqual(out[1], -0.5, accuracy: 1e-6)
    }

    func testFloat32InterleavedStereoTakesChannelZero() {
        let data = floatBytes([1.0, 9.0, 0.5, 8.0])   // (L,R),(L,R)
        let out = PCMConverter.channelZero(data, isFloat: true, bitsPerChannel: 32, frameStride: 2)
        XCTAssertEqual(out, [1.0, 0.5])
    }

    func testPartialTrailingFrameIsIgnored() {
        // 5 bytes is not a whole 16-bit frame pair; only complete frames are decoded.
        let out = PCMConverter.channelZero([1, 2, 3, 4, 5], isFloat: false, bitsPerChannel: 16, frameStride: 1)
        XCTAssertEqual(out.count, 2)   // 5 / 2 = 2 whole samples
    }

    func testEmptyAndUnsupportedAreSafe() {
        XCTAssertTrue(PCMConverter.channelZero([], isFloat: true, bitsPerChannel: 32, frameStride: 1).isEmpty)
        // 8-bit is unsupported: bytesPerSample 1, decodes frames but leaves zeros.
        let out = PCMConverter.channelZero([200, 10], isFloat: false, bitsPerChannel: 8, frameStride: 1)
        XCTAssertEqual(out, [0, 0])
    }
}
