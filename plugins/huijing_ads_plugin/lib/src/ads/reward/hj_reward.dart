import 'package:flutter/services.dart';
import 'package:huijing_ads_plugin/huijing_ads_plugin.dart';

class HjRewardInfo {
  late bool isReward;
  late String transId;
  late String errorCode;
  late String errorMsg;
  HjRewardInfo(this.transId, this.isReward, this.errorCode, this.errorMsg);

  @override
  String toString() {
    return 'HjRewardInfo{isReward: $isReward, transId: $transId， errorCode: $errorCode， errorMsg: $errorMsg}';
  }
}

class HjRewardAd with HjAdEventHandler {
  static const MethodChannel _channel = MethodChannel('com.huijingads/reward');

  final HjAdRequest request;
  late String _uniqId;
  late MethodChannel _adChannel;

  late final HjRewardListener<HjRewardAd> _listener;

  HjRewardAd({
    required this.request,
    required HjRewardListener<HjRewardAd> listener,
  }) : super() {
    _uniqId = hashCode.toString();
    _listener = listener;
    delegate = IHjRewardListener(this, _listener);
    _adChannel = MethodChannel('com.huijingads/reward.$_uniqId');
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
