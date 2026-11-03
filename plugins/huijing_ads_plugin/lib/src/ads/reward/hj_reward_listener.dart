import 'package:huijing_ads_plugin/src/ads/reward/hj_reward.dart';
import 'package:huijing_ads_plugin/src/hj_error.dart';
import 'package:huijing_ads_plugin/src/hj_ad_event_handler.dart';
import 'package:huijing_ads_plugin/src/hj_listener.dart';

abstract class HjRewardListener<T> extends HjListener<T> {
  void onAdReward(HjRewardInfo hjRewardInfo);
  void onVideoComplete();
}

class IHjRewardListener with HjAdEvent {
  final HjRewardAd? rewardAd;
  final HjRewardListener<HjRewardAd> listener;

  IHjRewardListener(this.rewardAd, this.listener);

  @override
  void onAdSucceed(Map<String, dynamic>? arguments) {
    listener.onAdSucceed(rewardAd!);
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
  void onAdReward(Map<String, dynamic>? arguments) {
    String transId = '';
    String errorCode = '';
    String errorMsg = '';
    bool isReward = false;
    if (arguments != null) {
      if (arguments['trans_id'] != null) {
        transId = arguments['trans_id'] as String;
      }
      if (arguments['errorCode'] is String) {
        errorCode = arguments['errorCode'] as String;
      }
      if (arguments['errorMsg'] is String) {
        errorMsg = arguments['errorMsg'] as String;
      }
      isReward = arguments['isReward'] == true;
    }

    listener.onAdReward(HjRewardInfo(transId, isReward, errorCode, errorMsg));
  }

  @override
  void onVideoComplete() {
    listener.onVideoComplete();
  }
}
