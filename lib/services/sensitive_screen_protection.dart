import 'package:flutter/services.dart';

/// Enables platform protections while a recovery phrase is visible.
class SensitiveScreenProtection {
  const SensitiveScreenProtection._();

  static const _channel = MethodChannel('aco/sensitive-screen');

  static Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
    } on MissingPluginException {
      // Web and unsupported platforms do not expose a secure-window API.
    }
  }
}
