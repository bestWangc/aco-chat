import 'package:flutter/services.dart';

/// Requests device biometrics when they are available and configured.
///
/// Unsupported devices and devices without enrolled biometrics are allowed to
/// continue. A user-cancelled prompt returns `false` so they can try again.
class BiometricAuthentication {
  const BiometricAuthentication._();

  static const _channel = MethodChannel('aco/biometric-authentication');

  static Future<bool> authenticateOrSkip() async {
    try {
      return await _channel.invokeMethod<bool>('authenticate') ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }
}
