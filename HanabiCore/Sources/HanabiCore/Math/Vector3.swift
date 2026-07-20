/// A 3-component vector of doubles, used for ECEF / ENU / camera geometry.
public struct Vector3: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Vector3(0, 0, 0)

    public static func + (a: Vector3, b: Vector3) -> Vector3 {
        Vector3(a.x + b.x, a.y + b.y, a.z + b.z)
    }

    public static func - (a: Vector3, b: Vector3) -> Vector3 {
        Vector3(a.x - b.x, a.y - b.y, a.z - b.z)
    }

    public static prefix func - (a: Vector3) -> Vector3 {
        Vector3(-a.x, -a.y, -a.z)
    }

    public static func * (a: Vector3, s: Double) -> Vector3 {
        Vector3(a.x * s, a.y * s, a.z * s)
    }

    public static func * (s: Double, a: Vector3) -> Vector3 { a * s }

    public static func / (a: Vector3, s: Double) -> Vector3 {
        Vector3(a.x / s, a.y / s, a.z / s)
    }

    public func dot(_ b: Vector3) -> Double { x * b.x + y * b.y + z * b.z }

    public func cross(_ b: Vector3) -> Vector3 {
        Vector3(
            y * b.z - z * b.y,
            z * b.x - x * b.z,
            x * b.y - y * b.x
        )
    }

    public var lengthSquared: Double { x * x + y * y + z * z }

    public var length: Double { lengthSquared.squareRoot() }

    /// Returns the unit vector, or `.zero` for a zero-length input.
    public func normalized() -> Vector3 {
        let n = length
        guard n > 0 else { return .zero }
        return self / n
    }

    /// Distance to another point.
    public func distance(to b: Vector3) -> Double { (self - b).length }
}
