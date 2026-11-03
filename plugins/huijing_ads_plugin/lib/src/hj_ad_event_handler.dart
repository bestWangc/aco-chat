import 'package:flutter/services.dart';
import 'hj_error.dart';

mixin HjAdEvent {
  void onAdSucceed(Map<String, dynamic>? arguments) {}
  void onAdExposure(Map<String, dynamic>? arguments) {}
  void onAdClicked() {}
  void onAdClose() {}
  void onAdFailed(HjError? error) {}
  void onVideoComplete() {}
  void onAdReward(Map<String, dynamic>? arguments) {}
  void onAdAutoRefreshFail(HjError error, Map<String, dynamic>? arguments) {}
  void onAdAutoRefreshed(Map<String, dynamic>? arguments) {}
  void onAdRenderSuccess(Map<String, dynamic>? arguments) {}
  void onAdRenderFail(HjError? error) {}
  void onAdDidDislike(Map<String, dynamic>? arguments) {}
  void onIncreaseRewardClicked() {}
  void onIncSmallRewardClicked() {}
  void onIncreaseRewardClosed() {}
  void onWithdrawClicked() {}
}

mixin HjAdEventHandler {
  late final HjAdEvent? delegate;

  Future<void> handleEvent(MethodCall call) async {
    try {
      if (delegate == null) return;
      Map<String, dynamic> arguments = {};
      if (call.arguments != null) {
        arguments.addAll(Map<String, dynamic>.from(call.arguments));
      }
      HjError? error;
      if (arguments.containsKey('code')) {
        var errorCode =
            int.tryParse(arguments['code']?.toString() ?? '') ?? 9999;
        var msg = arguments['message']?.toString() ?? '';
        error = HjError(errorCode, msg);
      }
      switch (call.method) {
        case 'onAdSucceed':
          delegate!.onAdSucceed(arguments);
          break;
        case 'onAdExposure':
          delegate!.onAdExposure(arguments);
          break;
        case 'onAdClicked':
          delegate!.onAdClicked();
          break;
        case 'onAdClose':
          delegate!.onAdClose();
          break;
        case 'onAdFailed':
          delegate!.onAdFailed(error!);
          break;
        case 'onVideoComplete':
          delegate!.onVideoComplete();
          break;
        case 'onAdReward':
          delegate!.onAdReward(arguments);
          break;
        case 'onAdAutoRefreshed':
          delegate!.onAdAutoRefreshed(arguments);
          break;
        case 'onAdAutoRefreshFail':
          delegate!.onAdAutoRefreshFail(error!, arguments);
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
      }
    } catch (_) {}
  }
}
