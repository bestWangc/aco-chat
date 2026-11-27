//
//  LiveTranscodingConfigFactory.m
//  flutter_livepush_plugin
//
//  Created by ISS013602000846 on 2023/5/9.
//

#import "LiveTranscodingConfigFactory.h"
#import "LivePusherTool.h"

@implementation LiveTranscodingConfigFactory

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
    if (self = [super init]) {
        FlutterMethodChannel *commonChannel = [FlutterMethodChannel
                                         methodChannelWithName:LiveTranscodingConfigMethodName
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
    self.config = [[AlivcLiveTranscodingConfig alloc] init];
}

// 混合后画面的底色颜色，默认为黑色，格式为十六进制数字,0xRRGGBB
- (void)setBackgroundColor:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.backgroundColor = value;
    result(nil);
}

- (void)getBackgroundColor:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.backgroundColor];
    result(value);
}

// 混合后视频画面裁剪模式
- (void)setCropMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.cropMode = value;
    result(nil);
}

- (void)getCropMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.cropMode];
    result(value);
}

// 云端混流（转码）中每一路子画面的位置信息
- (void)setMixStreams:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSArray *arrV = arr[2];
    if (arrV && arrV.count > 0) {
        NSMutableArray<AlivcLiveMixStream *> *mixStreams = [NSMutableArray array];
        [arrV enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary *dicV = obj;
            AlivcLiveMixStream *mixStream = [[AlivcLiveMixStream alloc] init];
            mixStream.userId = [dicV objectForKey:@"userId"];
            mixStream.x = [[dicV objectForKey:@"x"] intValue];
            mixStream.y = [[dicV objectForKey:@"y"] intValue];
            mixStream.width = [[dicV objectForKey:@"width"] intValue];
            mixStream.height = [[dicV objectForKey:@"height"] intValue];
            mixStream.zOrder = [[dicV objectForKey:@"zOrder"] intValue];
            [mixStreams addObject:mixStream];
        }];
        self.config.mixStreams = mixStreams;
    }
    result(nil);
}

- (void)getMixStreams:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSMutableArray *mixStreams = @{}.mutableCopy;
    [self.config.mixStreams enumerateObjectsUsingBlock:^(AlivcLiveMixStream * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSMutableDictionary *mixStream = [NSMutableDictionary dictionary];
        [mixStream setObject:obj.userId forKey:@"userId"];
        [mixStream setObject:[NSString stringWithFormat:@"%d", obj.x] forKey:@"x"];
        [mixStream setObject:[NSString stringWithFormat:@"%d", obj.y] forKey:@"y"];
        [mixStream setObject:[NSString stringWithFormat:@"%d", obj.width] forKey:@"width"];
        [mixStream setObject:[NSString stringWithFormat:@"%d", obj.height] forKey:@"height"];
        [mixStream setObject:[NSString stringWithFormat:@"%d", obj.zOrder] forKey:@"zOrder"];
        [mixStreams addObject:mixStream];
    }];
    result(mixStreams);
}

@end
