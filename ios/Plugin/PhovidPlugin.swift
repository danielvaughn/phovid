import Foundation
import Capacitor
import AVFoundation
import MobileCoreServices
import UIKit

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(PhovidPlugin)
public class PhovidPlugin: CAPPlugin {
  private let implementation = CaptureIosMedia()
  var capWebView: WKWebView!

  override public func load() {
    self.capWebView = self.bridge?.webView
  }

  @objc override public func checkPermissions(_ call: CAPPluginCall) {
    // TODO
  }

  @objc override public func requestPermissions(_ call: CAPPluginCall) {
    // TODO
  }

  @objc func startCapture(_ call: CAPPluginCall) {
    DispatchQueue.global(qos: .default).async {
      do {
        try self.implementation.startCapture(self.capWebView)
        call.resolve(["success": true])
      } catch CaptureIosMediaError.captureSessionAlreadyRunning {
        call.reject("The capture session is already running")
      } catch CaptureIosMediaError.invalidPermissions {
        call.reject("You do not have permission to begin the capture session")
      } catch {
        call.reject("Unknown error while starting capture session: \(error)")
      }
    }
  }

  @objc func stopCapture(_ call: CAPPluginCall) {
    DispatchQueue.global(qos: .default).async {
      self.implementation.stopCapture(self.capWebView)
      call.resolve(["success": true])
    }
  }

  @objc func capturePhoto(_ call: CAPPluginCall) {
    DispatchQueue.global(qos: .default).async {
      self.implementation.capturePhoto { (fileUrl, error) in
        guard
          let fileUrl = fileUrl,
          error == nil
        else {
          call.reject(error?.localizedDescription ?? "Unknown error")
          return
        }

        call.resolve(["fileUrl": fileUrl, "success": true])
      }
    }
  }

  @objc public func startRecording(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      do {
        try self.implementation.startRecording()
        call.resolve(["success": true])
      } catch CaptureIosMediaError.captureSessionIsMissing {
        call.reject("The capture session is missing")
      } catch {
        call.reject("Unknown error")
      }
    }
  }

  @objc public func stopRecording(_ call: CAPPluginCall) {
    DispatchQueue.global(qos: .default).async {
      self.implementation.stopRecording { (videoUrl, photoUrl, error) in
        guard
          let videoUrl = videoUrl,
          let photoUrl = photoUrl
        else {
          call.reject(error?.localizedDescription ?? "Unknown error")
          return
        }

        call.resolve(["videoUrl": videoUrl.absoluteString, "photoUrl": photoUrl.absoluteString, "success": true])
      }
    }
  }

  @objc public func flipCamera(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      do {
        try self.implementation.flipCamera()
      } catch CaptureIosMediaError.captureSessionIsMissing {
        call.reject("The capture session is missing")
      } catch {
        call.reject("Unknown error")
      }
      
      call.resolve(["success": true])
    }
  }

  @objc public func setFlashMode(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      guard let flashModeStr = call.getString("flashMode") else {
        call.reject("flashMode parameter is required")
        return
      }

      self.implementation.setFlashMode(flashModeStr)
      call.resolve(["success": true])
    }
  }

  @objc public func setZoom(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
      guard let zoomStr = call.getString("zoom") else {
        call.reject("zoom parameter is required")
        return
      }

      self.implementation.setZoom(zoomStr)
      call.resolve(["success": true])
    }
  }
}

