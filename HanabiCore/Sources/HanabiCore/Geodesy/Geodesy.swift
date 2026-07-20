import Foundation

/// WGS84 reference ellipsoid parameters.
public enum WGS84 {
    /// Semi-major axis (equatorial radius), meters.
    public static let a = 6_378_137.0
    /// Flattening.
    public static let f = 1.0 / 298.257_223_563
    /// Semi-minor axis (polar radius), meters.
    public static let b = a * (1.0 - f)
    /// First eccentricity squared.
    public static let e2 = f * (2.0 - f)
    /// Second eccentricity squared.
    public static let ep2 = e2 / (1.0 - e2)
}

/// Conversions between geodetic (lat/lon/height), ECEF, and local ENU frames.
public enum Geodesy {

    /// Geodetic -> Earth-Centered Earth-Fixed (meters).
    public static func geodeticToECEF(_ c: GeodeticCoordinate) -> Vector3 {
        let lat = c.latitudeRadians
        let lon = c.longitudeRadians
        let sinLat = sin(lat), cosLat = cos(lat)
        let sinLon = sin(lon), cosLon = cos(lon)
        let n = WGS84.a / (1.0 - WGS84.e2 * sinLat * sinLat).squareRoot()
        let x = (n + c.altitude) * cosLat * cosLon
        let y = (n + c.altitude) * cosLat * sinLon
        let z = (n * (1.0 - WGS84.e2) + c.altitude) * sinLat
        return Vector3(x, y, z)
    }

    /// ECEF (meters) -> geodetic, via a stable fixed-point iteration.
    public static func ecefToGeodetic(_ p: Vector3) -> GeodeticCoordinate {
        let x = p.x, y = p.y, z = p.z
        let lon = atan2(y, x)
        let pr = (x * x + y * y).squareRoot()

        if pr < 1e-9 {
            // On (or extremely near) the polar axis.
            let lat = z >= 0 ? Double.pi / 2.0 : -Double.pi / 2.0
            let alt = abs(z) - WGS84.b
            return GeodeticCoordinate(
                latitude: lat * 180.0 / .pi,
                longitude: lon * 180.0 / .pi,
                altitude: alt
            )
        }

        var lat = atan2(z, pr * (1.0 - WGS84.e2))
        var alt = 0.0
        for _ in 0..<12 {
            let sinLat = sin(lat)
            let n = WGS84.a / (1.0 - WGS84.e2 * sinLat * sinLat).squareRoot()
            alt = pr / cos(lat) - n
            let newLat = atan2(z, pr * (1.0 - WGS84.e2 * n / (n + alt)))
            if abs(newLat - lat) < 1e-12 {
                lat = newLat
                break
            }
            lat = newLat
        }
        let sinLat = sin(lat)
        let n = WGS84.a / (1.0 - WGS84.e2 * sinLat * sinLat).squareRoot()
        alt = pr / cos(lat) - n
        return GeodeticCoordinate(
            latitude: lat * 180.0 / .pi,
            longitude: lon * 180.0 / .pi,
            altitude: alt
        )
    }

    /// Right-handed ENU basis vectors expressed in ECEF at the given location.
    public static func enuBasis(
        latitudeDegrees latDeg: Double,
        longitudeDegrees lonDeg: Double
    ) -> (east: Vector3, north: Vector3, up: Vector3) {
        let lat = latDeg * Double.pi / 180.0
        let lon = lonDeg * Double.pi / 180.0
        let sinLat = sin(lat), cosLat = cos(lat)
        let sinLon = sin(lon), cosLon = cos(lon)
        let east = Vector3(-sinLon, cosLon, 0)
        let north = Vector3(-sinLat * cosLon, -sinLat * sinLon, cosLat)
        let up = Vector3(cosLat * cosLon, cosLat * sinLon, sinLat)
        return (east, north, up)
    }

    /// Rotation whose columns are (east, north, up): maps an ENU vector to ECEF.
    public static func enuToECEF(
        latitudeDegrees latDeg: Double,
        longitudeDegrees lonDeg: Double
    ) -> Matrix3 {
        let basis = enuBasis(latitudeDegrees: latDeg, longitudeDegrees: lonDeg)
        return Matrix3.columns(basis.east, basis.north, basis.up)
    }

    /// Rotation that maps an ECEF vector into the local ENU frame.
    public static func ecefToENU(
        latitudeDegrees latDeg: Double,
        longitudeDegrees lonDeg: Double
    ) -> Matrix3 {
        enuToECEF(latitudeDegrees: latDeg, longitudeDegrees: lonDeg).transposed
    }

    /// ENU offset (meters) of `point` relative to `origin`.
    public static func enuOffset(
        of point: GeodeticCoordinate,
        from origin: GeodeticCoordinate
    ) -> Vector3 {
        let delta = geodeticToECEF(point) - geodeticToECEF(origin)
        return ecefToENU(latitudeDegrees: origin.latitude, longitudeDegrees: origin.longitude).act(on: delta)
    }

    /// Geodetic coordinate at a given ENU offset (meters) from `origin`.
    public static func coordinate(
        from origin: GeodeticCoordinate,
        enuOffset offset: Vector3
    ) -> GeodeticCoordinate {
        let ecef = geodeticToECEF(origin)
            + enuToECEF(latitudeDegrees: origin.latitude, longitudeDegrees: origin.longitude).act(on: offset)
        return ecefToGeodetic(ecef)
    }
}
