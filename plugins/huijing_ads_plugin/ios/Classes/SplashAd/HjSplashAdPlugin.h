//
//  HjSplashAdPlugin.h
//  huijing_ads_plugin
//
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

@interface HjSplashAdPlugin : NSObject<FlutterPlugin>


+ (HjSplashAdPlugin *)getPluginWithUniqId:(NSString *)uniqId;

- (void)showAd:(UIView *)adContainer;

@end
