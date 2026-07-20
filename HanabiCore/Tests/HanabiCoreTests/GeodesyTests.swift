import XCTest
import Foundation
@testable import HanabiCore

final class GeodesyTests: XCTestCase {

    func testEquatorPrimeMeridian() {
        let p = Geodesy.geodeticToECEF(GeodeticCoordinate(latitude: 0, longitude: 0, altitude: 0))
        XCTAssertEqual(p.x, WGS84.a, accuracy: 1e-3)
        XCTAssertEqual(p.y, 0, accuracy: 1e-6)
        XCTAssertEqual(p.z, 0, accuracy: 1e-6)
    }

    func testEcefRoundTrip() {
        let coordinates = [
            GeodeticCoordinate(latitude: 35.681, longitude: 139.767, altitude: 40),
            GeodeticCoordinate(latitude: -33.8688, longitude: 151.2093, altitude: 5),
            GeodeticCoordinate(latitude: 51.5074, longitude: -0.1278, altitude: 100),
            GeodeticCoordinate(latitude: 0, longitude: 179.9, altitude: 0)
        ]
        for c in coordinates {
            let back = Geodesy.ecefToGeodetic(Geodesy.geodeticToECEF(c))
            XCTAssertEqual(back.latitude, c.latitude, accuracy: 1e-8)
            XCTAssertEqual(back.longitude, c.longitude, accuracy: 1e-8)
            XCTAssertEqual(back.altitude, c.altitude, accuracy: 1e-4)
        }
    }

    func testEnuBasisAtOrigin() {
        let basis = Geodesy.enuBasis(latitudeDegrees: 0, longitudeDegrees: 0)
        assertVector(basis.east, Vector3(0, 1, 0))
        assertVector(basis.north, Vector3(0, 0, 1))
        assertVector(basis.up, Vector3(1, 0, 0))
    }

    func testEnuOffsetRoundTrip() {
        let origin = GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 10)
        let moved = Geodesy.coordinate(from: origin, enuOffset: Vector3(0, 100, 0))
        let offset = Geodesy.enuOffset(of: moved, from: origin)
        XCTAssertEqual(offset.x, 0, accuracy: 1e-4)
        XCTAssertEqual(offset.y, 100, accuracy: 1e-4)
        XCTAssertEqual(offset.z, 0, accuracy: 1e-4)
        XCTAssertGreaterThan(moved.latitude, origin.latitude)
    }

    private func assertVector(_ a: Vector3, _ b: Vector3, _ tolerance: Double = 1e-9) {
        XCTAssertEqual(a.x, b.x, accuracy: tolerance)
        XCTAssertEqual(a.y, b.y, accuracy: tolerance)
        XCTAssertEqual(a.z, b.z, accuracy: tolerance)
    }
}
