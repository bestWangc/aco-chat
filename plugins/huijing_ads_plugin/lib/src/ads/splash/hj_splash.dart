import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:huijing_ads_plugin/huijing_ads_plugin.dart';

class HjSplashAd with HjAdEventHandler {
  static const MethodChannel _channel = MethodChannel('com.huijingads/splash');

  static const double APP_BOTTOM_HEIGHT = 100.0;

  final double width; //广告宽度
  final double height; //广告高度，设置为0表示根据width自适应，通过adSize.height获取自适应后的高度
  late final Size? adSize; // 广告渲染成功后，返回广实际大小
  late final ValueNotifier<Size> sizeNotify;

  final HjAdRequest request;
  late String _uniqId;
  String? title;
  String? desc;

  late MethodChannel _adChannel;
  late final HjSplashListener<HjSplashAd> _listener;
  HjSplashAd(
      {Key? key,
      required this.request,
      required this.width,
      required this.height,
      this.title,
      this.desc,
      required HjSplashListener<HjSplashAd> listener})
      : super() {
    _uniqId = hashCode.toString();
    _listener = listener;
    delegate = IHjSplashListener(this, _listener);
    _adChannel = MethodChannel('com.huijingads/splash.$_uniqId');
    _adChannel.setMethodCallHandler(handleEvent);
  }

  void updateAdSize(Size size) {
    adSize = size;
  }

  Size? getAdSize() {
    return adSize;
  }

  Future<bool> isReady() async {
    bool isReady = await _channel.invokeMethod('isReady', {"uniqId": _uniqId});
    return isReady;
  }

  Future<void> loadAd() async {
    var optHeight = height;
    if (Platform.isIOS && title != null) {
      optHeight -= APP_BOTTOM_HEIGHT;
    }
    await _channel.invokeMethod('load', {
      "uniqId": _uniqId,
      "width": width,
      "height": optHeight,
      "title": title,
      "desc": desc,
      'request': request.toJson()
    });
  }

  Future<void> showAd() async {
    await _channel.invokeMethod('showAd', {
      "uniqId": _uniqId,
    });
  }

  Future<void> destroy() async {
    await _channel.invokeMethod('destroy', {"uniqId": _uniqId});
  }
}
