import XCTest
import HanabiCore
@testable import HanabiCapture

final class ReplayEngineTests: XCTestCase {

    private func makeSink() -> CaptureCoordinator {
        CaptureCoordinator(
            capacity: 100,
            camera: MockCameraCaptureService(),
            audio: MockAudioCaptureService(),
            motion: MockMotionCaptureService(),
            location: MockLocationCaptureService(),
            logger: InMemoryLogger()
        )
    }

    func testReplayIsTimeOrderedAndDeterministic() {
        let session = RecordedSession(samples: [
            .attitude(Timed(time: CaptureTimestamp(seconds: 3), value: Quaternion(axis: Vector3(0, 0, 1), angle: .pi / 2))),
            .attitude(Timed(time: CaptureTimestamp(seconds: 1), value: .identity)),
            .location(Timed(
                time: CaptureTimestamp(seconds: 2),
                value: LocationSample(
                    coordinate: GeodeticCoordinate(latitude: 35, longitude: 139, altitude: 0),
                    horizontalAccuracy: 5, verticalAccuracy: 8
                )
            ))
        ])
        let engine = ReplayEngine()

        let first = makeSink()
        engine.replay(session, into: first)
        let second = makeSink()
        engine.replay(session, into: second)

        XCTAssertEqual(first.timeline.attitude.count, 2)
        XCTAssertEqual(first.timeline.location.count, 1)
        // Samples were fed in time order regardless of input order.
        XCTAssertEqual(first.timeline.attitude.oldest?.time.seconds, 1)
        XCTAssertEqual(first.timeline.attitude.newest?.time.seconds, 3)

        // Deterministic: identical interpolation from both replays.
        let time = CaptureTimestamp(seconds: 2)
        let a = first.timeline.interpolatedAttitude(at: time)!.act(on: Vector3(1, 0, 0))
        let b = second.timeline.interpolatedAttitude(at: time)!.act(on: Vector3(1, 0, 0))
        XCTAssertEqual(a.x, b.x, accuracy: 1e-12)
        XCTAssertEqual(a.y, b.y, accuracy: 1e-12)
        XCTAssertEqual(a.z, b.z, accuracy: 1e-12)
    }
}
