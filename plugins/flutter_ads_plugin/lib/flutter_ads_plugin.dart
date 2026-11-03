import 'dart:collection';

import 'package:flutter/services.dart';

typedef onSplashAdSuccessPresent = void Function();
typedef onSplashAdSuccessLoad = void Function(String placementId);
typedef onSplashAdFailToLoad =
    void Function(String code, String msg, String placementId);
typedef onSplashAdClicked = void Function();
typedef onSplashClosed = void Function();

typedef onInterstitialAdLoadSuccess = void Function(String placementId);
typedef onInterstitialAdPlayStart = void Function();
typedef onInterstitialAdPlayEnd = void Function();
typedef onInterstitialAdClicked = void Function();
typedef onInterstitialAdClosed = void Function();
typedef onInterstitialAdLoadError =
    void Function(String code, String msg, String placementId);
typedef onInterstitialAdPlayError =
    void Function(String code, String msg, String placementId);

typedef onVideoAdLoadSuccess = void Function(String placementId);
typedef onVideoAdPlayEnd = void Function();
typedef onVideoAdPlayStart = void Function();
typedef onVideoAdClicked = void Function();
typedef onVideoRewarded = void Function(String transId);
typedef onVideoAdClosed = void Function();
typedef onVideoAdLoadError =
    void Function(String code, String msg, String placementId);
typedef onVideoAdPlayError =
    void Function(String code, String msg, String placementId);

class FlutterAdsPlugin {
  final MethodChannel methodChannel = const MethodChannel(
    'flutter_ads_plugin/method',
  );
  final EventChannel events_SplashAd = const EventChannel(
    "flutter_ads_plugin/events_SplashAd",
  );
  final EventChannel events_InterstitialAd = const EventChannel(
    "flutter_ads_plugin/events_InterstitialAd",
  );
  final EventChannel events_RewardAd = const EventChannel(
    "flutter_ads_plugin/events_RewardAd",
  );

  @override
  void logd(String msg) {
    methodChannel.invokeMethod<String>('log', {"msg": msg});
  }

  @override
  void initAd(String initId, int isPersonalizedAdvertisingOn) {
    methodChannel.invokeMethod<String>('init', {
      "initId": initId,
      "isPersonalizedAdvertisingOn": isPersonalizedAdvertisingOn
    });
  }

  @override
  void initAd2(String initId, int isPersonalizedAdvertisingOn, String csjAppId, String djxJsonName) {
    methodChannel.invokeMethod<String>('init2', {
      "initId": initId,
      "isPersonalizedAdvertisingOn": isPersonalizedAdvertisingOn,
      "csjAppId": csjAppId,
      "djxJsonName": djxJsonName
    });
  }

  @override
  void loadSplash(
    String codeId, {
    onSplashAdSuccessPresent? onSplashAdSuccessPresent,
    onSplashAdSuccessLoad? onSplashAdSuccessLoad,
    onSplashAdFailToLoad? onSplashAdFailToLoad,
    onSplashAdClicked? onSplashAdClicked,
    onSplashClosed? onSplashClosed,
  }) {
    events_SplashAd.receiveBroadcastStream().listen((event) {
      switch (event["event"]) {
        case "onSplashAdSuccessPresent": //开屏广告成功展示，媒体可在此记录曝光。
          onSplashAdSuccessPresent?.call();
          break;
        case "onSplashAdSuccessLoad": //开屏广告成功加载。参数说明：placementId（报错的广告位Id）。
          String placementId = event["placementId"];
          onSplashAdSuccessLoad?.call(placementId);
          break;
        case "onSplashAdFailToLoad": //开屏广告加载失败。参数说明：error（报错信息，具体可看其内部code和message）、placementId（报错的广告位Id）。
          String code = event["code"];
          String msg = event["msg"];
          String placementId = event["placementId"];
          onSplashAdFailToLoad?.call(code, msg, placementId);
          break;
        case "onSplashAdClicked": //开屏广告被点击。
          onSplashAdClicked?.call();
          break;
        case "onSplashClosed": //开屏广告关闭。
          onSplashClosed?.call();
          break;
      }
    });
    methodChannel.invokeMethod<String>('loadSplash', {"codeId": codeId});
  }

  @override
  void showSplash() {
    methodChannel.invokeMethod<String>('showSplash');
  }

  @override
  void destroySplash() {
    methodChannel.invokeMethod<String>('destroySplash');
  }

  @override
  void loadAndShowSplash(
    String codeId, {
    onSplashAdSuccessPresent? onSplashAdSuccessPresent,
    onSplashAdSuccessLoad? onSplashAdSuccessLoad,
    onSplashAdFailToLoad? onSplashAdFailToLoad,
    onSplashAdClicked? onSplashAdClicked,
    onSplashClosed? onSplashClosed,
  }) {
    events_SplashAd.receiveBroadcastStream().listen((event) {
      switch (event["event"]) {
        case "onSplashAdSuccessPresent": //开屏广告成功展示，媒体可在此记录曝光。
          onSplashAdSuccessPresent?.call();
          break;
        case "onSplashAdSuccessLoad": //开屏广告成功加载。参数说明：placementId（报错的广告位Id）。
          String placementId = event["placementId"];
          onSplashAdSuccessLoad?.call(placementId);
          break;
        case "onSplashAdFailToLoad": //开屏广告加载失败。参数说明：error（报错信息，具体可看其内部code和message）、placementId（报错的广告位Id）。
          String code = event["code"];
          String msg = event["msg"];
          String placementId = event["placementId"];
          onSplashAdFailToLoad?.call(code, msg, placementId);
          break;
        case "onSplashAdClicked": //开屏广告被点击。
          onSplashAdClicked?.call();
          break;
        case "onSplashClosed": //开屏广告关闭。
          onSplashClosed?.call();
          break;
      }
    });
    methodChannel.invokeMethod<String>('loadAndShowSplash', {"codeId": codeId});
  }

  @override
  void loadInterstitial(
    String codeId, {
    onInterstitialAdLoadSuccess? onInterstitialAdLoadSuccess,
    onInterstitialAdPlayStart? onInterstitialAdPlayStart,
    onInterstitialAdPlayEnd? onInterstitialAdPlayEnd,
    onInterstitialAdClicked? onInterstitialAdClicked,
    onInterstitialAdClosed? onInterstitialAdClosed,
    onInterstitialAdLoadError? onInterstitialAdLoadError,
    onInterstitialAdPlayError? onInterstitialAdPlayError,
  }) {
    events_InterstitialAd.receiveBroadcastStream().listen((event) {
      switch (event["event"]) {
        case "onInterstitialAdLoadSuccess": //广告成功加载。参数说明：placementId（广告位Id）。
          String placementId = event["placementId"];
          onInterstitialAdLoadSuccess?.call(placementId);
          break;
        case "onInterstitialAdPlayStart": //广告成功展示，媒体可在此记录曝光。参数说明：adInfo（广告信息，具体可看其内部成员变量）。
          onInterstitialAdPlayStart?.call();
          break;
        case "onInterstitialAdPlayEnd": //广告播放结束。
          onInterstitialAdPlayEnd?.call();
          break;
        case "onInterstitialAdClicked": //广告被点击。
          onInterstitialAdClicked?.call();
          break;
        case "onInterstitialAdClosed": //广告关闭。
          onInterstitialAdClosed?.call();
          break;
        case "onInterstitialAdLoadError": //广告加载失败。参数说明：error（报错信息，具体可看其内部code和message）、placementId（报错的广告位Id）。
          String code = event["code"];
          String msg = event["msg"];
          String placementId = event["placementId"];
          onInterstitialAdLoadError?.call(code, msg, placementId);
          break;
        case "onInterstitialAdPlayError": //广告播放出错。参数说明：error（报错信息，具体可看其内部code和message）、placementId（报错的广告位Id）。
          String code = event["code"];
          String msg = event["msg"];
          String placementId = event["placementId"];
          onInterstitialAdPlayError?.call(code, msg, placementId);
          break;
      }
    });
    methodChannel.invokeMethod<String>('loadInterstitial', {"codeId": codeId});
  }

  @override
  void showInterstitial() {
    methodChannel.invokeMethod<String>('showInterstitial');
  }

  @override
  void destroyInterstitial() {
    methodChannel.invokeMethod<String>('destroyInterstitial');
  }

  @override
  void loadReward(
    String codeId,
    String userId,
    Map option, {
    onVideoAdLoadSuccess? onVideoAdLoadSuccess,
    onVideoAdPlayEnd? onVideoAdPlayEnd,
    onVideoAdPlayStart? onVideoAdPlayStart,
    onVideoAdClicked? onVideoAdClicked,
    onVideoRewarded? onVideoRewarded,
    onVideoAdClosed? onVideoAdClosed,
    onVideoAdLoadError? onVideoAdLoadError,
    onVideoAdPlayError? onVideoAdPlayError,
  }) {
    events_RewardAd.receiveBroadcastStream().listen((event) {
      switch (event["event"]) {
        case "onVideoAdLoadSuccess": //广告成功加载。参数说明：placementId（广告位Id）。
          String placementId = event["placementId"];
          onVideoAdLoadSuccess?.call(placementId);
          break;
        case "onVideoAdPlayEnd": //广告播放结束。
          onVideoAdPlayEnd?.call();
          break;
        case "onVideoAdPlayStart": //广告成功展示，媒体可在此记录曝光。
          onVideoAdPlayStart?.call();
          break;
        case "onVideoAdClicked": //广告被点击。
          onVideoAdClicked?.call();
          break;
        case "onVideoRewarded": //广告获取奖励。参数说明： transId（标识本次广告播放行为的唯一id）、RewardVerify：奖励对象
          String transId = event["transId"];
          onVideoRewarded?.call(transId);
          break;
        case "onVideoAdClosed": //广告关闭。
          onVideoAdClosed?.call();
          break;
        case "onVideoAdLoadError": //广告加载失败。参数说明：error（报错信息，具体可看其内部code和message）、placementId（报错的广告位Id）。
          String code = event["code"];
          String msg = event["msg"];
          String placementId = event["placementId"];
          onVideoAdLoadError?.call(code, msg, placementId);
          break;
        case "onVideoAdPlayError": //广告播放出错。参数说明：error（报错信息，具体可看其内部code和message）、placementId（报错的广告位Id）。
          String code = event["code"];
          String msg = event["msg"];
          String placementId = event["placementId"];
          onVideoAdPlayError?.call(code, msg, placementId);
          break;
      }
    });
    methodChannel.invokeMethod<String>('loadReward', {
      "codeId": codeId,
      "userId": userId,
      "option": option,
    });
  }

  @override
  void showReward(Map option) {
    methodChannel.invokeMethod<String>('showReward', {"option": option});
  }

  @override
  void destroyReward() {
    methodChannel.invokeMethod<String>('destroyReward');
  }

  //dramaUnlockAdMode  0:自定义的激励视频  1:短剧内置的默认激励视频
  //csjFreeSet  短剧免费集数
  //csjLockSet  短剧解锁集数
  //rewardVideoId  自定义的激励视频广告位id
  //userId  自定义的激励视频广告用户ID
  @override
  void openDJX(
    int dramaUnlockAdMode,
    int csjFreeSet,
    int csjLockSet,
    String rewardVideoId,
    String userId,
  ) {
    methodChannel.invokeMethod<String>('openDJX', {
      "dramaUnlockAdMode": dramaUnlockAdMode,
      "csjFreeSet": csjFreeSet,
      "csjLockSet": csjLockSet,
      "rewardVideoId": rewardVideoId,
      "userId": userId,
    });
  }
}
