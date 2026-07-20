import Foundation

/// A small, seedable PRNG (SplitMix64) so Monte Carlo estimation and its tests
/// are fully deterministic given a seed.
public struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) { self.state = seed }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Standard-normal sampling via the Box-Muller transform.
public enum Gaussian {

    public static func sample<G: RandomNumberGenerator>(using generator: inout G) -> Double {
        let u1 = Swift.max(Double.random(in: 0..<1, using: &generator), 1e-15)
        let u2 = Double.random(in: 0..<1, using: &generator)
        return (-2.0 * log(u1)).squareRoot() * cos(2.0 * Double.pi * u2)
    }

    public static func sample<G: RandomNumberGenerator>(
        mean: Double,
        standardDeviation: Double,
        using generator: inout G
    ) -> Double {
        mean + standardDeviation * sample(using: &generator)
    }
}
