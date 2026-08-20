import Flutter
import LocalAuthentication
import UIKit

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
