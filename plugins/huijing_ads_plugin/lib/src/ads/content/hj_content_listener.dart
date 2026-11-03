import 'package:huijing_ads_plugin/src/ads/content/hj_content.dart';
import 'package:huijing_ads_plugin/src/hj_error.dart';
import 'package:huijing_ads_plugin/src/hj_ad_event_handler.dart';
import 'package:huijing_ads_plugin/src/hj_listener.dart';

abstract class HjContentListener<T> {
  void onAdSucceed(T ad);
  void onIncreaseRewardClicked();
  void onIncSmallRewardClicked();
  void onIncreaseRewardClosed();
  void onWithdrawClicked();
  void onAdClose();
}

class IHjContentListener with HjAdEvent {
  final HjContentAd? hjContentAd;
  final HjContentListener<HjContentAd> listener;

  IHjContentListener(this.hjContentAd, this.listener);

  @override
  void onAdSucceed(Map<String, dynamic>? arguments) {
    listener.onAdSucceed(hjContentAd!);
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
  void onWithdrawClicked() {
    listener.onWithdrawClicked();
  }

  @override
  void onAdClose() {
    listener.onAdClose();
  }
}
