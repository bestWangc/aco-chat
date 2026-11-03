//
//  HjBannerAdPlugin.m
//  huijing_ads_plugin
//
//

#import "HjBannerAdPlugin.h"
#import "HuijingAdsPlugin.h"
#import "HjUtil.h"
#import "HjPluginContant.h"
#import <Flutter/Flutter.h>
#import <HJOpenAdSDK/HJAdsOpen.h>
#import <WindFoundation/WindFoundation.h>

@interface HjBannerAdPlugin ()<HJBannerViewDelegate>
@property (nonatomic, strong) FlutterMethodChannel *channel;
@property (nonatomic, strong) NSObject<FlutterPluginRegistrar> *registrar;
@property (nonatomic, strong) HJBannerView *bannerView;
@property (nonatomic,weak) UIView *adContainer;

@end

@implementation HjBannerAdPlugin

static NSMutableDictionary<NSString *, HjBannerAdPlugin *> *pluginMap;

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel request:(HJAdsRequest *)request
    arguments:(NSDictionary*)arguments{
    self = [super init];
    if (self) {
    _channel = channel;

    NSNumber *width = [arguments objectForKey:@"width"];
    NSNumber *height = [arguments objectForKey:@"height"];
    if(width != [NSNull null] && height != [NSNull null] && width.doubleValue >0 && height.doubleValue >0){
        _bannerView = [[HJBannerView alloc] initWithRequest:request expectSize:CGSizeMake(width.doubleValue, height.doubleValue)];
    }else{
        _bannerView = [[HJBannerView alloc] initWithRequest:request];
    }
    _bannerView.delegate = self;
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
                                        methodChannelWithName:@"com.huijingads/banner"
                                        binaryMessenger:[registrar messenger]];
    HjBannerAdPlugin *plugin = [[HjBannerAdPlugin alloc] init];
    plugin.registrar = registrar;
    [registrar addMethodCallDelegate:plugin channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *uniqId = [(NSDictionary *)call.arguments objectForKey:@"uniqId"];
    HjBannerAdPlugin *plugin = [self getPluginWithUniqId:uniqId arguments:call.arguments];
    NSString *func = [NSString stringWithFormat:@"%@MethodCall:result:", call.method];
    SEL selector = NSSelectorFromString(func);
    BOOL isImplementSel = NO;
    isImplementSel = [plugin respondsToSelector:selector];
    NSLog(@"banner: %@", self);
    NSLog(@"banner: [isImplementSel = %d, target = %@, func = %@, argus = %@]", isImplementSel, plugin, func, call.arguments);
    if (!isImplementSel) {
        result(FlutterMethodNotImplemented);
    }else {
        ((void (*)(id, SEL, id, id))[plugin methodForSelector:selector])(plugin, selector, call, result);
    }
}

+ (HjBannerAdPlugin *)getPluginWithUniqId:(NSString *)uniqId{
    if(pluginMap != nil){
        return [pluginMap objectForKey:uniqId];
    }
    return nil;
}

- (HjBannerAdPlugin *)getPluginWithUniqId:(NSString *)uniqId arguments:(NSDictionary *)arguments {
    HjBannerAdPlugin *plugin = [pluginMap objectForKey:uniqId];
    if (!plugin) {
        NSDictionary *reqItem = [arguments objectForKey:@"request"];
        HJAdsRequest *adRequest = [HjUtil getAdRequestWithItem:reqItem];
        if(adRequest.userId == nil || adRequest.userId.length==0){
            adRequest.userId = [HuijingAdsPlugin getUserId];
        }
        NSString *channelName = [NSString stringWithFormat:@"com.huijingads/banner.%@", uniqId];
        FlutterMethodChannel *channel = [FlutterMethodChannel
                                            methodChannelWithName:channelName
                                            binaryMessenger:[self.registrar messenger]];
        plugin = [[HjBannerAdPlugin alloc] initWithChannel:channel request:adRequest arguments:arguments];
        if(pluginMap == nil){
            pluginMap = [[NSMutableDictionary alloc] init];
        }
        
        [pluginMap setValue:plugin forKey:uniqId];
    }
    return plugin;
}
#pragma mark - ----- Method -----
- (void)isReadyMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    result(@([self.bannerView isAdValid]));
}
- (void)loadMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {

    UIViewController *rootViewController = [HjUtil getCurrentController];
    BOOL animated = [[(NSDictionary *)call.arguments objectForKey:@"animated"] boolValue];
    _bannerView.animated = animated;
    _bannerView.backgroundColor = UIColor.clearColor;
    _bannerView.viewController = rootViewController;


    [self.bannerView loadAdData];
    
    result(nil);
}

- (void)showAd:(UIView *)adContainer {

    self.adContainer = adContainer;
    CGSize adSize = _bannerView.adSize;
    [self.bannerView.getView sms_remakeConstraints:^(SMSConstraintMaker *make) {
            make.size.sms_equalTo(adSize);
            make.center.sms_equalTo(adContainer);
        }];
    NSLog(@"adContainer bannerView %@", self.bannerView.getView);
    [adContainer addSubview: self.bannerView.getView];
    
}


- (void)destroyMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *uniqId = [(NSDictionary *)call.arguments objectForKey:@"uniqId"];
    if (pluginMap != nil) {
       [pluginMap removeObjectForKey:uniqId];
    }

    result(nil);
}
#pragma mark - ----- HJBannerViewDelegate -----

//bannerView自动刷新
- (void)bannerAdViewDidAutoRefresh:(HJBannerView *)bannerAdView {
    NSLog(@"%@  size: %@", NSStringFromSelector(_cmd), NSStringFromCGSize(bannerAdView.adSize));
    CGSize adSize = bannerAdView.adSize;
    [self.channel invokeMethod:HuijingEventAdAutoRefreshed arguments:@{
        @"width": @(adSize.width),
        @"height": @(adSize.height),
    }];
}
//bannerView自动刷新失败
- (void)bannerViewFailedToAutoRefreshWithError:(NSError *)error {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.channel invokeMethod:HuijingEventAdAutoRefreshFail arguments:@{
        @"code": @(error.code),
        @"message": error.localizedDescription
    }];
}
//成功加载广告
- (void)bannerAdViewLoadSuccess:(HJBannerView *)bannerAdView {
    NSLog(@"%@  size: %@", NSStringFromSelector(_cmd), NSStringFromCGSize(bannerAdView.adSize));

    NSLog(@"%@", NSStringFromSelector(_cmd));
    CGSize adSize = bannerAdView.adSize;
   
    [self.channel invokeMethod:HuijingEventAdSucceed arguments:@{
        @"width": @(adSize.width),
        @"height": @(adSize.height),
    }];
}
//广告加载失败
- (void)bannerAdViewFailedToLoadError:(NSError *)error {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.channel invokeMethod:HuijingEventAdFailed arguments:@{
        @"code": @(error.code),
        @"message": error.localizedDescription
    }];
}
//广告将要展示
- (void)bannerAdViewWillExpose{
    NSLog(@"%@", NSStringFromSelector(_cmd));

    [self.channel invokeMethod:HuijingEventAdExposure arguments:@{}];
}
//广告被点击
- (void)bannerAdViewDidClicked {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.channel invokeMethod:HuijingEventAdClicked arguments:@{}];
}
//当用户由于点击要离开您的应用程序时触发该回调,您的应用程序将移至后台
- (void)bannerAdViewWillLeaveApplication {
    NSLog(@"%@", NSStringFromSelector(_cmd));
}
//将打开全屏视图。在打开storekit或在应用程序中打开网页时触发
- (void)bannerAdViewWillOpenFullScreen {
    NSLog(@"%@", NSStringFromSelector(_cmd));
}
//将关闭全屏视图。关闭storekit或关闭应用程序中的网页时发送
- (void)bannerAdViewCloseFullScreen {
    NSLog(@"%@", NSStringFromSelector(_cmd));
}
//广告视图被移除
- (void)bannerAdViewDidRemoved {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.channel invokeMethod:HuijingEventAdClose arguments:@{}];
}
- (void)dealloc {
    NSLog(@"--- dealloc -- %@", self);
    self.bannerView.delegate = nil;
    self.bannerView = nil;
    self.channel = nil;
}
@end
