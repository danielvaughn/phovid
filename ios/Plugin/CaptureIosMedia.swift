import Foundation
import AVFoundation
import UIKit
import AVKit

// Define the errors we expect to encounter.
enum CaptureIosMediaError: Swift.Error {
  case invalidPermissions
  case captureSessionAlreadyRunning
  case captureSessionIsMissing
  case noCamerasAvailable
  case unknown
}

@objc public class CaptureIosMedia: NSObject, AVCaptureFileOutputRecordingDelegate, AVCapturePhotoCaptureDelegate {
  public var captureSession: AVCaptureSession?
  var videoInput: AVCaptureDeviceInput?
  var videoOutput: AVCaptureMovieFileOutput?
  var photoOutput: AVCapturePhotoOutput?
  var viewColor: UIColor?
  var camera: CameraView?
  var photoCaptureCompletionBlock: ((String?, Error?) -> Void)?
  var videoCaptureCompletionBlock: ((URL?, URL?, Error?) -> Void)?

  var flashMode: AVCaptureDevice.FlashMode = .off

  // This method begins the media capture session.
  public func startCapture(_ view: UIView) throws {
    // Prevent capturing a session twice.
    if (self.captureSession?.isRunning != nil) {
      throw CaptureIosMediaError.captureSessionAlreadyRunning
    }

    // Verify that the user has permitted access to video/audio.
    if (!checkAVPermissions()) {
      throw CaptureIosMediaError.invalidPermissions
    }

    // Initialize a new capture session.
    let captureSession = AVCaptureSession()

    /*
      Begin a configuration session for the capture session.
      In this code we set parameters for audio and video.
      We also need to add inputs and outputs for both.
     */
    captureSession.beginConfiguration()

    // Configure the session to use the public audio instance.
    captureSession.usesApplicationAudioSession = true

    // Configure the session to let the device determine how best to capture audio.
    captureSession.automaticallyConfiguresApplicationAudioSession = true

    // Add the default video input to the session. Return if it cannot be initialized.
    let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    guard
      let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice!),
      captureSession.canAddInput(videoDeviceInput)
    else {
      throw CaptureIosMediaError.noCamerasAvailable
    }

    // Add the default audio input to the session. Return if it cannot be initialized.
    let audioDevice = AVCaptureDevice.default(for: .audio)
    guard
      let audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice!),
      captureSession.canAddInput(audioDeviceInput)
    else {
      throw CaptureIosMediaError.noCamerasAvailable
    }

    // Add a video output for standard MOV files.
    let videoOutput = AVCaptureMovieFileOutput()

    // Disable movie fragment generation.
    videoOutput.movieFragmentInterval = CMTime.invalid

    // Add a photo output.
    let photoOutput = AVCapturePhotoOutput()

    // Always capture photos at their highest resolution.
    photoOutput.isHighResolutionCaptureEnabled = true

    // Bind the inputs and outputs to the session.
    captureSession.addInput(videoDeviceInput)
    captureSession.addInput(audioDeviceInput)
    captureSession.addOutput(videoOutput)
    captureSession.addOutput(photoOutput)

    // Create a connection for the video output stream.
    let connection: AVCaptureConnection? = videoOutput.connection(with: .video)

    // Set the encoding for the stream.
    videoOutput.setOutputSettings([AVVideoCodecKey : AVVideoCodecType.h264], for: connection!)

    // Commit the configuration details to close the configuration session.
    captureSession.commitConfiguration()

    // Start running the session.
    captureSession.startRunning()

    // Bind references to the session and outputs to the class.
    self.captureSession = captureSession
    self.videoInput = videoDeviceInput
    self.videoOutput = videoOutput
    self.photoOutput = photoOutput

    DispatchQueue.main.async {
      // Create the UI view that will present the stream output.
      let cameraView = CameraView(frame: view.bounds)

      // Append the session to the view.
      cameraView.addPreviewLayer(captureSession)

      // Bind a reference to the view.
      self.camera = cameraView

      // Store the current color of the main view so we know what color to set it back to once we're done.
      self.viewColor = view.backgroundColor

      // While the session is active, we need to make the background transparent.
      view.backgroundColor = UIColor.clear
      view.isOpaque = false
      view.scrollView.backgroundColor = UIColor.clear
      view.scrollView.isOpaque = false

      // Finally, append the stream view to the target view.
      view.superview?.insertSubview(cameraView, belowSubview: view)
    }
  }

  // This method destroys the capture session and the related UI view.
  public func stopCapture(_ view: UIView) {
    // Set the bound references back to nil.
    self.captureSession = nil
    self.videoOutput = nil
    self.photoOutput = nil

    DispatchQueue.main.async {
      // Return the view's background color to its original and reset it to opaque.
      view.backgroundColor = self.viewColor ?? UIColor.white
      view.isOpaque = true

      // Remove the preview layer from the camera view.
      self.camera?.removePreviewLayer()

      // Remove the camera view from it's container.
      self.camera?.removeFromSuperview()
    }
  }

  // As the name implies, this method captures a photo from an active media stream.
  public func capturePhoto(completion: @escaping (String?, Error?) -> Void) {
    // Return if the session either isn't initialized or active.
    guard let captureSession = self.captureSession, captureSession.isRunning else {
      completion(nil, CaptureIosMediaError.captureSessionIsMissing)
      return
    }

    // Set flash mode based on the current value.
    let settings = AVCapturePhotoSettings()

    settings.flashMode = self.flashMode

    // Store a reference to the callback so we can call it via the "photoOutput" delegate method.
    self.photoCaptureCompletionBlock = completion

    // Call the photo output capturePhoto method.
    self.photoOutput?.capturePhoto(with: settings, delegate: self)
  }

  // This is a private helper method for generating a unique and temporary file path for either a video or photo file.
  private func tempUrl(_ fileType: String!) -> URL {
    let dir = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true)
    var fileName = "media_capture_" + ProcessInfo().globallyUniqueString
    fileName.append("." + fileType)
    let url = dir.appendingPathComponent(fileName)

    return url
  }

  // We need to check the user permissions before launching a streaming session, otherwise the app will crash.
  func checkAVPermissions() -> Bool {
    // Create a mutable variable for authorized status.
    var authorized = true

    // First we check the permission status for video.
    switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .authorized:
        break
      case .restricted:
        authorized = false
      case .denied:
        authorized = false
      case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { granted in
          if granted != true {
            authorized = false
          }
        }
      @unknown default:
        authorized = false
    }

    // Then we check the permission status for audio.
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
      case .authorized:
        break
      case .restricted:
        authorized = false
      case .denied:
        authorized = false
      case .notDetermined:
        AVCaptureDevice.requestAccess(for: .audio) { granted in
          if granted != true {
            authorized = false
          }
        }
      @unknown default:
        authorized = false
    }

    return authorized
  }

  @objc public func echo(_ value: String) -> String {
    print(value)
    return value
  }

  // This method begins recording the video output stream.
  public func startRecording() throws {
    // Ensure that the capture session exists, and isn't already running video.
    guard
      let _ = self.captureSession,
      self.videoOutput?.isRecording == false
    else {
      throw CaptureIosMediaError.captureSessionIsMissing
    }

    // Create a temporary file path and name to store our video.
    let fileUrl = self.tempUrl("mp4")
    DispatchQueue.main.async {
      self.videoOutput?.startRecording(to: fileUrl, recordingDelegate: self)
    }
  }

  // This method stops recording video.
  public func stopRecording(completion: @escaping (URL?, URL?, Error?) -> Void) {
    // Return if a video isn't currently being recorded, or if the capture session doesn't exist.
    if (self.captureSession == nil || !(self.videoOutput?.isRecording)!) {
      return
    }

    DispatchQueue.main.async {
      // Store a reference to the callback so we can call it from the "fileOutput" delegate method.
      self.videoCaptureCompletionBlock = completion

      // Call the stop recording method on the video output.
      self.videoOutput?.stopRecording()
    }
  }

  // Name is obvious - this method flips the camera.
  public func flipCamera() throws {
    // Make sure all the necessary stuff is available and running.
    guard
      let currentVideoInput = self.videoInput,
      let captureSession = self.captureSession,
      captureSession.inputs.contains(currentVideoInput),
      captureSession.isRunning
    else {
      throw CaptureIosMediaError.captureSessionIsMissing
    }

    // Start a configuration session for the capture session.
    captureSession.beginConfiguration()

    // Determine the new camera position based on the current value.
    let newPosition: AVCaptureDevice.Position = currentVideoInput.device.position == .back ? .front : .back

    // Create a device with the new position.
    let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition)

    // First, remove the current video input. This is important so that the "canAddInput" check returns true.
    captureSession.removeInput(currentVideoInput)

    // Ensure that adding the input will work correctly.
    guard
      let videoDevice = videoDevice,
      let newVideoInput = try? AVCaptureDeviceInput(device: videoDevice),
      captureSession.canAddInput(newVideoInput)
    else {
      return
    }

    // Add the new position input.
    captureSession.addInput(newVideoInput)

    // Commit the changes to the capture session.
    captureSession.commitConfiguration()

    // Store the new video input.
    self.videoInput = newVideoInput
  }

  public func setFlashMode(_ flashModeString: String) {
    var flashMode: AVCaptureDevice.FlashMode

    switch flashModeString {
      case "off":
        flashMode = .off
      case "on":
        flashMode = .on
      default:
        flashMode = .auto
    }

    self.flashMode = flashMode
  }

  public func setZoom(_ zoomString: String) {
    let device = self.videoInput!.device
    let minimumZoom = 1.0
    let maximumZoom = 5.0

    let scale = Float(zoomString)

      // Return zoom value between the minimum and maximum zoom values
      func minMaxZoom(_ factor: CGFloat) -> CGFloat {
          return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
      }

      func update(scale factor: CGFloat) {
          do {
              try device.lockForConfiguration()
              defer { device.unlockForConfiguration() }
              device.videoZoomFactor = factor
          } catch {
              print("\(error.localizedDescription)")
          }
      }

      let newScaleFactor = minMaxZoom(CGFloat(scale!))

      update(scale: newScaleFactor)
  }

  /*
   This method satisfies the AVCapturePhotoCaptureDelegate interface.
   "photoOutput" is the method that will be called when the camera is finished creating the photo.
   */
  public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    // If something went wrong, return early with a null response.
    if error != nil {
      self.photoCaptureCompletionBlock?(nil, error)
      return
    }

    // Convert the photo to raw data so we can write it to a temporary directory.
    let data = photo.fileDataRepresentation()

    // Create a temporary url (with a random and unique name) for a jpeg file.
    let fileUrl = self.tempUrl("jpeg")
    do {
      // Write the data to the temp path.
      try data?.write(to: fileUrl)
      self.photoCaptureCompletionBlock?(fileUrl.absoluteString, nil)
    } catch {
      self.photoCaptureCompletionBlock?(nil, CaptureIosMediaError.unknown)
    }
  }

  /*
   This method satisfies the AVCaptureFileOutputRecordingDelegate interface.
   "fileOutput" sounds like it could apply to both photos and video, but it's purely for video.
   Once the user stops recording, the system needs to process the remaining chunks of video before making
   it available. This method is called when it's ready.
   */
  public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    let videoAsset = AVAsset(url: outputFileURL)
    let timestamp = CMTime(value: 1, timescale: 1)

    let generator = AVAssetImageGenerator(asset: videoAsset)

    // Optional
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero

    generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: timestamp)]) { requestedTime, image, actualTime, result, error in
      guard
        let image = image
      else {
        self.videoCaptureCompletionBlock?(nil, nil, nil)
        return
      }


      let img = UIImage(cgImage: image)

      let data = img.jpegData(compressionQuality: 0.9)

      // Create a temporary url (with a random and unique name) for a jpeg file.
      let fileUrl = self.tempUrl("jpeg")
      do {
        // Write the data to the temp path.
        try data?.write(to: fileUrl)
        self.videoCaptureCompletionBlock?(outputFileURL, fileUrl, nil)
      } catch {
        self.videoCaptureCompletionBlock?(nil, nil, nil)
      }
    }
  }

}
