import Foundation

/// Frame composition (camera -> device -> ENU) and the angles derived from an ENU ray.
public enum LineOfSight {

    /// Composes a camera-frame ray into the local ENU frame.
    ///
    /// - `cameraToDevice` maps camera axes to device axes (mounting; device-verified).
    /// - `deviceToENU` maps device axes to the local East-North-Up frame, built by the
    ///   capture layer from the device attitude and true heading at the flash time.
    public static func enuRay(
        cameraRay: Vector3,
        cameraToDevice: Quaternion,
        deviceToENU: Quaternion
    ) -> Vector3 {
        let deviceRay = cameraToDevice.act(on: cameraRay)
        return deviceToENU.act(on: deviceRay).normalized()
    }

    /// Azimuth of an ENU ray in degrees, clockwise from true north, in [0, 360).
    public static func azimuthDegrees(enuRay r: Vector3) -> Double {
        var deg = atan2(r.x, r.y) * 180.0 / Double.pi   // x = east, y = north
        if deg < 0 { deg += 360 }
        return deg
    }

    /// Elevation angle of an ENU ray in degrees above the horizontal.
    public static func elevationDegrees(enuRay r: Vector3) -> Double {
        let horizontal = (r.x * r.x + r.y * r.y).squareRoot()
        return atan2(r.z, horizontal) * 180.0 / Double.pi
    }
}
