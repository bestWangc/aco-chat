import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  const AppUpdateService({this._client});

  static const _promptedDateKey = 'app_update.prompted_date';
  final http.Client? _client;

  Future<bool> hasUpdate() async {
    final client = _client ?? http.Client();
    try {
      final uri = Uri.parse('${AppConfig.websiteUrl}/version.json').replace(
        queryParameters: {
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;
      final json = jsonDecode(response.body);
      final latest = json is Map ? json['latest_version']?.toString() : null;
      return latest != null &&
          _compareVersions(latest, AppConfig.appVersion) > 0;
    } on Object {
      return false;
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<bool> shouldPromptToday() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString(_promptedDateKey) == _today) return false;
    await preferences.setString(_promptedDateKey, _today);
    return true;
  }

  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<bool> openWebsite() {
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : defaultTargetPlatform == TargetPlatform.android
        ? 'android'
        : 'other';
    final uri = Uri.parse(
      AppConfig.websiteUrl,
    ).replace(queryParameters: {'platform': platform});
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static int _compareVersions(String a, String b) {
    final left = _parts(a);
    final right = _parts(b);
    for (var i = 0; i < 3; i++) {
      final comparison = left[i].compareTo(right[i]);
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  static List<int> _parts(String value) {
    final parts = value
        .split('+')
        .first
        .split('.')
        .take(3)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    return [...parts, ...List.filled(3 - parts.length, 0)];
  }
}
