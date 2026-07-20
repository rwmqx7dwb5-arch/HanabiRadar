/// A WGS84 geodetic coordinate. Latitude/longitude in degrees, height in meters.
///
/// In the pure geometry `altitude` is treated as ellipsoidal height. Conversion to
/// mean-sea-level / orthometric height (geoid separation) and to height-above-ground
/// (terrain elevation) is the responsibility of the app-side providers; see
/// SCIENCE_AND_MATH.md for the datum discussion.
public struct GeodeticCoordinate: Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double

    public init(latitude: Double, longitude: Double, altitude: Double = 0) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }

    public var latitudeRadians: Double { latitude * Double.pi / 180.0 }
    public var longitudeRadians: Double { longitude * Double.pi / 180.0 }
}

/// A point in FULL pixel-buffer coordinates: origin at the top-left, +u to the
/// right, +v downward. This is deliberately not the preview-view coordinate space;
/// the capture layer must map preview taps / detector centroids into pixel-buffer
/// coordinates (accounting for aspect fill, mirroring, and crop) before use.
public struct ImagePoint: Equatable, Sendable {
    public var u: Double
    public var v: Double

    public init(u: Double, v: Double) {
        self.u = u
        self.v = v
    }
}

/// Pinhole camera intrinsics expressed in the SAME pixel space as the `ImagePoint`s
/// passed to the solver. `fx, fy` are focal lengths in pixels; `cx, cy` the principal
/// point; `width, height` the pixel-buffer dimensions the intrinsics were measured at.
public struct CameraIntrinsics: Equatable, Sendable {
    public var fx: Double
    public var fy: Double
    public var cx: Double
    public var cy: Double
    public var width: Double
    public var height: Double

    public init(fx: Double, fy: Double, cx: Double, cy: Double, width: Double, height: Double) {
        self.fx = fx
        self.fy = fy
        self.cx = cx
        self.cy = cy
        self.width = width
        self.height = height
    }

    /// The 3x3 intrinsic matrix K.
    public var matrix: Matrix3 {
        Matrix3(
            fx, 0, cx,
            0, fy, cy,
            0, 0, 1
        )
    }

    /// Rescales the intrinsics from their native resolution to a different pixel
    /// resolution (e.g. when the detector runs on a downscaled buffer).
    public func scaled(toWidth newWidth: Double, height newHeight: Double) -> CameraIntrinsics {
        let sx = newWidth / width
        let sy = newHeight / height
        return CameraIntrinsics(
            fx: fx * sx, fy: fy * sy,
            cx: cx * sx, cy: cy * sy,
            width: newWidth, height: newHeight
        )
    }
}
