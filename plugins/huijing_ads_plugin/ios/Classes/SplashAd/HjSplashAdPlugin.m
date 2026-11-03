//
//  HjSplashAdPlugin.m
//  huijing_ads_plugin
//
//

#import "HjSplashAdPlugin.h"
#import "HuijingAdsPlugin.h"
#import "HjUtil.h"
#import "HjPluginContant.h"
#import <Flutter/Flutter.h>
#import <HJOpenAdSDK/HJAdsOpen.h>


@interface HjSplashAdPlugin ()<HJSplashAdDelegate>
@property (nonatomic, strong) HJAdsSdkSplash *splashView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) FlutterMethodChannel *channel;
@property (nonatomic, strong) NSObject<FlutterPluginRegistrar> *registrar;
@property (nonatomic, strong) HJAdsRequest *request;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *desc;
@property (nonatomic,strong) UIWindow *splashWindow;
@property (nonatomic,strong) UIViewController *splashVC;
@property (nonatomic,strong) UIView *bottomView;
@end

@implementation HjSplashAdPlugin

static NSMutableDictionary<NSString *, HjSplashAdPlugin *> *pluginMap;

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel request:(HJAdsRequest *)request {
    self = [super init];
    if (self) {
        _channel = channel;
        _request = request;
        
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
                                     methodChannelWithName:@"com.huijingads/splash"
                                     binaryMessenger:[registrar messenger]];
    HjSplashAdPlugin *plugin = [[HjSplashAdPlugin alloc] init];
    plugin.registrar = registrar;
    [registrar addMethodCallDelegate:plugin channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *uniqId = [(NSDictionary *)call.arguments objectForKey:@"uniqId"];
    HjSplashAdPlugin *plugin = [self getPluginWithUniqId:uniqId arguments:call.arguments];
    NSString *func = [NSString stringWithFormat:@"%@MethodCall:result:", call.method];
    SEL selector = NSSelectorFromString(func);
    BOOL isImplementSel = NO;
    isImplementSel = [plugin respondsToSelector:selector];
    NSLog(@"splash: %@", self);
    NSLog(@"splash: [isImplementSel = %d, target = %@, func = %@, argus = %@]", isImplementSel, plugin, func, call.arguments);
    if (!isImplementSel) {
        result(FlutterMethodNotImplemented);
    }else {
        ((void (*)(id, SEL, id, id))[plugin methodForSelector:selector])(plugin, selector, call, result);
    }
}


+ (HjSplashAdPlugin *)getPluginWithUniqId:(NSString *)uniqId{
    if(pluginMap != nil){
        return [pluginMap objectForKey:uniqId];
    }
    return nil;
}

- (HjSplashAdPlugin *)getPluginWithUniqId:(NSString *)uniqId arguments:(NSDictionary *)arguments {
    HjSplashAdPlugin *plugin = [pluginMap objectForKey:uniqId];
    if (!plugin) {
        NSDictionary *reqItem = [arguments objectForKey:@"request"];
        WindMillAdRequest *adRequest = [HjUtil getAdRequestWithItem:reqItem];
        if(adRequest.userId == nil || adRequest.userId.length==0){
            adRequest.userId = [HuijingAdsPlugin getUserId];
        }
        NSString *channelName = [NSString stringWithFormat:@"com.huijingads/splash.%@", uniqId];
        FlutterMethodChannel *channel = [FlutterMethodChannel
                                         methodChannelWithName:channelName
                                         binaryMessenger:[self.registrar messenger]];
        plugin = [[HjSplashAdPlugin alloc] initWithChannel:channel request:adRequest];
        if(pluginMap == nil){
            pluginMap = [[NSMutableDictionary alloc] init];
        }
        
        [pluginMap setValue:plugin forKey:uniqId];
    }
    return plugin;
}


#pragma mark - ----- Method -----
- (void)isReadyMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    result(@([self.splashView isAdReady]));
}
- (void)loadMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    
    NSNumber *width = [(NSDictionary *)call.arguments objectForKey:@"width"];
    NSNumber *height= [(NSDictionary *)call.arguments objectForKey:@"height"];
    CGSize size = CGSizeMake(width.doubleValue, height.doubleValue);
    NSObject *object = [(NSDictionary *)call.arguments objectForKey:@"title"];
    if(object != [NSNull null]){
        _title = object;
    }
    
    object = [(NSDictionary *)call.arguments objectForKey:@"desc"];
    
    if(object != [NSNull null]){
        _desc = object;
    }
    
    
    
    
    NSDictionary *extra = @{kWindMillSplashExtraAdSize:NSStringFromCGSize(size)};
//    if(_title != nil && _title.length>0){
//        _bottomView =  [self getLogoViewWithTitle:_title description:_desc];
//    }
    _splashView = [[HJAdsSdkSplash alloc] initWithRequest:self.request];
    _splashView.delegate = self;
    _splashVC = [[UIViewController alloc] init];
    _splashView.rootViewController = _splashVC;
    [self.splashView loadAd];
    result(nil);
}

- (void)showAdMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    
    _splashWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    _splashWindow.rootViewController = _splashVC;
    [_splashWindow makeKeyAndVisible];
    
    [_splashView showAdInWindow:_splashWindow];
    
    result(nil);
    
}

- (void)destroyMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *uniqId = [(NSDictionary *)call.arguments objectForKey:@"uniqId"];
    [pluginMap removeObjectForKey:uniqId];
    result(nil);
}



#pragma mark - HJSplashAdDelegate

//成功加载广告
- (void)onSplashAdSuccessLoad:(NSString *) placementId{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.channel invokeMethod:HuijingEventAdSucceed arguments:nil];
}
//广告加载失败
-(void) onSplashAdFailToLoad:(NSString *) placementId error:(NSError *)error {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.channel invokeMethod:HuijingEventAdFailed arguments:@{
        @"code": @(error.code),
        @"message": error.localizedDescription
    }];
}
//广告将要展示
-(void) onSplashAdSuccessPresent {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.channel invokeMethod:HuijingEventAdExposure arguments:@{}];
}


//广告被点击
- (void)onSplashAdClicked {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.channel invokeMethod:HuijingEventAdClicked arguments:@{}];
}

- (void)onSplashAdSkiped {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.channel invokeMethod:HuijingEventAdClose arguments:@{}];
}


////根据宽度求高度  content 计算的内容  width 计算的宽度 font字体大小
//- (CGSize)getLabelSizeWithText:(NSString *)text width:(CGFloat)width font: (UIFont *)font {
//    CGRect rect = [text boundingRectWithSize:CGSizeMake(width, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:font} context:nil];
//    return rect.size;
//}
//
//- (UIView *)getLogoViewWithTitle:(NSString *)title description:(NSString *)description {
//    UIView *bottomView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(UIScreen.mainScreen.bounds), 100)];
//    bottomView.backgroundColor = [UIColor whiteColor];
//    
//    UIView *backView = [[UIView alloc] init];
//    backView.backgroundColor = [UIColor clearColor];
//    [bottomView addSubview:backView];
//    
//    //icon
//    UIImageView *iconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
//    [iconImgView.layer setMasksToBounds:YES];
//    [iconImgView.layer setCornerRadius:10];
//    NSDictionary *infoPlist = [[NSBundle mainBundle] infoDictionary];
//    NSString *icon = [[infoPlist valueForKeyPath:@"CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconFiles"] lastObject];
//    UIImage* image = [UIImage imageNamed:icon];
//    iconImgView.image = image;
//    
//    //标题
//    UILabel *titleLabel = [[UILabel alloc] init];
//    titleLabel.textAlignment = NSTextAlignmentCenter;
//    titleLabel.text = title;
//    UIFont *titleFont = [UIFont fontWithName:@"Helvetica-Bold" size:25];
//    titleLabel.font = titleFont;
//    titleLabel.textColor = [UIColor blackColor];
//    
//    //描述
//    UILabel *descLabel = [[UILabel alloc] init];
//    descLabel.textAlignment = NSTextAlignmentCenter;
//    descLabel.text = description;
//    UIFont *descFont = [UIFont fontWithName:@"Helvetica" size:12];
//    descLabel.font = descFont;
//    descLabel.textColor = [UIColor grayColor];
//    
//    [backView addSubview:iconImgView];
//    [backView addSubview:titleLabel];
//    [backView addSubview:descLabel];
//    
//    CGSize titleSize = [self getLabelSizeWithText:title width:200 font:titleFont];
//    CGSize descSize = [self getLabelSizeWithText:description width:200 font:descFont];
//    float wid = MAX(titleSize.width, descSize.width);
//    wid = MIN(wid, 180);
//    
//    [backView sms_remakeConstraints:^(SMSConstraintMaker *make) {
//        make.width.sms_equalTo(@(wid+60));
//        make.height.sms_equalTo(bottomView);
//        make.centerY.sms_equalTo(bottomView);
//        make.centerX.sms_equalTo(bottomView);
//    }];
//    [iconImgView sms_remakeConstraints:^(SMSConstraintMaker *make) {
//        make.left.sms_equalTo(backView).offset(0);
//        make.width.sms_equalTo(@60);
//        make.height.sms_equalTo(@60);
//        make.centerY.sms_equalTo(backView).offset(0);
//    }];
//    [titleLabel sms_remakeConstraints:^(SMSConstraintMaker *make) {
//        make.left.sms_equalTo(iconImgView.sms_right).offset(10);
//        make.top.sms_equalTo(iconImgView).offset(0);
//        make.height.sms_equalTo(iconImgView.sms_height).multipliedBy(0.6);
//        make.width.sms_equalTo(@(wid));
//    }];
//    [descLabel sms_remakeConstraints:^(SMSConstraintMaker *make) {
//        make.left.sms_equalTo(iconImgView.sms_right).offset(10);
//        make.bottom.sms_equalTo(iconImgView).offset(0);
//        make.height.sms_equalTo(iconImgView.sms_height).multipliedBy(0.4);
//        make.width.sms_equalTo(@(wid));
//    }];
//    return bottomView;
//}

- (void)onSplashAdClosed {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    if(_splashVC != nil){
        _splashVC = nil;
    }
    
    if(_splashWindow != nil){
        [_splashWindow resignKeyWindow];
        _splashWindow = nil;
    }
    [self.channel invokeMethod:HuijingEventAdClose arguments:@{}];
}

- (void)onSplashZoomOutViewAdDidClick:(WindMillSplashAd *)splashAd {
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)onSplashZoomOutViewAdDidClose:(WindMillSplashAd *)splashAd {
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)dealloc {
    NSLog(@"--- dealloc -- %@", self);
    self.splashView.delegate = nil;
    self.splashVC = nil;
    self.splashWindow = nil;
    self.splashView = nil;
    self.channel = nil;
}
@end
