import Foundation
import AVFoundation
import HanabiCapture

/// AVAudioEngine microphone source. Uses the `.measurement` mode to suppress system
/// processing, taps the input for an RMS level per buffer, and reports audio-route
/// changes. Timestamps use the buffer host time mapped onto the uptime axis. Requires a
/// physical device.
///
/// Note: tight audio/video synchronization ultimately wants both captured in one
/// AVCaptureSession (shared clock); unifying them is device-verified work in Phase 2.
final class DeviceAudioCaptureService: AudioCaptureService {
    weak var sink: CaptureSink?
    private(set) var isRunning = false

    private let engine = AVAudioEngine()
    private var routeObserver: NSObjectProtocol?

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)
        observeRouteChanges(session)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, when in
            guard let self else { return }
            let level = Self.rms(buffer)
            let seconds = Self.seconds(for: when)
            DispatchQueue.main.async {
                self.sink?.ingest(audioLevel: Timed(time: CaptureTimestamp(seconds: seconds), value: level))
            }
        }
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
        }
        routeObserver = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        isRunning = false
    }

    private func observeRouteChanges(_ session: AVAudioSession) {
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let input = session.currentRoute.inputs.first
            let route = AudioRoute(
                portName: input?.portName ?? "unknown",
                isBuiltIn: input?.portType == .builtInMic
            )
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) ?? 0
            self.sink?.ingest(
                routeChange: AudioRouteChange(route: route, reason: String(reason)),
                at: CaptureTimestamp(seconds: UptimeClock.now())
            )
        }
    }

    private static func seconds(for when: AVAudioTime) -> Double {
        if when.isHostTimeValid {
            return AVAudioTime.seconds(forHostTime: when.hostTime)
        }
        return UptimeClock.now()
    }

    private static func rms(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum = 0.0
        for index in 0..<count {
            let value = Double(channelData[index])
            sum += value * value
        }
        return (sum / Double(count)).squareRoot()
    }
}
