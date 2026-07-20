import XCTest
import HanabiCore
@testable import HanabiCapture

final class CaptureCoordinatorTests: XCTestCase {

    private struct TestError: Error {}

    private struct Rig {
        let coordinator: CaptureCoordinator
        let camera: MockCameraCaptureService
        let audio: MockAudioCaptureService
        let motion: MockMotionCaptureService
        let location: MockLocationCaptureService
        let logger: InMemoryLogger
    }

    private func makeRig() -> Rig {
        let camera = MockCameraCaptureService()
        let audio = MockAudioCaptureService()
        let motion = MockMotionCaptureService()
        let location = MockLocationCaptureService()
        let logger = InMemoryLogger()
        let coordinator = CaptureCoordinator(
            capacity: 100, camera: camera, audio: audio, motion: motion, location: location, logger: logger
        )
        return Rig(coordinator: coordinator, camera: camera, audio: audio, motion: motion, location: location, logger: logger)
    }

    func testStartRunsAllServices() {
        let rig = makeRig()
        rig.coordinator.start()
        XCTAssertEqual(rig.coordinator.state, .running)
        XCTAssertTrue(rig.camera.isRunning && rig.audio.isRunning && rig.motion.isRunning && rig.location.isRunning)
    }

    func testStopReleasesEveryService() {
        let rig = makeRig()
        rig.coordinator.start()
        rig.coordinator.stop()
        XCTAssertEqual(rig.coordinator.state, .idle)
        XCTAssertFalse(rig.camera.isRunning || rig.audio.isRunning || rig.motion.isRunning || rig.location.isRunning)
        XCTAssertGreaterThanOrEqual(rig.camera.stopCount, 1)
        XCTAssertGreaterThanOrEqual(rig.location.stopCount, 1)
    }

    func testStartFailureTearsDownEverything() {
        let rig = makeRig()
        rig.motion.startError = TestError()
        rig.coordinator.start()

        if case .failed = rig.coordinator.state {} else {
            return XCTFail("expected .failed state, got \(rig.coordinator.state)")
        }
        XCTAssertFalse(rig.camera.isRunning || rig.audio.isRunning || rig.motion.isRunning || rig.location.isRunning)
        XCTAssertGreaterThanOrEqual(rig.camera.stopCount, 1)     // started, then torn down
        XCTAssertGreaterThanOrEqual(rig.location.stopCount, 1)   // stop reaches services that never started
        XCTAssertEqual(rig.location.startCount, 0)               // motion threw before location started
    }

    func testStopIsIdempotent() {
        let rig = makeRig()
        rig.coordinator.start()
        rig.coordinator.stop()
        rig.coordinator.stop()
        XCTAssertEqual(rig.coordinator.state, .idle)
        XCTAssertGreaterThanOrEqual(rig.camera.stopCount, 2)
    }

    func testSinkIngestionPopulatesTimeline() {
        let rig = makeRig()
        rig.coordinator.start()
        rig.motion.emit(attitude: .identity, at: CaptureTimestamp(seconds: 1))
        rig.motion.emit(attitude: Quaternion(axis: Vector3(0, 0, 1), angle: .pi / 2), at: CaptureTimestamp(seconds: 3))
        rig.location.emit(
            location: LocationSample(
                coordinate: GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 0),
                horizontalAccuracy: 5, verticalAccuracy: 8
            ),
            at: CaptureTimestamp(seconds: 2)
        )
        rig.location.emit(heading: HeadingSample(trueHeadingDegrees: 90, accuracyDegrees: 3), at: CaptureTimestamp(seconds: 2))
        rig.audio.emit(audioLevel: 0.5, at: CaptureTimestamp(seconds: 2))

        XCTAssertEqual(rig.coordinator.timeline.attitude.count, 2)
        XCTAssertNotNil(rig.coordinator.timeline.interpolatedAttitude(at: CaptureTimestamp(seconds: 2)))
        XCTAssertEqual(rig.coordinator.timeline.location.count, 1)
        XCTAssertEqual(rig.coordinator.timeline.heading.count, 1)
        XCTAssertEqual(rig.coordinator.lastAudioLevel?.value, 0.5)
    }

    func testRouteChangeWhileRunningInvalidatesMeasurement() {
        let rig = makeRig()
        rig.coordinator.start()
        let route = AudioRoute(portName: "AirPods", isBuiltIn: false)
        rig.audio.emit(routeChange: AudioRouteChange(route: route, reason: "newDeviceAvailable"), at: CaptureTimestamp(seconds: 1))

        XCTAssertTrue(rig.coordinator.routeInvalidatedMeasurement)
        XCTAssertEqual(rig.coordinator.lastRouteChange?.route.portName, "AirPods")
        XCTAssertTrue(rig.logger.events.contains { $0.level == .warning && $0.category == "audio" })
    }
}
