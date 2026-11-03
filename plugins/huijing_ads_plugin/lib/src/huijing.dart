// import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
// import 'package:windmill_ad_plugin/windmill_ad_plugin.dart';

class HjAd {
  static const _channel = MethodChannel('com.huijingads.ad');
  /// 设置自定义 Bid
  static Future<void> setCustomBid(String bundleId) {
    if (Platform.isIOS) {
      return _channel.invokeMethod('setCustomBid', {'bundleId': bundleId});
    } else {
      return Future.value();
    }
  }
  /// 初始化SDK
  static Future<void> init(String appId,
      {String? rewardId,
      String? interstitialId,
      String? fullScreenId,
      String? userId}) {
    return _channel.invokeMethod('init', {
      'appId': appId,
      'rewardId': rewardId,
      'interstitialId': interstitialId,
      'fullScreenId': fullScreenId,
      'userId': userId
    });
  }

  /// 初始化短剧内容SDK
  static Future<void> initContentSdk(
      String contentAppId, String contentPlacementId) {
    return _channel.invokeMethod('initContentSdk', {
      'contentAppId': contentAppId,
      'contentPlacementId': contentPlacementId
    });
  }

  /// 初始化短剧内容SDK(新版)
  static Future<void> initNewContentSdk(String contentAppId) {
    return _channel.invokeMethod('initNewContentSdk', {
      'contentAppId': contentAppId,
    });
  }

  /// 打开短剧页面
  static Future<void> loadTubePage() {
    return _channel.invokeMethod('loadTubePage', {});
  }

  /// 打开短视频页面
  static Future<void> loadContentPage() {
    return _channel.invokeMethod('loadContentPage', {});
  }
}
