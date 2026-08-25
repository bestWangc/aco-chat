import Flutter
import flutter_webrtc
import LocalAuthentication
import UIKit
import AVFoundation

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
        self.authenticateWithBiometrics(result: result)
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

  private func authenticateWithBiometrics(result: @escaping FlutterResult) {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      result(false)
      return
    }
    context.evaluatePolicy(
      .deviceOwnerAuthenticationWithBiometrics,
      localizedReason: "验证身份以保护你的钱包"
    ) { success, _ in
      DispatchQueue.main.async {
        result(success)
      }
    }
  }
}
