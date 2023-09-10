#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(PhovidPlugin, "Phovid",
  CAP_PLUGIN_METHOD(echo, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(startCapture, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(stopCapture, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(capturePhoto, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(startRecording, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(stopRecording, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(flipCamera, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setFlashMode, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(setZoom, CAPPluginReturnPromise);
)
