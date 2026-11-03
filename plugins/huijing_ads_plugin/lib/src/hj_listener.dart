import 'hj_error.dart';

abstract class HjListener<T> {
  void onAdSucceed(T ad);
  void onAdExposure();
  void onAdClicked();
  void onAdClose();
  void onAdFailed(HjError error);
}
