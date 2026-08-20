import 'package:flutter/services.dart';

enum BiometricAvailability { enrolled, notEnrolled, unavailable }

/// Requests device biometrics and exposes whether it is configured.
class BiometricAuthentication {
  const BiometricAuthentication._();

  static const _channel = MethodChannel('aco/biometric-authentication');

  static Future<BiometricAvailability> availability() async {
    try {
      final value = await _channel.invokeMethod<String>('availability');
      return switch (value) {
        'enrolled' => BiometricAvailability.enrolled,
        'not_enrolled' => BiometricAvailability.notEnrolled,
        _ => BiometricAvailability.unavailable,
      };
    } on MissingPluginException {
      return BiometricAvailability.unavailable;
    } on PlatformException {
      return BiometricAvailability.unavailable;
    }
  }

  /// First-time wallet setup treats biometrics as optional.
  static Future<bool> authenticateOrSkip() async {
    if (await availability() != BiometricAvailability.enrolled) return true;
    try {
      return await _channel.invokeMethod<bool>('authenticate') ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }

  /// A transaction must always be verified. Callers should prompt for the
  /// wallet password unless biometrics have already been enrolled.
  static Future<bool> transactionRequiresPassword() async =>
      await availability() != BiometricAvailability.enrolled;
}
