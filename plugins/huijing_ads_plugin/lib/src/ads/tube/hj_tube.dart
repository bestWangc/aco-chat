import 'package:flutter/services.dart';
import 'package:huijing_ads_plugin/huijing_ads_plugin.dart';

class HjTubeInfo {
  Map<String, dynamic>? customData;
}

class HjTubeAd with HjAdEventHandler {
  static const MethodChannel _channel = MethodChannel('com.huijingads/tube');

  late String _uniqId;
  late MethodChannel _adChannel;

  late final HjTubeListener<HjTubeAd> _listener;
  late final Future<int> Function() getRewardAmountFunc;
  late final Future<int> Function() onCollectClickedFunc;

  HjTubeAd({
    required HjTubeListener<HjTubeAd> listener,
  }) : super() {
    _uniqId = "999999";
    _listener = listener;
    delegate = IHjTubeListener(this, _listener);
    _adChannel = MethodChannel('com.huijingads/tube.$_uniqId');
    // _adChannel.setMethodCallHandler(handleEvent);

    // getRewardAmountFunc = getRewardAmount;
    // onCollectClickedFunc = onCollectClicked;
    _adChannel.setMethodCallHandler((call) async {
      try {
        Map<String, dynamic> arguments = {};
        if (call.arguments != null) {
          arguments.addAll(Map<String, dynamic>.from(call.arguments));
        }
        HjError? error;
        if (arguments.containsKey('code')) {
          var errorCode = int.tryParse(arguments['code']) ?? 9999;
          var msg = arguments['message'] as String;
          error = HjError(errorCode, msg);
        }
        switch (call.method) {
          case 'onAdSucceed':
            delegate!.onAdSucceed(arguments);
            break;
          case 'onAdClose':
            delegate!.onAdClose();
            break;
          case 'onIncreaseRewardClicked':
            delegate!.onIncreaseRewardClicked();
            break;
          case 'onIncSmallRewardClicked':
            delegate!.onIncSmallRewardClicked();
            break;
          case 'onIncreaseRewardClosed':
            delegate!.onIncreaseRewardClosed();
            break;
          case 'getRewardAmount':
            // int rewardAmount = await getRewardAmountFunc();
            // Map<String, dynamic> adData = {"rewardAmount": rewardAmount};
            // return adData;
            break;
          case 'onCollectClicked':
            // int amount = await onCollectClickedFunc();
            // Map<String, dynamic> adData = {"amount": amount};
            // return adData;
            break;
        }
      } catch (_) {}
      return null;
    });
  }

  Future<void> loadAd() async {
    await _channel.invokeMethod('load', {"uniqId": _uniqId});
  }

  Future<void> showLoading() async {
    await _channel.invokeMethod('showLoading', {"uniqId": _uniqId});
  }

  Future<void> hideLoading() async {
    await _channel.invokeMethod('hideLoading', {"uniqId": _uniqId});
  }

  Future<void> destroy() async {
    await _channel.invokeMethod('destroy', {"uniqId": _uniqId});
  }
}
