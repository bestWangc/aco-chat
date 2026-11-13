//
//  LivePusherPreview.h
//  livepush
//
//  Created by ISS013602000846 on 2023/2/13.
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

@interface LivePusherPreview : NSObject<FlutterPlatformView>

- (instancetype)initWithFrameArguments:(id _Nullable)args
                       binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger;

@end

NS_ASSUME_NONNULL_END
