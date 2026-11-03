import 'package:huijing_ads_plugin/src/ads/interstitial/hj_interstitial.dart';
import 'package:huijing_ads_plugin/src/hj_error.dart';
import 'package:huijing_ads_plugin/src/hj_ad_event_handler.dart';
import 'package:huijing_ads_plugin/src/hj_listener.dart';

abstract class HjInterstitialListener<T> extends HjListener<T> {}

class IHjInterstitialListener with HjAdEvent {
  final HjInterstitialAd? interstitialAd;
  final HjInterstitialListener<HjInterstitialAd> listener;

  IHjInterstitialListener(this.interstitialAd, this.listener);

  @override
  void onAdSucceed(Map<String, dynamic>? arguments) {
    listener.onAdSucceed(interstitialAd!);
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
}
