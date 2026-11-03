import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:huijing_ads_plugin/src/ads/native/hj_native.dart';
import 'package:huijing_ads_plugin/src/hj_error.dart';
import 'package:huijing_ads_plugin/src/hj_listener.dart';
import 'package:huijing_ads_plugin/src/hj_ad_event_handler.dart';

abstract class HjNativeListener<T> {
  void onAdSucceed(T ad);
  void onAdFailed(HjError error);
  void onAdExposure();
  // void onAdShowError(HjError error);
  void onAdClicked();
  void onAdRenderSuccess(
      T ad); //原生模板广告渲染成功，此时的ad.size.height根据width 完成了动态更新。（只针对模版渲染）
  void onAdRenderFail(HjError error); //原生模板广告渲染失败（只针对模版渲染）
  void onAdDidDislike(
      String reason); //点击dislike回调，开发者需要在这个回调中移除视图，否则，会出现用户点击叉无效的情况
  // void onAdDetailViewOpened(T ad); //广告详情页面展示回调
  // void onAdDetailViewClosed(T ad); //广告详情页面关闭回调
}

class IHjNativeListener with HjAdEvent {
  final HjNativeAd nativeAd;
  final HjNativeListener<HjNativeAd> listener;
  IHjNativeListener(this.nativeAd, this.listener);

  @override
  void onAdSucceed(Map<String, dynamic>? arguments) {
    listener.onAdSucceed(nativeAd);
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
  void onAdRenderSuccess(Map<String, dynamic>? arguments) {
    if (arguments?.containsKey('width') == true) {
      double width = arguments!['width'].toDouble();
      double height = arguments['height'].toDouble();

      if (width > 0 && height > 0) {
        var size = Size(width, height);
        if (Platform.isAndroid) {
          size = Size(width / window.devicePixelRatio,
              height / window.devicePixelRatio);
        }
        nativeAd.adSize = size;
      }
    }

    listener.onAdRenderSuccess(nativeAd);
  }

  @override
  void onAdRenderFail(HjError? error) {
    listener.onAdRenderFail(error!);
  }

  @override
  void onAdDidDislike(Map<String, dynamic>? arguments) {
    String reason = arguments!['reason'];
    listener.onAdDidDislike(reason);
  }
}
