import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import AudioToolbox
import HanabiCore
import HanabiCapture

/// A single `AVCaptureSession` capturing BOTH video and audio, so both sample streams'
/// presentation timestamps come from one session clock (the unified time axis the
/// estimator relies on for flash-to-bang). `start`/`stop` complete asynchronously and
/// `stop` fully tears the session down.
///
/// Video frames yield luminance features + camera intrinsics; audio buffers are decoded to
/// mono PCM and windowed into audio features — both on the shared clock, feeding the flash
/// and bang detectors. Compile-verified on the iOS Simulator; the live sample-buffer
/// handling is exercised on a physical device via TestFlight.
final class DeviceUnifiedCaptureSession: NSObject, UnifiedCaptureBackend, CameraPreviewSource,
    @unchecked Sendable,
    AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let queue = DispatchQueue(label: "com.example.hanabiradar.capture")
    private let lock = NSLock()
    private var onEvent: (@Sendable (UnifiedEvent) -> Void)?
    private var resources: Set<CaptureResource> = []
    private var routeObserver: NSObjectProtocol?
    /// Windows the microphone PCM into `AudioFeatureFrame`s. Created lazily once the real
    /// sample rate is known; touched only on `queue` (captureOutput / teardown).
    private var audioExtractor: AudioFeatureExtractor?

    func start(_ onEvent: @escaping @Sendable (UnifiedEvent) -> Void) async throws {
        setHandler(onEvent)
        try configure()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                if !self.session.isRunning { self.session.startRunning() }
                continuation.resume()
            }
        }
        insert(.session)
        addRouteObserver()
    }

    func stop() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                if self.session.isRunning { self.session.stopRunning() }
                self.session.beginConfiguration()
                self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
                self.audioOutput.setSampleBufferDelegate(nil, queue: nil)
                for output in self.session.outputs { self.session.removeOutput(output) }
                for input in self.session.inputs { self.session.removeInput(input) }
                self.session.commitConfiguration()
                self.audioExtractor?.reset()
                self.audioExtractor = nil
                continuation.resume()
            }
        }
        if let observer = routeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        routeObserver = nil
        setHandler(nil)
        clearResources()
    }

    func residualResources() async -> Set<CaptureResource> {
        lock.lock()
        defer { lock.unlock() }
        return resources
    }

    // MARK: - Preview

    /// Exposes the single `AVCaptureSession` so a preview layer can render the live feed.
    /// The session instance is stable across start/stop, so the layer stays attached; it
    /// simply shows frames once the session is running.
    var previewSession: AVCaptureSession? { session }

    // MARK: - Helpers (lock-guarded shared state)

    private func setHandler(_ handler: (@Sendable (UnifiedEvent) -> Void)?) {
        lock.lock(); onEvent = handler; lock.unlock()
    }

    private func insert(_ resource: CaptureResource) {
        lock.lock(); resources.insert(resource); lock.unlock()
    }

    private func clearResources() {
        lock.lock(); resources.removeAll(); lock.unlock()
    }

    private func emit(_ event: UnifiedEvent) {
        lock.lock(); let handler = onEvent; lock.unlock()
        handler?(event)
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(videoInput) else {
            throw CaptureError.unavailable("camera")
        }
        session.addInput(videoInput)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        // Deliver the bi-planar 4:2:0 format so plane 0 is the luma (Y) channel the flash
        // detector reads directly, no color conversion.
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            insert(.videoOutput)
            insert(.videoDelegate)
        }
        if let connection = videoOutput.connection(with: .video),
           connection.isCameraIntrinsicMatrixDeliverySupported {
            connection.isCameraIntrinsicMatrixDeliveryEnabled = true
        }

        if let microphone = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: microphone),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
            audioOutput.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(audioOutput) {
                session.addOutput(audioOutput)
                insert(.audioOutput)
                insert(.audioDelegate)
            }
        }
    }

    private func addRouteObserver() {
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let input = AVAudioSession.sharedInstance().currentRoute.inputs.first
            let route = AudioRoute(
                portName: input?.portName ?? "unknown",
                isBuiltIn: input?.portType == .builtInMic
            )
            self.emit(.routeChange(
                AudioRouteChange(route: route, reason: "routeChange"),
                CaptureTimestamp(seconds: UptimeClock.now())
            ))
        }
    }

    // Both video and audio arrive here on the shared session clock.
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let seconds = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        let time = CaptureTimestamp(seconds: seconds)
        if output === videoOutput {
            emit(.sample(UnifiedSample(time: time, payload: videoPayload(from: sampleBuffer, time: time))))
        } else {
            for frame in audioFrames(from: sampleBuffer, time: time) {
                emit(.sample(UnifiedSample(time: frame.time, payload: .audio(frame))))
            }
        }
    }

    // MARK: - Audio feature extraction

    /// Decodes the microphone sample buffer to mono PCM and windows it into
    /// `AudioFeatureFrame`s via the shared `AudioFeatureExtractor` (created lazily at the
    /// real sample rate). Returns an empty array for unsupported formats — audio simply
    /// stays silent rather than crashing. Called only on `queue`.
    private func audioFrames(from sampleBuffer: CMSampleBuffer, time: CaptureTimestamp) -> [AudioFeatureFrame] {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return []
        }
        let asbd = asbdPointer.pointee
        guard asbd.mFormatID == kAudioFormatLinearPCM, asbd.mSampleRate > 0 else { return [] }

        let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let nonInterleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0
        let channels = Int(asbd.mChannelsPerFrame)
        let frameStride = nonInterleaved ? 1 : max(channels, 1)

        var blockBuffer: CMBlockBuffer?
        var audioBufferList = AudioBufferList()
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.stride,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return [] }

        let buffers = UnsafeMutableAudioBufferListPointer(&audioBufferList)
        guard let first = buffers.first, let data = first.mData, first.mDataByteSize > 0 else { return [] }
        let bytes = [UInt8](UnsafeRawBufferPointer(start: data, count: Int(first.mDataByteSize)))

        let samples = PCMConverter.channelZero(
            bytes, isFloat: isFloat, bitsPerChannel: Int(asbd.mBitsPerChannel), frameStride: frameStride
        )
        guard !samples.isEmpty else { return [] }

        let extractor = audioExtractor ?? {
            let new = AudioFeatureExtractor(config: .init(sampleRate: asbd.mSampleRate))
            audioExtractor = new
            return new
        }()
        return extractor.process(samples, startTime: time)
    }

    // MARK: - Video feature extraction

    /// Builds the video payload from a sample buffer: the flash-relevant luminance features
    /// (from a downsampled Y plane) plus the frame's camera metadata.
    private func videoPayload(from sampleBuffer: CMSampleBuffer, time: CaptureTimestamp) -> UnifiedSamplePayload {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return .video(Self.emptyLuminance(time), metadata: Self.emptyMetadata())
        }
        let fullWidth = CVPixelBufferGetWidth(pixelBuffer)
        let fullHeight = CVPixelBufferGetHeight(pixelBuffer)
        let intrinsics = Self.cameraIntrinsics(from: sampleBuffer, width: fullWidth, height: fullHeight)
        let luminance = Self.luminance(from: pixelBuffer, time: time)
        return .video(luminance, metadata: FrameMetadata(intrinsics: intrinsics, lensIdentifier: "wide", frameRate: 0))
    }

    /// Downsamples the Y (luma) plane of a bi-planar 4:2:0 buffer into a small grid and
    /// extracts luminance features with the pure `FrameLuminanceExtractor`.
    private static func luminance(from pixelBuffer: CVPixelBuffer, time: CaptureTimestamp) -> FrameLuminanceSample {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard CVPixelBufferGetPlaneCount(pixelBuffer) > 0,
              let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            return emptyLuminance(time)
        }
        let planeWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let planeHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let rowStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        guard planeWidth > 0, planeHeight > 0 else { return emptyLuminance(time) }

        let bytes = base.assumingMemoryBound(to: UInt8.self)
        let cols = min(96, planeWidth)
        let rows = min(72, planeHeight)
        var grid = [UInt8](repeating: 0, count: cols * rows)
        var index = 0
        for r in 0..<rows {
            let srcY = r * planeHeight / rows
            let rowPtr = bytes + srcY * rowStride
            for c in 0..<cols {
                let srcX = c * planeWidth / cols
                grid[index] = rowPtr[srcX]
                index += 1
            }
        }
        return FrameLuminanceExtractor.features(luma: grid, width: cols, height: rows, time: time)
    }

    /// Reads the per-frame camera intrinsic matrix delivered on the sample buffer (enabled
    /// in `configure`), falling back to zeros when unavailable. The matrix is a column-major
    /// 3×3 of `Float32`: K = [fx 0 cx; 0 fy cy; 0 0 1].
    private static func cameraIntrinsics(from sampleBuffer: CMSampleBuffer, width: Int, height: Int) -> CameraIntrinsics {
        var fx = 0.0, fy = 0.0, cx = 0.0, cy = 0.0
        if let raw = CMGetAttachment(
            sampleBuffer,
            key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
            attachmentModeOut: nil
        ) as? Data, raw.count >= MemoryLayout<Float32>.stride * 9 {
            let stride = MemoryLayout<Float32>.stride
            raw.withUnsafeBytes { buffer in
                func element(_ i: Int) -> Double {
                    Double(buffer.loadUnaligned(fromByteOffset: i * stride, as: Float32.self))
                }
                // Column-major: fx=[0], fy=[4], cx=[6], cy=[7].
                fx = element(0); fy = element(4); cx = element(6); cy = element(7)
            }
        }
        return CameraIntrinsics(
            fx: fx, fy: fy, cx: cx, cy: cy,
            width: Double(width), height: Double(height)
        )
    }

    private static func emptyLuminance(_ time: CaptureTimestamp) -> FrameLuminanceSample {
        FrameLuminanceSample(
            time: time, meanLuminance: 0, peakLuminance: 0, brightArea: 0,
            brightCentroid: NormalizedPoint(x: 0.5, y: 0.5), atFrameEdge: false
        )
    }

    private static func emptyMetadata() -> FrameMetadata {
        FrameMetadata(
            intrinsics: CameraIntrinsics(fx: 0, fy: 0, cx: 0, cy: 0, width: 0, height: 0),
            lensIdentifier: "wide", frameRate: 0
        )
    }
}
