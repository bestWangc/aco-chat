import 'package:flutter/services.dart';
import 'package:huijing_ads_plugin/huijing_ads_plugin.dart';

class HjInterstitialAd with HjAdEventHandler {
  static const MethodChannel _channel =
      MethodChannel('com.huijingads/interstitial');

  final HjAdRequest request;
  late String _uniqId;
  late MethodChannel _adChannel;

  late final HjInterstitialListener<HjInterstitialAd> _listener;

  HjInterstitialAd({
    required this.request,
    required HjInterstitialListener<HjInterstitialAd> listener,
  }) : super() {
    _uniqId = hashCode.toString();
    _listener = listener;
    delegate = IHjInterstitialListener(this, _listener);
    _adChannel = MethodChannel('com.huijingads/interstitial.$_uniqId');
    _adChannel.setMethodCallHandler(handleEvent);
  }

  Future<bool> isReady() async {
    bool isReady = await _channel.invokeMethod('isReady', {"uniqId": _uniqId});
    return isReady;
  }

  Future<void> loadAdData() async {
    await _channel
        .invokeMethod('load', {"uniqId": _uniqId, 'request': request.toJson()});
  }

  Future<void> showAd({Map<String, String>? options}) async {
    await _channel.invokeMethod('showAd', {
      "uniqId": _uniqId,
      'request': request.toJson(),
      'options': options ?? {}
    });
  }

  Future<void> destroy() async {
    await _channel.invokeMethod('destroy', {"uniqId": _uniqId});
  }
}
