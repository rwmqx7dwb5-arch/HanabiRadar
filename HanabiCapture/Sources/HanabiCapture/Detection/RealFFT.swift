import Foundation

/// A minimal, dependency-free radix-2 Cooley–Tukey FFT used by the audio feature
/// extractor. Kept in pure Swift (no Accelerate) so the audio features are deterministic
/// and unit-testable on any platform the tests run on.
enum RealFFT {

    /// Magnitude spectrum (bins `0 ..< n/2`) of a real signal whose length `n` is a power
    /// of two. Magnitudes are scaled by `1/n`. Returns an empty array if `n` is not a
    /// positive power of two.
    static func magnitudes(_ signal: [Double]) -> [Double] {
        let n = signal.count
        guard n >= 2, n & (n - 1) == 0 else { return [] }
        var re = signal
        var im = [Double](repeating: 0, count: n)
        transform(&re, &im)
        let scale = 1.0 / Double(n)
        var mags = [Double](repeating: 0, count: n / 2)
        for k in 0..<(n / 2) {
            mags[k] = (re[k] * re[k] + im[k] * im[k]).squareRoot() * scale
        }
        return mags
    }

    /// In-place iterative FFT of complex data `(re, im)` of power-of-two length.
    private static func transform(_ re: inout [Double], _ im: inout [Double]) {
        let n = re.count

        // Bit-reversal permutation.
        var j = 0
        for i in 1..<n {
            var bit = n >> 1
            while j & bit != 0 {
                j ^= bit
                bit >>= 1
            }
            j ^= bit
            if i < j {
                re.swapAt(i, j)
                im.swapAt(i, j)
            }
        }

        // Butterfly stages.
        var len = 2
        while len <= n {
            let angle = -2.0 * Double.pi / Double(len)
            let wLenRe = cos(angle)
            let wLenIm = sin(angle)
            var start = 0
            while start < n {
                var wRe = 1.0
                var wIm = 0.0
                let half = len / 2
                for k in 0..<half {
                    let uRe = re[start + k]
                    let uIm = im[start + k]
                    let vReRaw = re[start + k + half]
                    let vImRaw = im[start + k + half]
                    let vRe = vReRaw * wRe - vImRaw * wIm
                    let vIm = vReRaw * wIm + vImRaw * wRe
                    re[start + k] = uRe + vRe
                    im[start + k] = uIm + vIm
                    re[start + k + half] = uRe - vRe
                    im[start + k + half] = uIm - vIm
                    let nextWRe = wRe * wLenRe - wIm * wLenIm
                    wIm = wRe * wLenIm + wIm * wLenRe
                    wRe = nextWRe
                }
                start += len
            }
            len <<= 1
        }
    }
}
