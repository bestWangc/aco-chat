//
//  HJNativeAdPlugin.m
//  Pods
//
//  Created by 胡兵 on 2024/6/8.
//

#import "HJNativeAdPlugin.h"
#import "HuijingAdsPlugin.h"
#import "HjUtil.h"
#import "HjPluginContant.h"
#import <Flutter/Flutter.h>
#import <HJOpenAdSDK/HJAdsOpen.h>

@interface HJNativeAdPlugin()<HJNativeAdsManagerDelegate,HJNativeAdViewDelegate>
@property (nonatomic, strong) FlutterMethodChannel *channel;
@property (nonatomic, strong) NSObject<FlutterPluginRegistrar> *registrar;
@property (nonatomic, strong) HJNativeAdsManager *nativeAdManager;
@property (nonatomic, strong) HJNativeAd *nativeAd;
@property (nonatomic, strong) HJNativeAdView *adView;
@property (nonatomic,weak) UIView *adContainer;
@end

@implementation HJNativeAdPlugin

static NSMutableDictionary<NSString *, HJNativeAdPlugin *> *pluginMap;

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel request:(HJAdsRequest *)request {
    self = [super init];
    if (self) {
        
        _channel = channel;
        
        self.nativeAdManager = [[HJNativeAdsManager alloc] initWithRequest:request];
        self.nativeAdManager.delegate = self;
        

    }
    return self;
}
- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
}
+ (void)registerWithRegistrar:(nonnull NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel
                                        methodChannelWithName:@"com.huijingads/native"
                                        binaryMessenger:[registrar messenger]];
    HJNativeAdPlugin *plugin = [[HJNativeAdPlugin alloc] init];
    plugin.registrar = registrar;
    [registrar addMethodCallDelegate:plugin channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *uniqId = [(NSDictionary *)call.arguments objectForKey:@"uniqId"];
    HJNativeAdPlugin *plugin = [self getPluginWithUniqId:uniqId arguments:call.arguments];
    NSString *func = [NSString stringWithFormat:@"%@MethodCall:result:", call.method];
    SEL selector = NSSelectorFromString(func);
    BOOL isImplementSel = NO;
    isImplementSel = [plugin respondsToSelector:selector];
    NSLog(@"native: %@", self);
    NSLog(@"native: [isImplementSel = %d, target = %@, func = %@, argus = %@]", isImplementSel, plugin, func, call.arguments);
    if (!isImplementSel) {
        result(FlutterMethodNotImplemented);
    }else {
        ((void (*)(id, SEL, id, id))[plugin methodForSelector:selector])(plugin, selector, call, result);
    }
}


+ (HJNativeAdPlugin *)getPluginWithUniqId:(NSString *)uniqId{
    if(pluginMap != nil){
        return [pluginMap objectForKey:uniqId];
    }
    return nil;
}

 - (HJNativeAdPlugin *)getPluginWithUniqId:(NSString *)uniqId arguments:(NSDictionary *)arguments {
     HJNativeAdPlugin *plugin = [pluginMap objectForKey:uniqId];
     if (!plugin) {
         NSDictionary *reqItem = [arguments objectForKey:@"request"];
         HJAdsRequest *adRequest = [HjUtil getAdRequestWithItem:reqItem];
         if(adRequest.userId == nil || adRequest.userId.length==0){
             adRequest.userId = [HuijingAdsPlugin getUserId];
         }
         NSString *channelName = [NSString stringWithFormat:@"com.huijingads/native.%@", uniqId];
         FlutterMethodChannel *channel = [FlutterMethodChannel
                                             methodChannelWithName:channelName
                                             binaryMessenger:[self.registrar messenger]];
         plugin = [[HJNativeAdPlugin alloc] initWithChannel:channel request:adRequest];
         if(pluginMap == nil){
             pluginMap = [[NSMutableDictionary alloc] init];
         }
        
         [pluginMap setValue:plugin forKey:uniqId];
     }
     return plugin;
 }
//- (HJNativeAdPlugin *)getPluginWithUniqId:(NSString *)uniqId arguments:(NSDictionary *)arguments {
//    HJNativeAdPlugin *plugin = [pluginMap objectForKey:uniqId];
//    if (!plugin) {
//        NSDictionary *reqItem = [arguments objectForKey:@"request"];
//        HJAdsRequest *adRequest = [HjUtil getAdRequestWithItem:reqItem];
//        
//        // 用户 ID 兜底
//        if (adRequest.userId == nil || adRequest.userId.length == 0) {
//            adRequest.userId = [HuijingAdsPlugin getUserId];
//        }
//        
//        // ✅ 处理自定义 bundleId（Bid）
//        NSString *customBundleId = reqItem[@"bundleId"];
//        if (customBundleId != nil && customBundleId.length > 0) {
//            // 如果 SDK 提供了设置 Bid 的接口，直接调 SDK
//            if ([HJAdsSdk.sharedAds respondsToSelector:@selector(setCustomBid:)]) {
//                [HJAdsSdk.sharedAds performSelector:@selector(setCustomBid:) withObject:customBundleId];
//                NSLog(@"[HuijingAdsPlugin] 已设置自定义 Bid = %@", customBundleId);
//            } else {
//                // 如果 SDK 没有接口，就 fallback 到你之前写的 swizzling
//                [[NSBundle mainBundle] custom_setBundleIdentifier:customBundleId];
//                NSLog(@"[HuijingAdsPlugin] 已通过 swizzling 伪装 BundleID = %@", customBundleId);
//            }
//        }
//        
//        // 创建插件实例
//        NSString *channelName = [NSString stringWithFormat:@"com.huijingads/native.%@", uniqId];
//        FlutterMethodChannel *channel = [FlutterMethodChannel
//                                            methodChannelWithName:channelName
//                                            binaryMessenger:[self.registrar messenger]];
//        plugin = [[HJNativeAdPlugin alloc] initWithChannel:channel request:adRequest];
//        
//        if (pluginMap == nil) {
//            pluginMap = [[NSMutableDictionary alloc] init];
//        }
//        [pluginMap setValue:plugin forKey:uniqId];
//    }
//    return plugin;
//}
#pragma mark - ----- Method -----
- (void)isReadyMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    result(@((bool)(self.nativeAd != nil && self.nativeAd.getAd != nil)));
}
- (void)loadMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    
    NSNumber *width = [(NSDictionary *)call.arguments objectForKey:@"width"];
    NSNumber *height = [(NSDictionary *)call.arguments objectForKey:@"height"];
    if(width != [NSNull null] && height != [NSNull null]){
        self.nativeAdManager.adSize = CGSizeMake(width.doubleValue, height.doubleValue);
    }
    _adView = nil;
    self.nativeAd = nil;
    [self.nativeAdManager loadAdDataWithCount:1];

    result(nil);
}

- (void)destroyMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *uniqId = [(NSDictionary *)call.arguments objectForKey:@"uniqId"];
    if (pluginMap != nil) {
       [pluginMap removeObjectForKey:uniqId];
    }
    [self destroy];
    result(nil);
}

- (HJNativeAdView *)adView {
    if (!_adView) {
        _adView = [HJNativeAdView initAdView];
    }
    return _adView;
}

- (void)showAd:(UIView *)adContainer args:(NSDictionary *)args{
    UIViewController *rootViewController = [HjUtil getCurrentController];
    [adContainer addSubview:self.adView.getView];
    NSLog(@"############ adContainer  %@", adContainer);
    NSLog(@"############ rootViewController  %@", rootViewController);
    self.adView.frame = adContainer.bounds;
    self.adView.delegate = self;
    self.adView.viewController = rootViewController;
    [self.adView refreshData:self.nativeAd];
}

#pragma mark - ----- HJNativeAdsManagerDelegate -----
- (void)nativeAdsManagerSuccessToLoad:(HJNativeAdsManager *)nativeAdsManager {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.channel invokeMethod:HuijingEventAdSucceed arguments:@{}];
    NSArray<HJNativeAd *> *nativeAdList = [self.nativeAdManager getAllNativeAds];
    if (nativeAdList.count == 0) return;
    self.nativeAd = nativeAdList.firstObject;
    NSLog(@"############ nativeAdsManagerSuccessToLoad  %@", self.nativeAd.getAd);
}

- (void)nativeAdsManagerdidFailWithError:(NSError *)error {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.channel invokeMethod:HuijingEventAdFailed arguments:@{
        @"code": @(error.code),
        @"message": error.localizedDescription
    }];
}

#pragma mark - ----- HJNativeAdViewDelegate -----
- (void)nativeExpressAdViewRenderSuccess:(HJNativeAdView *)nativeExpressAdView{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    CGSize adSize = nativeExpressAdView.frame.size;
    
    self.adView.frame = CGRectMake(self.adView.frame.origin.x, self.adView.frame.origin.y, adSize.width, adSize.height);
    [self.channel invokeMethod:HuijingEventAdRenderSuccess arguments:@{
        @"width": @(adSize.width),
        @"height": @(adSize.height),
    }];
}

- (void)nativeExpressAdViewRenderFail:(NSError *)error {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.channel invokeMethod:HuijingEventAdRenderFail arguments:@{
        @"code": @(error.code),
        @"message": error.localizedDescription
    }];
}
- (void)nativeAdViewWillExpose{
    NSLog(@"%@", NSStringFromSelector(_cmd));

    [self.channel invokeMethod:HuijingEventAdExposure arguments:@{}];
}

- (void)nativeAdViewDidClick{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.channel invokeMethod:HuijingEventAdClicked arguments:@{}];
}

- (void)dislikeWithReason:(NSString *) reason {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.channel invokeMethod:HuijingEventAdDidDislike arguments:@{
        @"reason":reason
    }];
}

- (void) destroy {
    if(self.nativeAdManager != nil){
        self.nativeAdManager.delegate = nil;
    }
    self.nativeAdManager = nil;
    self.nativeAd = nil;
    _adView = nil;
    self.channel = nil;
}
- (void)dealloc {
    NSLog(@"--- dealloc -- %@", self);
 
    [self destroy];
}
@end
