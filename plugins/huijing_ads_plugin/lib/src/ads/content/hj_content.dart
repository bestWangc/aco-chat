import 'package:flutter/services.dart';
import 'package:huijing_ads_plugin/huijing_ads_plugin.dart';

class HjContentInfo {
  Map<String, dynamic>? customData;
}

class HjContentAd with HjAdEventHandler {
  static const MethodChannel _channel = MethodChannel('com.huijingads/content');

  late String _uniqId;
  late MethodChannel _adChannel;

  late final HjContentListener<HjContentAd> _listener;
  late final Future<int> Function() getRewardAmountFunc;
  late final Future<int> Function() getTotalAmountFunc;
  late final Future<int> Function() onCollectClickedFunc;

  HjContentAd({
    // required Future<int> Function() getRewardAmount,
    // required Future<int> Function() getTotalAmount,
    // required Future<int> Function() onCollectClicked,
    required HjContentListener<HjContentAd> listener,
  }) : super() {
    _uniqId = "888888";
    _listener = listener;
    delegate = IHjContentListener(this, _listener);
    _adChannel = MethodChannel('com.huijingads/content.$_uniqId');
    // _adChannel.setMethodCallHandler(handleEvent);

    // getRewardAmountFunc = getRewardAmount;
    // getTotalAmountFunc = getTotalAmount;
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
          case 'onWithdrawClicked':
            delegate!.onWithdrawClicked();
            break;
          case 'getRewardAmount':
            // int rewardAmount = await getRewardAmountFunc();
            // Map<String, dynamic> adData = {"rewardAmount": rewardAmount};
            // return adData;
            break;
          case 'getTotalAmount':
            // int totalAmount = await getTotalAmountFunc();
            // Map<String, dynamic> adData = {"totalAmount": totalAmount};
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
