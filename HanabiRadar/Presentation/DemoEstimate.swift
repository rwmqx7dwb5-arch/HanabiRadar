import Foundation
import HanabiCore

/// Computes a fixed demo estimate so the skeleton screen shows the core working.
/// This is not a real measurement; it exercises the deterministic solver kernel.
enum DemoEstimate {
    static func compute() -> String {
        let solver = BurstSolver()
        let observer = GeodeticCoordinate(latitude: 35.681, longitude: 139.767, altitude: 30)
        let azimuth = 45.0 * .pi / 180
        let elevation = 40.0 * .pi / 180
        let ray = Vector3(
            cos(elevation) * sin(azimuth),
            cos(elevation) * cos(azimuth),
            sin(elevation)
        )
        let estimate = solver.estimate(
            observer: observer,
            enuRay: ray,
            deltaT: 4.0,
            effectiveSoundSpeed: 343.0,
            iterations: 0
        )
        let distance = Formatting.distance(meters: estimate.lineOfSightDistance, metric: true)
        return "距離 \(distance) / 仰角 \(String(format: "%.0f", estimate.elevationDegrees))°"
            + " / 方位 \(String(format: "%.0f", estimate.azimuthDegrees))°"
    }
}
