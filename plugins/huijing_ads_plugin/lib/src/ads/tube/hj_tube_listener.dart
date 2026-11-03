import 'package:huijing_ads_plugin/src/ads/tube/hj_tube.dart';
import 'package:huijing_ads_plugin/src/hj_error.dart';
import 'package:huijing_ads_plugin/src/hj_ad_event_handler.dart';
import 'package:huijing_ads_plugin/src/hj_listener.dart';

abstract class HjTubeListener<T> {
  void onAdSucceed(T ad);
  void onIncreaseRewardClicked();
  void onIncSmallRewardClicked();
  void onIncreaseRewardClosed();
  void onAdClose();
}

class IHjTubeListener with HjAdEvent {
  final HjTubeAd? hjTubeAd;
  final HjTubeListener<HjTubeAd> listener;

  IHjTubeListener(this.hjTubeAd, this.listener);

  @override
  void onAdSucceed(Map<String, dynamic>? arguments) {
    listener.onAdSucceed(hjTubeAd!);
  }

  @override
  void onIncreaseRewardClicked() {
    listener.onIncreaseRewardClicked();
  }

  @override
  void onIncSmallRewardClicked() {
    listener.onIncSmallRewardClicked();
  }

  @override
  void onIncreaseRewardClosed() {
    listener.onIncreaseRewardClosed();
  }

  @override
  void onAdClose() {
    listener.onAdClose();
  }
}
