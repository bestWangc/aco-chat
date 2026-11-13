//
//  LivePusherPreview.m
//  livepush
//
//  Created by ISS013602000846 on 2023/2/13.
//

#import "LivePusherPreview.h"

@interface LivePusherPreview ()

@property (nonatomic, strong) UIView *pusherPreview;

@end

@implementation LivePusherPreview

- (instancetype)initWithFrameArguments:(id _Nullable)args
                       binaryMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    if (self = [super init]) {
        NSDictionary *dic = args;
        CGFloat x = [dic[@"x"] floatValue];
        CGFloat y = [dic[@"y"] floatValue];
        CGFloat width = [dic[@"width"] floatValue];
        CGFloat height = [dic[@"height"] floatValue];
        self.pusherPreview = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, height)];
    }
    return self;
}

#pragma mark -- FlutterPlatformView
- (UIView *)view {
    return self.pusherPreview;
}

@end
