#import "LivePushPlugin.h"
#import "LiveBaseFactory.h"
#import "LivePusherFactory.h"
#import "LivePusherTool.h"

#if __has_include("LivePlayerFactory.h")
#import "LivePlayerFactory.h"
#define LIVEPLAYERFACTORY_ENABLE
#endif

@implementation LivePushPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    LivePusherFactory *livePusherFactory = [[LivePusherFactory alloc] initWithMessenger:registrar.messenger];
    [registrar registerViewFactory:livePusherFactory withId:LivePusherPreviewName];
    
    [LiveBaseFactory registerWithRegistrar:registrar];
    
#ifdef LIVEPLAYERFACTORY_ENABLE
    LivePlayerFactory *livePlayerFactory = [[LivePlayerFactory alloc] initWithMessenger:registrar.messenger];
    [registrar registerViewFactory:livePlayerFactory withId:LivePlayerViewName];
#endif
}

@end
