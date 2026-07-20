/// A 3x3 matrix stored in row-major order. Used for rotations and the camera
/// intrinsic matrix and its inverse.
public struct Matrix3: Equatable, Sendable {
    public var m00, m01, m02: Double
    public var m10, m11, m12: Double
    public var m20, m21, m22: Double

    public init(
        _ m00: Double, _ m01: Double, _ m02: Double,
        _ m10: Double, _ m11: Double, _ m12: Double,
        _ m20: Double, _ m21: Double, _ m22: Double
    ) {
        self.m00 = m00; self.m01 = m01; self.m02 = m02
        self.m10 = m10; self.m11 = m11; self.m12 = m12
        self.m20 = m20; self.m21 = m21; self.m22 = m22
    }

    public static let identity = Matrix3(1, 0, 0, 0, 1, 0, 0, 0, 1)

    /// Builds a matrix whose COLUMNS are the given vectors.
    public static func columns(_ c0: Vector3, _ c1: Vector3, _ c2: Vector3) -> Matrix3 {
        Matrix3(
            c0.x, c1.x, c2.x,
            c0.y, c1.y, c2.y,
            c0.z, c1.z, c2.z
        )
    }

    /// Builds a matrix whose ROWS are the given vectors.
    public static func rows(_ r0: Vector3, _ r1: Vector3, _ r2: Vector3) -> Matrix3 {
        Matrix3(
            r0.x, r0.y, r0.z,
            r1.x, r1.y, r1.z,
            r2.x, r2.y, r2.z
        )
    }

    public func act(on v: Vector3) -> Vector3 {
        Vector3(
            m00 * v.x + m01 * v.y + m02 * v.z,
            m10 * v.x + m11 * v.y + m12 * v.z,
            m20 * v.x + m21 * v.y + m22 * v.z
        )
    }

    public static func * (a: Matrix3, b: Matrix3) -> Matrix3 {
        Matrix3(
            a.m00 * b.m00 + a.m01 * b.m10 + a.m02 * b.m20,
            a.m00 * b.m01 + a.m01 * b.m11 + a.m02 * b.m21,
            a.m00 * b.m02 + a.m01 * b.m12 + a.m02 * b.m22,
            a.m10 * b.m00 + a.m11 * b.m10 + a.m12 * b.m20,
            a.m10 * b.m01 + a.m11 * b.m11 + a.m12 * b.m21,
            a.m10 * b.m02 + a.m11 * b.m12 + a.m12 * b.m22,
            a.m20 * b.m00 + a.m21 * b.m10 + a.m22 * b.m20,
            a.m20 * b.m01 + a.m21 * b.m11 + a.m22 * b.m21,
            a.m20 * b.m02 + a.m21 * b.m12 + a.m22 * b.m22
        )
    }

    public var transposed: Matrix3 {
        Matrix3(m00, m10, m20, m01, m11, m21, m02, m12, m22)
    }

    public var determinant: Double {
        m00 * (m11 * m22 - m12 * m21)
      - m01 * (m10 * m22 - m12 * m20)
      + m02 * (m10 * m21 - m11 * m20)
    }

    /// Inverse via the adjugate, or `nil` when the matrix is (numerically) singular.
    public var inverse: Matrix3? {
        let det = determinant
        guard abs(det) > 1e-15 else { return nil }
        let invDet = 1.0 / det
        return Matrix3(
            (m11 * m22 - m12 * m21) * invDet,
            (m02 * m21 - m01 * m22) * invDet,
            (m01 * m12 - m02 * m11) * invDet,
            (m12 * m20 - m10 * m22) * invDet,
            (m00 * m22 - m02 * m20) * invDet,
            (m02 * m10 - m00 * m12) * invDet,
            (m10 * m21 - m11 * m20) * invDet,
            (m01 * m20 - m00 * m21) * invDet,
            (m00 * m11 - m01 * m10) * invDet
        )
    }
}
