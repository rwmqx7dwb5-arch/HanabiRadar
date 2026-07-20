import XCTest
import Foundation
@testable import HanabiCore

final class MathTests: XCTestCase {

    func testVectorArithmetic() {
        let a = Vector3(1, 2, 3)
        let b = Vector3(4, 5, 6)
        XCTAssertEqual(a + b, Vector3(5, 7, 9))
        XCTAssertEqual(b - a, Vector3(3, 3, 3))
        XCTAssertEqual(a.dot(b), 32, accuracy: 1e-12)
        XCTAssertEqual(a.cross(b), Vector3(-3, 6, -3))
        XCTAssertEqual(Vector3(3, 4, 0).length, 5, accuracy: 1e-12)
        XCTAssertEqual(Vector3(0, 3, 0).normalized(), Vector3(0, 1, 0))
    }

    func testQuaternionRotatesAboutZ() {
        let q = Quaternion(axis: Vector3(0, 0, 1), angle: .pi / 2)
        let r = q.act(on: Vector3(1, 0, 0))
        XCTAssertEqual(r.x, 0, accuracy: 1e-9)
        XCTAssertEqual(r.y, 1, accuracy: 1e-9)
        XCTAssertEqual(r.z, 0, accuracy: 1e-9)
    }

    func testQuaternionFromToVector() {
        let q = Quaternion(from: Vector3(0, 0, 1), to: Vector3(0, 1, 0))
        let r = q.act(on: Vector3(0, 0, 1))
        XCTAssertEqual(r.x, 0, accuracy: 1e-9)
        XCTAssertEqual(r.y, 1, accuracy: 1e-9)
        XCTAssertEqual(r.z, 0, accuracy: 1e-9)
    }

    func testQuaternionMatrixRoundTrip() {
        let q = Quaternion(axis: Vector3(1, 2, 3), angle: 0.7).normalized()
        let q2 = Quaternion(rotationMatrix: q.rotationMatrix)
        let v = Vector3(0.3, -0.5, 0.8)
        let a = q.act(on: v)
        let b = q2.act(on: v)
        XCTAssertEqual(a.x, b.x, accuracy: 1e-9)
        XCTAssertEqual(a.y, b.y, accuracy: 1e-9)
        XCTAssertEqual(a.z, b.z, accuracy: 1e-9)
    }

    func testMatrixInverseIsIdentity() {
        let k = CameraIntrinsics(fx: 1500, fy: 1500, cx: 960, cy: 540, width: 1920, height: 1080).matrix
        guard let inverse = k.inverse else { return XCTFail("K must be invertible") }
        let product = k * inverse
        XCTAssertEqual(product.m00, 1, accuracy: 1e-9)
        XCTAssertEqual(product.m11, 1, accuracy: 1e-9)
        XCTAssertEqual(product.m22, 1, accuracy: 1e-9)
        XCTAssertEqual(product.m01, 0, accuracy: 1e-9)
        XCTAssertEqual(product.m12, 0, accuracy: 1e-9)
    }
}
