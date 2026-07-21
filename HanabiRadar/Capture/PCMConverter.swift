import Foundation

/// Converts a linear-PCM byte blob into normalized `Float` mono samples in [-1, 1].
///
/// The device audio path hands over the raw bytes of one `AudioBuffer` plus the format's
/// shape; keeping the sample decoding here (pure, no CoreMedia) makes the fiddly parts —
/// integer scaling, interleaved-channel stride, sample width — unit-testable in the
/// Simulator, independent of any live microphone.
enum PCMConverter {

    /// Decodes channel 0 from a native-endian linear-PCM blob.
    ///
    /// - `isFloat`: samples are `Float32`; otherwise signed integer.
    /// - `bitsPerChannel`: 16 or 32.
    /// - `frameStride`: interleaved channels in the blob (1 for a single-channel buffer);
    ///   only channel 0 is read.
    static func channelZero(
        _ data: [UInt8],
        isFloat: Bool,
        bitsPerChannel: Int,
        frameStride: Int
    ) -> [Float] {
        let bytesPerSample = bitsPerChannel / 8
        let stride = max(frameStride, 1)
        guard bytesPerSample > 0, stride > 0 else { return [] }
        let frameBytes = bytesPerSample * stride
        let frameCount = data.count / frameBytes
        guard frameCount > 0 else { return [] }

        var out = [Float](repeating: 0, count: frameCount)
        data.withUnsafeBytes { raw in
            for i in 0..<frameCount {
                let offset = i * frameBytes   // channel 0 sits at the start of each frame
                if isFloat, bitsPerChannel == 32 {
                    out[i] = raw.loadUnaligned(fromByteOffset: offset, as: Float32.self)
                } else if !isFloat, bitsPerChannel == 16 {
                    let v = raw.loadUnaligned(fromByteOffset: offset, as: Int16.self)
                    out[i] = Float(v) / 32_768.0
                } else if !isFloat, bitsPerChannel == 32 {
                    let v = raw.loadUnaligned(fromByteOffset: offset, as: Int32.self)
                    out[i] = Float(Double(v) / 2_147_483_648.0)
                }
                // Unsupported widths leave a 0 sample (defensive; caller checks the format).
            }
        }
        return out
    }
}
