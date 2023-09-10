import Foundation
import UIKit
import AVFoundation

public class CameraView: UIView {
  var videoPreviewLayer: AVCaptureVideoPreviewLayer?

  func addPreviewLayer(_ captureSession: AVCaptureSession) {
    // Initialize preview layer
    let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)

    // Configure video layer
    previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill

    // Set video layer bounds to parent view
    previewLayer.frame = self.bounds

    // Insert video layer
    self.layer.addSublayer(previewLayer)

    // Retain reference
    self.videoPreviewLayer = previewLayer
  }

  func removePreviewLayer() {
    // Remove video layer from parent view
    self.videoPreviewLayer?.removeFromSuperlayer()

    // Remove reference to video layer
    self.videoPreviewLayer = nil
  }

}
