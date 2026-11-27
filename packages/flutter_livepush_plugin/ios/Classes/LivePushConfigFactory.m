//
//  LivePushConfigFactory.m
//  livepush
//
//  Created by ISS013602000846 on 2023/2/20.
//

#import "LivePushConfigFactory.h"
#import "LivePusherTool.h"

@interface LivePushConfigFactory ()

@property (nonatomic, strong) FlutterMethodChannel *commonChannel;
@property (nonatomic, strong) NSObject<FlutterBinaryMessenger> *messenger;

@end

@implementation LivePushConfigFactory

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
    if (self = [super init]) {
        _messenger = messenger;
        _commonChannel = [FlutterMethodChannel
                                         methodChannelWithName:LivePusherConfigMethodName
                                         binaryMessenger:messenger];
        __weak typeof(self) weakSelf = self;
        [_commonChannel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
            __strong typeof(self) strongSelf = weakSelf;
            [LivePusherTool interfaceClass:strongSelf handleMethodCall:call result:result];
        }];
        
        [self createConfig];
    }
    return self;
}

// 创建config
- (void)createConfig {
    self.config = [[AlivcLivePushConfig alloc] init];
    self.config.businessInfo = @{@"traceId": @"fluttersdk"};
}

// 直播SDK推流模式
- (void)setLivePushMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.livePushMode = value;
    result(nil);
}

- (void)getLivePushMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.livePushMode];
    result(value);
}

// 分辨率
- (void)setResolution:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.resolution = value;
    result(nil);
}

- (void)getResolution:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.resolution];
    result(value);
}

// 码率自适应
- (void)setEnableAutoBitrate:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool value = [arr[2] boolValue];
    self.config.enableAutoBitrate = value;
    result(nil);
}

- (void)getEnableAutoBitrate:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.enableAutoBitrate];
    result(value);
}

// 分辨率自适应
- (void)setEnableAutoResolution:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool value = [arr[2] boolValue];
    self.config.enableAutoResolution = value;
    result(nil);
}

- (void)getEnableAutoResolution:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.enableAutoResolution];
    result(value);
}

// 推流模式
- (void)setQualityMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.qualityMode = value;
    result(nil);
}

- (void)getQualityMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.qualityMode];
    result(value);
}

// 目标视频编码码率
- (void)setTargetVideoBitrate:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.targetVideoBitrate = value;
    result(nil);
}

- (void)getTargetVideoBitrate:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.targetVideoBitrate];
    result(value);
}

// 最小视频编码码率
- (void)setMinVideoBitrate:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.minVideoBitrate = value;
    result(nil);
}

- (void)getMinVideoBitrate:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.minVideoBitrate];
    result(value);
}

// 初始视频编码码率
- (void)setInitialVideoBitrate:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.initialVideoBitrate = value;
    result(nil);
}

- (void)getInitialVideoBitrate:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.initialVideoBitrate];
    result(value);
}

// 音频编码码率
- (void)setAudioBitrate:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.audioBitrate = value;
    result(nil);
}

- (void)getAudioBitrate:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.audioBitrate];
    result(value);
}

// 音频采样率
- (void)setAudioSampleRate:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.audioSampleRate = value;
    result(nil);
}

- (void)getAudioSampleRate:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.audioSampleRate];
    result(value);
}

// 视频采集帧率
- (void)setFps:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.fps = value;
    result(nil);
}

- (void)getFps:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.fps];
    result(value);
}

// 最小视频采集帧率
- (void)setMinFps:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.minFps = value;
    result(nil);
}

- (void)getMinFPS:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.minFps];
    result(value);
}

// 关键帧间隔
- (void)setVideoEncodeGop:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.videoEncodeGop = value;
    result(nil);
}

- (void)getVideoEncodeGop:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.videoEncodeGop];
    result(value);
}

// 音频编码格式
- (void)setAudioEncoderProfile:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.audioEncoderProfile = value;
    result(nil);
}

- (void)getAudioEncoderProfile:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.audioEncoderProfile];
    result(value);
}

// 声道数
- (void)setAudioChannel:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.audioChannel = value;
    result(nil);
}

- (void)getAudioChannel:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.audioChannel];
    result(value);
}

// 纯音频推流
- (void)setAudioOnly:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool value = [arr[2] boolValue];
    self.config.audioOnly = value;
    result(nil);
}

- (void)getAudioOnly:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.audioOnly];
    result(value);
}

// 纯视频推流，只有RTMP推流才支持纯视频推流，当前RTC不支持纯视频推流
- (void)setVideoOnly:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool value = [arr[2] boolValue];
    self.config.videoOnly = value;
    result(nil);
}

- (void)getVideoOnly:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.videoOnly];
    result(value);
}

// 音频编码模式
- (void)setAudioEncoderMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.audioEncoderMode = value;
    result(nil);
}

- (void)getAudioEncoderMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.audioEncoderMode];
    result(value);
}

// 视频编码模式
- (void)setVideoEncoderMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.videoEncoderMode = value;
    result(nil);
}

- (void)getVideoEncoderMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.videoEncoderMode];
    result(value);
}

// 视频硬编码方式
- (void)setVideoHardEncoderCodec:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.videoHardEncoderCodec = value;
    result(nil);
}

- (void)getVideoHardEncoderCodec:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.videoHardEncoderCodec];
    result(value);
}

// 视频硬编模式下是否开启B帧
- (void)setOpenBFrame:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool value = [arr[2] boolValue];
    self.config.openBFrame = value;
    result(nil);
}

- (void)getOpenBFrame:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.openBFrame];
    result(value);
}

// 推流方向 : 竖屏、90度横屏、270度横屏
- (void)setOrientation:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.orientation = value;
    result(nil);
}

- (void)getOrientation:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.orientation];
    result(value);
}

// 预览显示模式
- (void)setPreviewDisplayMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.previewDisplayMode = value;
    result(nil);
}

- (void)getPreviewDisplayMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.previewDisplayMode];
    result(value);
}

// 重连时长
- (void)setConnectRetryInterval:(NSArray *)arr {
    FlutterResult result = arr[1];
    float value = [arr[2] floatValue];
    self.config.connectRetryInterval = value;
    result(nil);
}

- (void)getConnectRetryInterval:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%.2f", self.config.connectRetryInterval];
    result(value);
}

// 重连次数
- (void)setConnectRetryCount:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.connectRetryCount = value;
    result(nil);
}

- (void)getConnectRetryCount:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.connectRetryCount];
    result(value);
}


// 推流镜像
- (void)setPushMirror:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool value = [arr[2] boolValue];
    self.config.pushMirror = value;
    result(nil);
}

- (void)getPushMirror:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.pushMirror];
    result(value);
}

// 预览镜像
- (void)setPreviewMirror:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool value = [arr[2] boolValue];
    self.config.previewMirror = value;
    result(nil);
}

- (void)getPreviewMirror:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.previewMirror];
    result(value);
}

// 摄像头类型
- (void)setCameraType:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.cameraType = value;
    result(nil);
}

- (void)getCameraType:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.cameraType];
    result(value);
}

// 自动聚焦
- (void)setAutoFocus:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool value = [arr[2] boolValue];
    self.config.autoFocus = value;
    result(nil);
}

- (void)getAutoFocus:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.autoFocus];
    result(value);
}

// 暂停推流图片
- (void)setPauseImg:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = arr[2];
    UIImage *image = [LivePusherTool getImageWithContent:value];
    self.config.pauseImg = image;
    result(nil);
}

// 码率低图片
- (void)setNetworkPoorImg:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = arr[2];
    UIImage *image = [LivePusherTool getImageWithContent:value];
    self.config.networkPoorImg = image;
    result(nil);
}

// 外部自定义音频数据
- (void)setExternAudioFormat:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.externAudioFormat = value;
    result(nil);
}

- (void)getExternAudioFormat:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.externAudioFormat];
    result(value);
}

// 外部自定义视频数据
- (void)setExternVideoFormat:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.externVideoFormat = value;
    result(nil);
}

- (void)getExternVideoFormat:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.externVideoFormat];
    result(value);
}

// 音频应用场景
- (void)setAudioScene:(NSArray *)arr {
    FlutterResult result = arr[1];
    int value = [arr[2] intValue];
    self.config.audioScene = value;
    result(nil);
}

- (void)getAudioScene:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%ld", self.config.audioScene];
    result(value);
}

// 是否外部自定义数据推流
- (void)setExternMainStream:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool value = [arr[2] intValue];
    self.config.externMainStream = value;
    result(nil);
}

- (void)getExternMainStream:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *value = [NSString stringWithFormat:@"%d", self.config.externMainStream];
    result(value);
}

- (void)getPushResolution:(NSArray *)arr {
    FlutterResult result = arr[1];
    CGSize size = [self.config getPushResolution];
    NSDictionary *sizeDic = @{@"width": [NSString stringWithFormat:@"%f", size.width],
                              @"height": [NSString stringWithFormat:@"%f", size.height],
    };
    result(sizeDic);
}

@end
