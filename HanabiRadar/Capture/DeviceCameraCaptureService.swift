import Foundation
import AVFoundation
import HanabiCapture

/// AVFoundation camera source. This increment stands up the capture session (back
/// wide-angle camera, video data output, camera-intrinsics delivery when supported) and
/// tracks frame presentation timestamps. Frame pixel processing and intrinsics delivery
/// into the pipeline are implemented with the flash detector in Phase 2. Requires a
/// physical device; on the Simulator there is no camera, so `start()` throws.
final class DeviceCameraCaptureService: NSObject, CameraCaptureService, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var sink: CaptureSink?
    private(set) var isRunning = false
    private(set) var lastPresentationSeconds: Double?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.example.hanabiradar.camera")

    func start() throws {
        try configureIfNeeded()
        queue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
        isRunning = true
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
        isRunning = false
    }

    private func configureIfNeeded() throws {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            throw CaptureError.unavailable("camera")
        }
        session.addInput(input)
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        if let connection = output.connection(with: .video),
           connection.isCameraIntrinsicMatrixDeliverySupported {
            connection.isCameraIntrinsicMatrixDeliveryEnabled = true
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let presentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        lastPresentationSeconds = CMTimeGetSeconds(presentation)
    }
}
