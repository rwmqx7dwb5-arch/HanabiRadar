import SwiftUI
import UIKit
import AVFoundation

/// A capture backend that can vend its `AVCaptureSession` for on-screen preview.
///
/// Only the device backend conforms. The mock / Simulator backend does not, so the
/// measurement screen sees a `nil` session and draws a placeholder instead of a live feed
/// (there is no camera in the Simulator). This keeps the preview device-only without
/// leaking `AVFoundation` into the capture package.
protocol CameraPreviewSource: AnyObject {
    var previewSession: AVCaptureSession? { get }
}

/// SwiftUI wrapper around `AVCaptureVideoPreviewLayer`. Given a running session it shows
/// the live camera feed filling the view; given `nil` it stays clear so the caller can
/// layer a placeholder behind it (Simulator / permission-denied).
///
/// Written on Windows without Xcode — this UIKit/AVFoundation layer is build-verified by
/// the iOS CI and exercised on a physical device via TestFlight, not compiled locally.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }

    /// A `UIView` whose backing layer is an `AVCaptureVideoPreviewLayer`, so the preview
    /// tracks the view's bounds through Auto Layout with no manual frame bookkeeping.
    final class PreviewContainerView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            // Safe: `layerClass` guarantees the backing layer's type.
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
