//
//  HjBannerAdPlugin.h
//  huijing_ads_plugin
//
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

@interface HjBannerAdPlugin : NSObject<FlutterPlugin>
+ (HjBannerAdPlugin *)getPluginWithUniqId:(NSString *)uniqId;

- (void)showAd:(UIView *)adContainer;
@end

