//
//  HjPluginContant.h
//  huijing_ads_plugin
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HjPluginContant : NSObject

extern NSString *const kHjBannerAdViewId;
extern NSString *const kHjSplashAdViewId;
extern NSString *const kHjNativeAdViewId;

extern NSString *const HuijingEventAdSucceed;
extern NSString *const HuijingEventAdFailed;
extern NSString *const HuijingEventAdExposure;
extern NSString *const HuijingEventAdClicked;
extern NSString *const HuijingEventAdReward;
extern NSString *const HuijingEventAdClose;
extern NSString *const HuijingEventAdVideoComplete;
extern NSString *const HuijingEventAdAutoRefreshed;
extern NSString *const HuijingEventAdAutoRefreshFail;
extern NSString *const HuijingEventAdRenderSuccess;
extern NSString *const HuijingEventAdRenderFail;
extern NSString *const HuijingEventAdDidDislike;

@end

NS_ASSUME_NONNULL_END
