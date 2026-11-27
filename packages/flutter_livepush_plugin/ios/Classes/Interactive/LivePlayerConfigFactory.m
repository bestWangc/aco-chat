//
//  LivePlayerConfigFactory.m
//  flutter_livepushInteractive_plugin
//
//  Created by ISS013602000846 on 2023/4/28.
//

#import "LivePlayerConfigFactory.h"
#import "LivePusherTool.h"

@interface LivePlayerConfigFactory ()

@end

@implementation LivePlayerConfigFactory

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
    if (self = [super init]) {
        FlutterMethodChannel *commonChannel = [FlutterMethodChannel
                                         methodChannelWithName:LivePlayerConfigMethodName
                                         binaryMessenger:messenger];
        __weak typeof(self) weakSelf = self;
        [commonChannel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
            __strong typeof(self) strongSelf = weakSelf;
            [LivePusherTool interfaceClass:strongSelf handleMethodCall:call result:result];
        }];
        
        [self createConfig];
    }
    return self;
}

// 创建config
- (void)createConfig {
    self.config = [[AlivcLivePlayConfig alloc] init];
}

// 渲染模式
- (void)setRenderMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.renderMode = value;
    result(nil);
}

- (void)getRenderMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.renderMode];
    result(value);
}

// 播放是否镜像
- (void)setMirror:(NSArray *)arr {
    FlutterResult result = arr[1];
    BOOL value = [arr[2] boolValue];
    self.config.mirror = value;
    result(nil);
}

- (void)getMirror:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.mirror];
    result(value);
}

// 旋转角度
- (void)setRotationMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.rotationMode = value;
    result(nil);
}

- (void)getRotationMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.rotationMode];
    result(value);
}

@end
