import Foundation

/// A quaternion used to represent rotations between coordinate frames
/// (camera -> device -> local ENU). Assumed to be unit-length for rotations.
public struct Quaternion: Equatable, Sendable {
    public var w: Double
    public var x: Double
    public var y: Double
    public var z: Double

    public init(w: Double, x: Double, y: Double, z: Double) {
        self.w = w; self.x = x; self.y = y; self.z = z
    }

    public static let identity = Quaternion(w: 1, x: 0, y: 0, z: 0)

    public var lengthSquared: Double { w * w + x * x + y * y + z * z }
    public var length: Double { lengthSquared.squareRoot() }

    public func normalized() -> Quaternion {
        let n = length
        guard n > 0 else { return .identity }
        return Quaternion(w: w / n, x: x / n, y: y / n, z: z / n)
    }

    public var conjugate: Quaternion { Quaternion(w: w, x: -x, y: -y, z: -z) }

    public static func * (a: Quaternion, b: Quaternion) -> Quaternion {
        Quaternion(
            w: a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
            x: a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
            y: a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
            z: a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w
        )
    }

    /// Rotates `v` by this (assumed unit) quaternion.
    /// v' = (s^2 - |u|^2) v + 2 (u . v) u + 2 s (u x v), with s = w, u = (x, y, z).
    public func act(on v: Vector3) -> Vector3 {
        let u = Vector3(x, y, z)
        let s = w
        let a = (s * s - u.dot(u))
        let b = 2.0 * u.dot(v)
        let c = 2.0 * s
        return (v * a) + (u * b) + (u.cross(v) * c)
    }

    /// A rotation of `angle` radians about `axis`.
    public init(axis: Vector3, angle: Double) {
        let n = axis.normalized()
        let half = angle / 2.0
        let s = sin(half)
        self.init(w: cos(half), x: n.x * s, y: n.y * s, z: n.z * s)
    }

    /// The shortest-arc rotation taking unit vector `a` onto unit vector `b`.
    public init(from a: Vector3, to b: Vector3) {
        let u = a.normalized()
        let v = b.normalized()
        let d = u.dot(v)
        if d >= 1.0 - 1e-12 {
            self = .identity
            return
        }
        if d <= -1.0 + 1e-12 {
            // Antiparallel: rotate 180 degrees about any orthogonal axis.
            var axis = Vector3(1, 0, 0).cross(u)
            if axis.length < 1e-6 { axis = Vector3(0, 1, 0).cross(u) }
            self = Quaternion(axis: axis, angle: Double.pi)
            return
        }
        let axis = u.cross(v)
        self = Quaternion(w: 1.0 + d, x: axis.x, y: axis.y, z: axis.z).normalized()
    }

    /// Builds a quaternion from a proper rotation matrix (Shepperd's method).
    public init(rotationMatrix m: Matrix3) {
        let trace = m.m00 + m.m11 + m.m22
        if trace > 0 {
            let s = 0.5 / (trace + 1.0).squareRoot()
            self.init(
                w: 0.25 / s,
                x: (m.m21 - m.m12) * s,
                y: (m.m02 - m.m20) * s,
                z: (m.m10 - m.m01) * s
            )
        } else if m.m00 > m.m11 && m.m00 > m.m22 {
            let s = 2.0 * (1.0 + m.m00 - m.m11 - m.m22).squareRoot()
            self.init(
                w: (m.m21 - m.m12) / s,
                x: 0.25 * s,
                y: (m.m01 + m.m10) / s,
                z: (m.m02 + m.m20) / s
            )
        } else if m.m11 > m.m22 {
            let s = 2.0 * (1.0 + m.m11 - m.m00 - m.m22).squareRoot()
            self.init(
                w: (m.m02 - m.m20) / s,
                x: (m.m01 + m.m10) / s,
                y: 0.25 * s,
                z: (m.m12 + m.m21) / s
            )
        } else {
            let s = 2.0 * (1.0 + m.m22 - m.m00 - m.m11).squareRoot()
            self.init(
                w: (m.m10 - m.m01) / s,
                x: (m.m02 + m.m20) / s,
                y: (m.m12 + m.m21) / s,
                z: 0.25 * s
            )
        }
    }

    public var rotationMatrix: Matrix3 {
        let q = normalized()
        let (qw, qx, qy, qz) = (q.w, q.x, q.y, q.z)
        return Matrix3(
            1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qw * qz),     2 * (qx * qz + qw * qy),
            2 * (qx * qy + qw * qz),     1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qw * qx),
            2 * (qx * qz - qw * qy),     2 * (qy * qz + qw * qx),     1 - 2 * (qx * qx + qy * qy)
        )
    }

    public func dot(_ b: Quaternion) -> Double { w * b.w + x * b.x + y * b.y + z * b.z }

    /// Spherical linear interpolation between two unit quaternions.
    /// Used to interpolate device attitude to the exact flash timestamp.
    public static func slerp(_ a: Quaternion, _ b: Quaternion, _ t: Double) -> Quaternion {
        var cosom = a.dot(b)
        var end = b
        if cosom < 0 {
            cosom = -cosom
            end = Quaternion(w: -b.w, x: -b.x, y: -b.y, z: -b.z)
        }
        if cosom > 0.9995 {
            // Nearly parallel: fall back to normalized linear interpolation.
            let r = Quaternion(
                w: a.w + (end.w - a.w) * t,
                x: a.x + (end.x - a.x) * t,
                y: a.y + (end.y - a.y) * t,
                z: a.z + (end.z - a.z) * t
            )
            return r.normalized()
        }
        let omega = acos(cosom)
        let sinom = sin(omega)
        let scale0 = sin((1 - t) * omega) / sinom
        let scale1 = sin(t * omega) / sinom
        return Quaternion(
            w: scale0 * a.w + scale1 * end.w,
            x: scale0 * a.x + scale1 * end.x,
            y: scale0 * a.y + scale1 * end.y,
            z: scale0 * a.z + scale1 * end.z
        )
    }
}
