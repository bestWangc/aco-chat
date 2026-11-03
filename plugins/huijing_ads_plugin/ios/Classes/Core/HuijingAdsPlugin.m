#import "HuijingAdsPlugin.h"
#import <HJOpenAdSDK/HJAdsOpen.h>
#import "HjBannerViewFactory.h"
#import "HJNativeViewFactory.h"

#import "HjPluginContant.h"
#import "HJNativeAdPlugin.h"
#import "HjIntersititialAdPlugin.h"
#import "HjBannerAdPlugin.h"
#import "HjRewardVideoAdPlugin.h"
#import "HjSplashAdPlugin.h"
#import "HjUtil.h"
#import "NSBundle+CustomBundleID.h"
@implementation HuijingAdsPlugin

static NSString *userId;
NSMutableArray * sdkConfigures;

+(NSString *)getUserId{
    return userId;
}

+(void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    NSLog(@"---- registerWithRegistrar ---- ");
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"com.huijingads.ad"
                                     binaryMessenger:[registrar messenger]];
    HuijingAdsPlugin* instance = [[HuijingAdsPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    // 注册BannerAdView 工厂
    HjBannerViewFactory *bannerFactory = [[HjBannerViewFactory alloc]
                                                initWithMessenger:[registrar messenger]];
    [registrar registerViewFactory:bannerFactory withId:kHjBannerAdViewId];
    
    HJNativeViewFactory *nativeFactory = [[HJNativeViewFactory alloc] initWithMessenger:[registrar messenger]];
    [registrar registerViewFactory:nativeFactory withId:kHjNativeAdViewId];

    [HjIntersititialAdPlugin registerWithRegistrar:registrar];
    [HjRewardVideoAdPlugin registerWithRegistrar:registrar];
    [HjBannerAdPlugin registerWithRegistrar:registrar];
    [HjSplashAdPlugin registerWithRegistrar:registrar];
    [HJNativeAdPlugin registerWithRegistrar:registrar];
    
}
#pragma mark - 自定义 Bid
- (void)setCustomBidMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *bundleId = call.arguments[@"bundleId"];
    if (bundleId != nil && bundleId.length > 0) {
        if ([[HJAdsSdk sharedAds] respondsToSelector:@selector(setCustomBid:)]) {
            // ✅ SDK 本身支持自定义 Bid
            [[HJAdsSdk sharedAds] performSelector:@selector(setCustomBid:) withObject:bundleId];
            NSLog(@"[HuijingAdsPlugin] 使用 SDK setCustomBid = %@", bundleId);
        } else {
            // ⚠️ SDK 没有这个接口 → fallback 到 NSBundle swizzling
            [[NSBundle mainBundle] custom_setBundleIdentifier:bundleId];
            NSLog(@"[HuijingAdsPlugin] 使用 swizzling 修改 bundleId = %@", bundleId);
        }
        result(nil);
    } else {
        result([FlutterError errorWithCode:@"INVALID_ARG"
                                   message:@"bundleId is nil"
                                   details:nil]);
    }
}
- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *func = [NSString stringWithFormat:@"%@MethodCall:result:", call.method];
    SEL selector = NSSelectorFromString(func);
    BOOL isImplementSel = NO;
    id target = self;
    [HJAdsSdk sharedAds];

    isImplementSel = [target respondsToSelector:selector];
    NSLog(@"plugin: [isImplementSel = %d, target = %@, func = %@, argus = %@]", isImplementSel, target, func, call.arguments);
    if (!isImplementSel) {
        result(FlutterMethodNotImplemented);
    }else {
        ((void (*)(id, SEL, id, id))[target methodForSelector:selector])(target, selector, call, result);
    }
}


- (void)setPresetLocalStrategyPathMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *bundleName = call.arguments[@"path"];
    
    if(bundleName != nil){
        
        NSBundle * bundle = nil;
        if( [bundleName isEqualToString: @"mainbundle"]){
            bundle = [NSBundle mainBundle];
        }else{
            NSString * bundlePath = [[NSBundle mainBundle] pathForResource:bundleName ofType:@"bundle"];
           
            if([[NSFileManager defaultManager] fileExistsAtPath:bundlePath]){
                bundle = [NSBundle bundleWithPath:bundlePath];
            }else{
                NSLog(@"error: bundle %@ not exist",bundleName);
            }
        }
        
        if(bundle != nil){
            NSLog(@"setPresetPlacementConfigPathBundle bundle: %@ sccess",bundleName);
        }
    }

    result(nil);
}

/*
 * 获取sdk的版本号
 */
- (void)initMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *appId = call.arguments[@"appId"];
    NSString *rewardId = call.arguments[@"rewardId"];
    NSString *interstitialId = call.arguments[@"interstitialId"];
    NSString *fullScreenId = call.arguments[@"fullScreenId"];
    NSLog(@"---- rewardId: %@", rewardId);
//    NSLog(@"---- interstitialId: %@", interstitialId);
//    NSLog(@"---- fullScreenId: %@", fullScreenId);
    HJAdsSdk* hjAdsSdk = [HJAdsSdk sharedAds];
    [hjAdsSdk setDebugEnable:false];
    [hjAdsSdk setupSDKWithAppId:appId];
    result(nil);
}

@end
