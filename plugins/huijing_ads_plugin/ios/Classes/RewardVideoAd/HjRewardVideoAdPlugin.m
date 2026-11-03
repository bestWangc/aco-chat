//
//  HjRewardVideoAdPlugin.m
//  huijing_ads_plugin
//

#import "HjRewardVideoAdPlugin.h"
#import "HuijingAdsPlugin.h"
#import "HjUtil.h"
#import "HjPluginContant.h"
#import <Flutter/Flutter.h>
#import <HJOpenAdSDK/HJAdsOpen.h>
#import <WebKit/WebKit.h>

@interface HjRewardVideoAdPlugin ()<HJRewardAdDelegate>
@property (nonatomic, strong) FlutterMethodChannel *channel;
@property (nonatomic, strong) NSObject<FlutterPluginRegistrar> *registrar;
@property (nonatomic, strong) NSMutableDictionary<NSString *, HjRewardVideoAdPlugin *> *pluginMap;
@property (nonatomic, strong) HJAdsSdkReward *reward;
@property (nonatomic, weak) HjRewardVideoAdPlugin *father;
@property (nonatomic, strong) UIView *adView; // 兼容 WKWebView
@end

@implementation HjRewardVideoAdPlugin

#pragma mark - 注册
+ (void)registerWithRegistrar:(nonnull NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel
                                     methodChannelWithName:@"com.huijingads/reward"
                                     binaryMessenger:[registrar messenger]];
    HjRewardVideoAdPlugin *plugin = [[HjRewardVideoAdPlugin alloc] init];
    plugin.registrar = registrar;
    [registrar addMethodCallDelegate:plugin channel:channel];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _pluginMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel
                        request:(HJAdsRequest *)request {
    self = [super init];
    if (self) {
        _channel = channel;
        _reward = [[HJAdsSdkReward alloc] initWithRequest:request];
        _reward.delegate = self;
    }
    return self;
}

#pragma mark - MethodCall 分发
- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *uniqId = [call.arguments objectForKey:@"uniqId"];
    HjRewardVideoAdPlugin *rewardAd = [self getRewardAdPluginWithUniqId:uniqId arguments:call.arguments];
    NSString *func = [NSString stringWithFormat:@"%@MethodCall:result:", call.method];
    SEL selector = NSSelectorFromString(func);
    BOOL isImplementSel = [rewardAd respondsToSelector:selector];
    if (!isImplementSel) {
        result(FlutterMethodNotImplemented);
    } else {
        ((void (*)(id, SEL, id, id))[rewardAd methodForSelector:selector])(rewardAd, selector, call, result);
    }
}

- (HjRewardVideoAdPlugin *)getRewardAdPluginWithUniqId:(NSString *)uniqId arguments:(NSDictionary *)arguments {
    HjRewardVideoAdPlugin *rewardAd = [self.pluginMap objectForKey:uniqId];
    if (!rewardAd) {
        NSDictionary *reqItem = [arguments objectForKey:@"request"];
        HJAdsRequest *adRequest = [HjUtil getAdRequestWithItem:reqItem];
        if (adRequest.userId == nil || adRequest.userId.length == 0) {
            adRequest.userId = [HuijingAdsPlugin getUserId];
        }
        NSString *channelName = [NSString stringWithFormat:@"com.huijingads/reward.%@", uniqId];
        FlutterMethodChannel *channel = [FlutterMethodChannel
                                         methodChannelWithName:channelName
                                         binaryMessenger:[self.registrar messenger]];
        rewardAd = [[HjRewardVideoAdPlugin alloc] initWithChannel:channel request:adRequest];
        rewardAd.father = self;
        [self.pluginMap setValue:rewardAd forKey:uniqId];
    }
    return rewardAd;
}

#pragma mark - ----- Flutter 方法 -----
- (void)isReadyMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    result(@([self.reward isAdReady]));
}

- (void)loadMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if (!self.reward.isAdReady) {
        [self.reward loadAd];
    } else {
        [self.channel invokeMethod:HuijingEventAdSucceed arguments:@{}];
    }
    result(nil);
}

- (void)showAdMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    UIViewController *rootViewController = [HjUtil getCurrentController];
    NSDictionary *options = [call.arguments objectForKey:@"options"];
    [self.reward show:rootViewController options:options];
    result(nil);
}

- (void)destroyMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *uniqId = [call.arguments objectForKey:@"uniqId"];
    if (uniqId && self.father) {
        [self.father.pluginMap removeObjectForKey:uniqId];
    }
    [self safeDestroy];
    if (result) result(nil);
}

#pragma mark - 统一清理方法
- (void)safeDestroy {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.adView) {
            if ([self.adView isKindOfClass:[WKWebView class]]) {
                WKWebView *webView = (WKWebView *)self.adView;
                [webView stopLoading];
                webView.navigationDelegate = nil;
                webView.UIDelegate = nil;
                [webView.configuration.userContentController removeAllScriptMessageHandlers];
                [webView loadHTMLString:@"" baseURL:nil];
                [webView removeFromSuperview];
            } else {
                [self.adView removeFromSuperview];
            }
            self.adView = nil;
        }

        if (self.reward) {
            self.reward.delegate = nil;
            self.reward = nil;
        }

        NSLog(@"[HjRewardVideoAdPlugin] safeDestroy -> resources released");
    });
}

#pragma mark - HJRewardAdDelegate
-(void) onVideoAdLoadSuccess:(NSString *) placementId {
    [self.channel invokeMethod:HuijingEventAdSucceed arguments:@{}];
}

-(void) onVideoAdLoadError:(NSString *) placementId error:(NSError *)error {
    [self.channel invokeMethod:HuijingEventAdFailed arguments:@{
        @"code": @(error.code),
        @"message": error.localizedDescription ?: @""
    }];
    [self safeDestroy]; // ❗加载失败也清理
}

-(void) onVideoAdPlayStart {
    [self.channel invokeMethod:HuijingEventAdExposure arguments:@{}];
}

-(void) onVideoAdClicked {
    [self.channel invokeMethod:HuijingEventAdClicked arguments:@{}];
}

- (void)rewardVideoAdDidClickSkip {
    [self.channel invokeMethod:HuijingEventAdClose arguments:@{}];
    [self safeDestroy]; // ❗跳过时清理
}

-(void) onVideoRewarded:(NSString *_Nonnull) transId{
    [self.channel invokeMethod:HuijingEventAdReward arguments:@{
          @"trans_id":transId,
          @"isReward":@YES,
          @"errorCode":[NSNull null],
          @"errorMsg":[NSNull null]
    }];
}

-(void) onVideoAdClosed {
    [self.channel invokeMethod:HuijingEventAdClose arguments:@{}];
    [self safeDestroy]; // ❗关闭时清理
}

-(void) onVideoAdPlayEnd {
    [self.channel invokeMethod:HuijingEventAdVideoComplete arguments:@{}];
}

-(void) onVideoAdPlayError:(NSString *) placementId error:(NSError *)error {
    [self.channel invokeMethod:HuijingEventAdFailed arguments:@{
        @"code": @(error.code),
        @"message": error.localizedDescription ?: @""
    }];
    [self safeDestroy]; // ❗播放出错也清理
}

@end
