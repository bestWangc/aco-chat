import 'dart:ui';
import 'dart:io';

import 'package:huijing_ads_plugin/src/ads/banner/hj_banner.dart';
import 'package:huijing_ads_plugin/src/hj_listener.dart';
import 'package:huijing_ads_plugin/src/hj_ad_event_handler.dart';
import 'package:huijing_ads_plugin/src/hj_error.dart';

abstract class HjBannerListener<T> extends HjListener<T> {
  void onAdAutoRefreshFail(T ad, HjError error);
  void onAdAutoRefreshed(T ad);
}

class IHjBannerListener with HjAdEvent {
  final HjBannerAd? bannerAd;
  final HjBannerListener<HjBannerAd> listener;

  IHjBannerListener(this.bannerAd, this.listener);

  @override
  void onAdSucceed(Map<String, dynamic>? arguments) {
    if (arguments?.containsKey('width') == true) {
      double width = arguments!['width'];
      double height = arguments['height'];

      if (width > 0 && height > 0) {
        var size = Size(width, height);

        if (Platform.isAndroid && width > 0 && height > 0) {
          size = Size(width / window.devicePixelRatio,
              height / window.devicePixelRatio);
        }
        bannerAd?.adSize = size;
      }
    }

    listener.onAdSucceed(bannerAd!);
  }

  @override
  void onAdFailed(HjError? error) {
    listener.onAdFailed(error!);
  }

  @override
  void onAdExposure(Map<String, dynamic>? arguments) {
    listener.onAdExposure();
  }

  @override
  void onAdClicked() {
    listener.onAdClicked();
  }

  @override
  void onAdClose() {
    listener.onAdClose();
  }

  @override
  void onAdAutoRefreshFail(HjError error, Map<String, dynamic>? arguments) {
    listener.onAdAutoRefreshFail(bannerAd!, error);
  }

  @override
  void onAdAutoRefreshed(Map<String, dynamic>? arguments) {
    if (arguments?.containsKey('width') == true) {
      double width = arguments!['width'].toDouble();
      double height = arguments['height'].toDouble();
      var size = Size(width, height);

      if (Platform.isAndroid && width > 0 && height > 0) {
        size = Size(
            width / window.devicePixelRatio, height / window.devicePixelRatio);
      }

      bannerAd?.adSize = size;
    }

    listener.onAdAutoRefreshed(bannerAd!);
  }
}
