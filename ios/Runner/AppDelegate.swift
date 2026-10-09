import Flutter
import flutter_webrtc
import LocalAuthentication
import UIKit
import AVFoundation
import MediaPlayer
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    prepareWebRTCAudioDevice()
    FlutterMethodChannel(
      name: "aco/downloads",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      guard call.method == "saveImage" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let data = args["bytes"] as? FlutterStandardTypedData,
            let image = UIImage(data: data.data) else {
        result(FlutterError(code: "INVALID_IMAGE", message: "图片数据无效", details: nil))
        return
      }
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        guard status == .authorized || status == .limited else {
          DispatchQueue.main.async {
            result(FlutterError(code: "PERMISSION_DENIED", message: "未获得相册权限", details: nil))
          }
          return
        }
        PHPhotoLibrary.shared().performChanges({
          PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { saved, error in
          DispatchQueue.main.async {
            if saved {
              result(nil)
            } else {
              result(FlutterError(code: "SAVE_FAILED", message: error?.localizedDescription, details: nil))
            }
          }
        }
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AcoLiveAudioBackground") {
      let channel = FlutterMethodChannel(
        name: "aco/live-audio-background",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "start":
          let args = call.arguments as? [String: Any]
          var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
          info[MPMediaItemPropertyTitle] = args?["title"] as? String ?? "会议"
          info[MPMediaItemPropertyArtist] = "Aco Chat"
          info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
          MPNowPlayingInfoCenter.default().nowPlayingInfo = info
          result(nil)
        case "stop":
          MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AcoLiveAudioRoute") {
      let channel = FlutterMethodChannel(
        name: "aco/live-audio-route",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "routeInfo" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(self.liveAudioRouteInfo())
      }
    }
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "AcoBiometricAuthentication"
    ) else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "aco/biometric-authentication",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "availability":
        result(self.biometricAvailability())
      case "authenticate":
        let arguments = call.arguments as? [String: Any]
        let reason = arguments?["reason"] as? String ?? "使用指纹或人脸完成钱包创建"
        self.authenticateWithBiometrics(reason: reason, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Keep WebRTC's recording unit prepared while a room is receive-only.
  /// This does not enable/publish the microphone or request permission; it
  /// prevents iOS from creating the playout path only after a local mic track
  /// is enabled (the classic "unmuting fixes remote audio" failure).
  private func prepareWebRTCAudioDevice() {
    guard let adm = FlutterWebRTCPlugin.sharedSingleton()?
      .peerConnectionFactory?.audioDeviceModule else {
      NSLog("[AcoAudio] WebRTC audio device module unavailable")
      return
    }
    let status = adm.setRecordingAlwaysPreparedMode(true)
    NSLog("[AcoAudio] recordingAlwaysPreparedMode enabled, status=%ld", status)
  }

  private func liveAudioRouteInfo() -> [String: Any] {
    let session = AVAudioSession.sharedInstance()
    let outputs = session.currentRoute.outputs.map { output in
      [
        "portType": output.portType.rawValue,
        "portName": output.portName,
        "uid": output.uid,
      ]
    }
    let inputs = session.currentRoute.inputs.map { input in
      [
        "portType": input.portType.rawValue,
        "portName": input.portName,
        "uid": input.uid,
      ]
    }
    let info: [String: Any] = [
      "category": session.category.rawValue,
      "mode": session.mode.rawValue,
      "categoryOptions": session.categoryOptions.rawValue,
      "isOtherAudioPlaying": session.isOtherAudioPlaying,
      "outputVolume": session.outputVolume,
      "secondaryAudioShouldBeSilencedHint": session.secondaryAudioShouldBeSilencedHint,
      "outputs": outputs,
      "inputs": inputs,
    ]
    NSLog("[AcoAudio] routeInfo=%@", String(describing: info))
    return info
  }

  private func biometricAvailability() -> String {
    let context = LAContext()
    var error: NSError?
    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
      return "enrolled"
    }
    if error?.code == LAError.biometryNotEnrolled.rawValue {
      return "not_enrolled"
    }
    return "unavailable"
  }

  private func authenticateWithBiometrics(
    reason: String,
    result: @escaping FlutterResult
  ) {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      result(false)
      return
    }
    context.evaluatePolicy(
      .deviceOwnerAuthenticationWithBiometrics,
      localizedReason: reason
    ) { success, _ in
      DispatchQueue.main.async {
        result(success)
      }
    }
  }
}
