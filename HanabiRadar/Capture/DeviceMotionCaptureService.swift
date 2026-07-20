import Foundation
import CoreMotion
import HanabiCore
import HanabiCapture

/// Core Motion device-attitude source. Delivers the device attitude quaternion
/// (relative to the true-north / vertical reference frame) timed by the sample's own
/// uptime timestamp. Requires a physical device; on the Simulator it compiles but
/// produces no updates.
final class DeviceMotionCaptureService: MotionCaptureService {
    weak var sink: CaptureSink?
    private(set) var isRunning = false

    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    func start() throws {
        guard manager.isDeviceMotionAvailable else {
            throw CaptureError.unavailable("device motion")
        }
        queue.name = "com.example.hanabiradar.motion"
        queue.maxConcurrentOperationCount = 1
        manager.deviceMotionUpdateInterval = 1.0 / 100.0
        manager.startDeviceMotionUpdates(using: .xTrueNorthZVertical, to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let q = motion.attitude.quaternion
            let attitude = Quaternion(w: q.w, x: q.x, y: q.y, z: q.z)
            let time = CaptureTimestamp(seconds: motion.timestamp)
            DispatchQueue.main.async {
                self.sink?.ingest(attitude: Timed(time: time, value: attitude))
            }
        }
        isRunning = true
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isRunning = false
    }
}
