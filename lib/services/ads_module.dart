import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:aco_chat/features/account/data/account_token_store.dart';
import 'package:flutter/services.dart';
import 'package:huijing_ads_plugin/huijing_ads_plugin.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Native ads exposed to configured DApps in the in-app webview.
class AdsModule {
  AdsModule._();

  static final instance = AdsModule._();
  static final _httpClient = http.Client();
  static final _secureRandom = Random.secure();
  static Future<String>? _applicationId;
  static const _configCacheDuration = Duration(minutes: 1);
  static const _methodChannel = MethodChannel('flutter_ads_plugin/method');
  static const _interstitialEvents = EventChannel(
    'flutter_ads_plugin/events_InterstitialAd',
  );
  static const _rewardEvents = EventChannel(
    'flutter_ads_plugin/events_RewardAd',
  );

  final _configCache = <String, _CachedAdsConfig>{};
  final _preparations = <String, Future<_DappAdsConfig?>>{};
  Future<bool>? _initialization;
  String? _initializedAppId;
  String? _activeAd;

  Future<void> prepare(String dappId) async {
    try {
      await _prepare(dappId);
    } on Object {
      // The ad request retries preparation and reports the failure.
    }
  }

  Future<Map<String, Object?>> showInterstitial(
    String dappId, {
    String? walletAddress,
  }) => _showAd(dappId, _DappAdType.interstitial, walletAddress: walletAddress);

  Future<Map<String, Object?>> showRewarded(
    String dappId, {
    String? walletAddress,
  }) => _showAd(dappId, _DappAdType.rewarded, walletAddress: walletAddress);

  Future<Map<String, Object?>> _showAd(
    String dappId,
    _DappAdType type, {
    String? walletAddress,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return _failure('unsupported_platform');
    }
    if (_activeAd != null) return _failure('busy');
    _activeAd = type.name;
    _DappAdViewTracker? viewTracker;

    try {
      _DappAdsConfig? config;
      try {
        config = await _prepare(dappId);
      } on _AdsInitializationException {
        return _failure('initialization_failed');
      } on Object {
        return _failure('config_unavailable');
      }
      if (config == null) return _failure('not_configured');
      final placementId = type == _DappAdType.interstitial
          ? config.placement.interstitialId
          : config.placement.rewardedId;
      if (placementId == null) return _failure('not_configured');
      viewTracker = _DappAdViewTracker(
        onQualified: () => unawaited(
          _reportAdView(
            dappId: dappId,
            walletAddress: walletAddress,
            type: type,
            placementId: placementId,
          ),
        ),
      );
      if (type == _DappAdType.interstitial) {
        if (Platform.isIOS) {
          return await _showHuijingInterstitial(
            config.placement,
            placementId,
            walletAddress,
            viewTracker,
          );
        }
        return await _showAndroidInterstitial(
          placementId,
          walletAddress,
          viewTracker,
        );
      }
      if (Platform.isIOS) {
        return await _showHuijingRewarded(
          config.placement,
          placementId,
          walletAddress,
          viewTracker,
        );
      }
      return await _showAndroidRewarded(
        config.placement,
        placementId,
        walletAddress,
        viewTracker,
      );
    } on Object {
      return _failure('sdk_error');
    } finally {
      viewTracker?.dispose();
      _activeAd = null;
    }
  }

  Future<Map<String, Object?>> _showAndroidInterstitial(
    String placementId,
    String? walletAddress,
    _DappAdViewTracker viewTracker,
  ) {
    var showRequested = false;
    var shown = false;
    return _runAndroidAd(
      eventChannel: _interstitialEvents,
      loadMethod: 'loadInterstitial',
      loadArguments: {'codeId': placementId, 'userId': walletAddress ?? ''},
      destroyMethod: 'destroyInterstitial',
      timeout: const Duration(seconds: 90),
      onEvent: (data, result) {
        switch (data?['event']) {
          case 'onInterstitialAdLoadSuccess':
            if (showRequested) return;
            showRequested = true;
            unawaited(
              _invoke('showInterstitial').catchError((Object _) {
                _completeWithFailure(result, 'sdk_error');
              }),
            );
            break;
          case 'onInterstitialAdPlayStart':
            shown = true;
            viewTracker.onExposure();
            break;
          case 'onInterstitialAdClosed':
            viewTracker.onClosed();
            if (!result.isCompleted) {
              result.complete({'ok': true, 'shown': shown});
            }
            break;
          case 'onInterstitialAdLoadError' || 'onInterstitialAdPlayError':
            if (!result.isCompleted) result.complete(_eventFailure(data));
            break;
        }
      },
    );
  }

  Future<Map<String, Object?>> _showAndroidRewarded(
    _DappAdPlacement placement,
    String placementId,
    String? walletAddress,
    _DappAdViewTracker viewTracker,
  ) {
    var showRequested = false;
    String? transactionId;
    var rewarded = false;
    return _runAndroidAd(
      eventChannel: _rewardEvents,
      loadMethod: 'loadReward',
      loadArguments: {
        'codeId': placementId,
        'userId': walletAddress ?? '',
        'option': placement.rewardOptions,
      },
      destroyMethod: 'destroyReward',
      timeout: const Duration(minutes: 3),
      onEvent: (data, result) {
        switch (data?['event']) {
          case 'onVideoAdLoadSuccess':
            if (showRequested) return;
            showRequested = true;
            unawaited(
              _invoke('showReward', {
                'option': placement.rewardOptions,
              }).catchError((Object _) {
                _completeWithFailure(result, 'sdk_error');
              }),
            );
            break;
          case 'onVideoAdPlayStart':
            viewTracker.onExposure();
            break;
          case 'onVideoRewarded':
            transactionId = data?['transId']?.toString();
            rewarded = data?['isReward'] == true;
            break;
          case 'onVideoAdClosed':
            viewTracker.onClosed();
            if (!result.isCompleted) {
              result.complete({
                'ok': true,
                'rewarded': rewarded && transactionId != null,
                'transactionId': transactionId,
              });
            }
            break;
          case 'onVideoAdLoadError' || 'onVideoAdPlayError':
            if (!result.isCompleted) result.complete(_eventFailure(data));
            break;
        }
      },
    );
  }

  Future<Map<String, Object?>> _runAndroidAd({
    required EventChannel eventChannel,
    required String loadMethod,
    required Map<String, Object?> loadArguments,
    required String destroyMethod,
    required Duration timeout,
    required _AdEventHandler onEvent,
  }) async {
    final result = Completer<Map<String, Object?>>();
    final subscription = eventChannel.receiveBroadcastStream().listen(
      (event) => onEvent(_eventMap(event), result),
      onError: (Object _) => _completeWithFailure(result, 'sdk_error'),
      onDone: () => _completeWithFailure(result, 'stream_closed'),
    );
    try {
      await _invoke(loadMethod, loadArguments);
      return await result.future.timeout(
        timeout,
        onTimeout: () => _failure('timeout'),
      );
    } on Object {
      return _failure('sdk_error');
    } finally {
      await subscription.cancel();
      await _destroy(destroyMethod);
    }
  }

  Future<Map<String, Object?>> _showHuijingInterstitial(
    _DappAdPlacement placement,
    String placementId,
    String? walletAddress,
    _DappAdViewTracker viewTracker,
  ) async {
    final result = Completer<Map<String, Object?>>();
    var showRequested = false;
    var shown = false;
    final options = <String, String>{
      'AD_SCENE_ID': 'dapp',
      'AD_SCENE_DESC': 'DApp interstitial',
      ...placement.iosInterstitialOptions,
    };
    final ad = HjInterstitialAd(
      request: HjAdRequest(
        placementId: placementId,
        userId: walletAddress,
        options: options,
      ),
      listener: _HuijingInterstitialListener(
        onLoaded: (ad) {
          if (showRequested) return;
          showRequested = true;
          unawaited(
            ad.showAd(options: options).catchError((Object _) {
              if (!result.isCompleted) result.complete(_failure('sdk_error'));
            }),
          );
        },
        onExposure: () {
          shown = true;
          viewTracker.onExposure();
        },
        onClosed: () {
          viewTracker.onClosed();
          if (!result.isCompleted) {
            result.complete({'ok': true, 'shown': shown});
          }
        },
        onFailed: (error) {
          if (!result.isCompleted) result.complete(_huijingFailure(error));
        },
      ),
    );
    return _waitForHuijingAd(
      result: result,
      load: ad.loadAdData,
      destroy: ad.destroy,
      timeout: const Duration(seconds: 90),
    );
  }

  Future<Map<String, Object?>> _showHuijingRewarded(
    _DappAdPlacement placement,
    String placementId,
    String? walletAddress,
    _DappAdViewTracker viewTracker,
  ) async {
    final result = Completer<Map<String, Object?>>();
    var showRequested = false;
    var rewarded = false;
    String? transactionId;
    final ad = HjRewardAd(
      request: HjAdRequest(
        placementId: placementId,
        userId: walletAddress,
        options: placement.iosRewardOptions,
      ),
      listener: _HuijingRewardListener(
        onLoaded: (ad) {
          if (showRequested) return;
          showRequested = true;
          unawaited(
            ad.showAd(options: placement.iosRewardOptions).catchError((
              Object _,
            ) {
              if (!result.isCompleted) {
                result.complete(_failure('sdk_error'));
              }
            }),
          );
        },
        onExposure: viewTracker.onExposure,
        onReward: (reward) {
          rewarded = reward.isReward;
          if (reward.transId.isNotEmpty) transactionId = reward.transId;
        },
        onClosed: () {
          viewTracker.onClosed();
          if (!result.isCompleted) {
            result.complete({
              'ok': true,
              'rewarded': rewarded,
              'transactionId': transactionId,
            });
          }
        },
        onFailed: (error) {
          if (!result.isCompleted) result.complete(_huijingFailure(error));
        },
      ),
    );
    return _waitForHuijingAd(
      result: result,
      load: ad.loadAdData,
      destroy: ad.destroy,
      timeout: const Duration(minutes: 3),
    );
  }

  Future<void> _reportAdView({
    required String dappId,
    required String? walletAddress,
    required _DappAdType type,
    required String placementId,
  }) async {
    final normalizedWalletAddress = walletAddress?.trim();
    if (normalizedWalletAddress == null || normalizedWalletAddress.isEmpty) {
      return;
    }

    try {
      final tokenStore = SecureAccountTokenStore();
      final tokens = await tokenStore.read();
      if (tokens == null || tokens.accessToken.isEmpty) return;

      final platform = Platform.isIOS ? 'ios' : 'android';
      final applicationId = await (_applicationId ??= PackageInfo.fromPlatform()
          .then((info) => info.packageName));
      final base = const AppConfig().apiBaseUrl.replaceFirst(
        RegExp(r'/+$'),
        '',
      );
      final eventId = base64Url
          .encode(List<int>.generate(16, (_) => _secureRandom.nextInt(256)))
          .replaceAll('=', '');
      final body = jsonEncode({
        'eventId': eventId,
        'platform': platform,
        'applicationId': applicationId,
        'dappId': dappId,
        'walletAddress': normalizedWalletAddress,
        'adType': type.name,
        'placementId': placementId,
        'viewedSeconds': 5,
      });
      final uri = Uri.parse('$base/ads/impressions');
      var accessToken = tokens.accessToken;

      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final response = await _httpClient
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $accessToken',
                  'x-app-version': AppConfig.appVersion,
                },
                body: body,
              )
              .timeout(const Duration(seconds: 8));
          if (response.statusCode >= 200 && response.statusCode < 300) return;
          if (response.statusCode == 401 && attempt == 0) {
            final refreshed = await AccountApiClient(
              httpClient: _httpClient,
            ).refreshAccessToken(tokens.refreshToken);
            await tokenStore.write(refreshed.tokens);
            accessToken = refreshed.tokens.accessToken;
            continue;
          }
          if (response.statusCode < 500) return;
        } on Object {
          if (attempt == 1) return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } on Object {
      // Ad reporting must not interrupt playback or affect the DApp flow.
    }
  }

  Future<Map<String, Object?>> _waitForHuijingAd({
    required Completer<Map<String, Object?>> result,
    required Future<void> Function() load,
    required Future<void> Function() destroy,
    required Duration timeout,
  }) async {
    try {
      await load();
      return await result.future.timeout(
        timeout,
        onTimeout: () => _failure('timeout'),
      );
    } on Object {
      return _failure('sdk_error');
    } finally {
      await _quietly(destroy);
    }
  }

  Future<bool> _ensureInitialized(String appId) {
    if (_initializedAppId == appId) return Future.value(true);
    final pending = _initialization;
    if (pending != null) return pending;
    final initialization = _initialize(appId);
    _initialization = initialization;
    return initialization;
  }

  Future<bool> _initialize(String appId) async {
    try {
      final initialization = Platform.isIOS
          ? HjAd.init(appId)
          : _invoke('init', {
              'initId': appId,
              'isPersonalizedAdvertisingOn': 0,
            });
      await initialization.timeout(const Duration(seconds: 30));
      _initializedAppId = appId;
      _initialization = null;
      return true;
    } on Object {
      _initialization = null;
      return false;
    }
  }

  static Future<void> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) => _methodChannel.invokeMethod<void>(method, arguments);

  static Future<void> _destroy(String method) =>
      _quietly(() => _invoke(method));

  static Future<void> _quietly(Future<void> Function() dispose) async {
    try {
      await dispose();
    } on Object {
      // The ad may already have been destroyed by the SDK after an error.
    }
  }

  static void _completeWithFailure(
    Completer<Map<String, Object?>> result,
    String code,
  ) {
    if (!result.isCompleted) result.complete(_failure(code));
  }

  static Map<String, Object?> _failure(String code) => {
    'ok': false,
    'code': code,
  };

  static Map<String, Object?> _huijingFailure(HjError error) => {
    'ok': false,
    'code': error.code.toString(),
    'message': error.message,
  };

  static Map<Object?, Object?>? _eventMap(Object? event) =>
      event is Map ? event : null;

  static Map<String, Object?> _eventFailure(Map<Object?, Object?>? event) => {
    'ok': false,
    'code': event?['code']?.toString() ?? 'ad_error',
    if (event?['msg'] != null) 'message': event!['msg'].toString(),
    if (event?['placementId'] != null)
      'placementId': event!['placementId'].toString(),
  };

  Future<_DappAdsConfig?> _loadConfig(String dappId) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    final cacheKey = '$platform:$dappId';
    final cached = _configCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _configCacheDuration) {
      return cached.config;
    }

    final base = const AppConfig().apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final applicationId = await (_applicationId ??= PackageInfo.fromPlatform()
        .then((info) => info.packageName));
    final uri = Uri.parse('$base/ads/config').replace(
      queryParameters: {
        'platform': platform,
        'application_id': applicationId,
        'dapp_id': dappId,
      },
    );
    final response = await _httpClient
        .get(uri, headers: {'x-app-version': AppConfig.appVersion})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('ads config request failed');
    }

    final body = jsonDecode(response.body);
    if (body is! Map || body['data'] is! Map) {
      throw const FormatException('invalid ads config response');
    }
    final data = body['data'] as Map;
    if (data['enabled'] != true) {
      _configCache[cacheKey] = _CachedAdsConfig(DateTime.now(), null);
      return null;
    }

    final appId = data['appId']?.toString().trim() ?? '';
    final rawPlacement = data['placement'];
    if (appId.isEmpty || rawPlacement is! Map) {
      throw const FormatException('invalid ads config');
    }
    final interstitialId =
        _nonEmpty(rawPlacement['fullScreenInterstitial']?.toString().trim()) ??
        _nonEmpty(rawPlacement['interstitial']?.toString().trim());
    final rewardedId = _nonEmpty(rawPlacement['rewarded']?.toString().trim());
    if (interstitialId == null && rewardedId == null) {
      _configCache[cacheKey] = _CachedAdsConfig(DateTime.now(), null);
      return null;
    }

    final config = _DappAdsConfig(
      appId: appId,
      placement: _DappAdPlacement(
        interstitialId: interstitialId,
        rewardedId: rewardedId,
        rewardOptions: _objectMap(rawPlacement['rewardOptions']),
        iosRewardOptions: platform == 'ios'
            ? _stringMap(rawPlacement['rewardOptions'])
            : const {},
        iosInterstitialOptions: _stringMap(rawPlacement['interstitialOptions']),
      ),
    );
    _configCache[cacheKey] = _CachedAdsConfig(DateTime.now(), config);
    return config;
  }

  Future<_DappAdsConfig?> _prepare(String dappId) {
    final platform = Platform.isIOS ? 'ios' : 'android';
    final key = '$platform:$dappId';
    final pending = _preparations[key];
    if (pending != null) return pending;

    late final Future<_DappAdsConfig?> preparation;
    preparation = (() async {
      final config = await _loadConfig(dappId);
      if (config != null && !await _ensureInitialized(config.appId)) {
        throw const _AdsInitializationException();
      }
      return config;
    })();
    _preparations[key] = preparation;
    unawaited(
      preparation.then<void>(
        (_) {
          if (identical(_preparations[key], preparation)) {
            _preparations.remove(key);
          }
        },
        onError: (Object _, StackTrace __) {
          if (identical(_preparations[key], preparation)) {
            _preparations.remove(key);
          }
        },
      ),
    );
    return preparation;
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;

  static Map<String, Object?> _objectMap(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        entry.key.toString(): entry.value.toString(),
    };
  }
}

typedef _AdEventHandler =
    void Function(
      Map<Object?, Object?>? data,
      Completer<Map<String, Object?>> result,
    );

enum _DappAdType { interstitial, rewarded }

class _CachedAdsConfig {
  const _CachedAdsConfig(this.fetchedAt, this.config);

  final DateTime fetchedAt;
  final _DappAdsConfig? config;
}

class _AdsInitializationException implements Exception {
  const _AdsInitializationException();
}

class _DappAdsConfig {
  const _DappAdsConfig({required this.appId, required this.placement});

  final String appId;
  final _DappAdPlacement placement;
}

class _DappAdPlacement {
  const _DappAdPlacement({
    required this.interstitialId,
    required this.rewardedId,
    required this.rewardOptions,
    required this.iosRewardOptions,
    required this.iosInterstitialOptions,
  });

  final String? interstitialId;
  final String? rewardedId;
  final Map<String, Object?> rewardOptions;
  final Map<String, String> iosRewardOptions;
  final Map<String, String> iosInterstitialOptions;
}

class _HuijingInterstitialListener
    extends HjInterstitialListener<HjInterstitialAd> {
  _HuijingInterstitialListener({
    required this.onLoaded,
    required this.onExposure,
    required this.onClosed,
    required this.onFailed,
  });

  final void Function(HjInterstitialAd ad) onLoaded;
  final void Function() onExposure;
  final void Function() onClosed;
  final void Function(HjError error) onFailed;

  @override
  void onAdSucceed(HjInterstitialAd ad) => onLoaded(ad);

  @override
  void onAdExposure() => onExposure();

  @override
  void onAdClicked() {}

  @override
  void onAdClose() => onClosed();

  @override
  void onAdFailed(HjError error) => onFailed(error);
}

class _HuijingRewardListener extends HjRewardListener<HjRewardAd> {
  _HuijingRewardListener({
    required this.onLoaded,
    required this.onExposure,
    required this.onReward,
    required this.onClosed,
    required this.onFailed,
  });

  final void Function(HjRewardAd ad) onLoaded;
  final void Function() onExposure;
  final void Function(HjRewardInfo reward) onReward;
  final void Function() onClosed;
  final void Function(HjError error) onFailed;

  @override
  void onAdSucceed(HjRewardAd ad) => onLoaded(ad);

  @override
  void onAdExposure() => onExposure();

  @override
  void onAdClicked() {}

  @override
  void onAdClose() => onClosed();

  @override
  void onAdFailed(HjError error) => onFailed(error);

  @override
  void onAdReward(HjRewardInfo hjRewardInfo) => onReward(hjRewardInfo);

  @override
  void onVideoComplete() {}
}

class _DappAdViewTracker {
  _DappAdViewTracker({required this.onQualified});

  final void Function() onQualified;
  final Stopwatch _elapsed = Stopwatch();
  Timer? _timer;
  bool _closed = false;
  bool _qualified = false;

  void onExposure() {
    if (_elapsed.isRunning || _closed) return;
    _elapsed.start();
    _timer = Timer(const Duration(seconds: 5), () {
      if (!_closed) _qualify();
    });
  }

  void onClosed() {
    _closed = true;
    _timer?.cancel();
    if (_elapsed.elapsed >= const Duration(seconds: 5)) _qualify();
  }

  void dispose() {
    _closed = true;
    _timer?.cancel();
  }

  void _qualify() {
    if (_qualified) return;
    _qualified = true;
    onQualified();
  }
}
