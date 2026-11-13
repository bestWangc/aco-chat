#import "SampleHandler.h"
#import <AlivcLibReplayKitExt/AlivcLibReplayKitExt.h>

static NSString * const AcoScreenBroadcastAppGroup = @"group.com.meimeidacios.app";

@interface SampleHandler ()
@property(nonatomic, strong) dispatch_source_t stopTimer;
@end

@implementation SampleHandler

- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *, NSObject *> *)setupInfo {
  [[AlivcReplayKitExt sharedInstance] setAppGroup:AcoScreenBroadcastAppGroup];
  NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:AcoScreenBroadcastAppGroup];
  [sharedDefaults setBool:YES forKey:@"aco.aliyun.broadcast.active"];
  [sharedDefaults setBool:NO forKey:@"aco.aliyun.broadcast.stop_requested"];
  [sharedDefaults synchronize];

  dispatch_source_t timer = dispatch_source_create(
      DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
  self.stopTimer = timer;
  dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
                            NSEC_PER_SEC, 200 * NSEC_PER_MSEC);
  __weak typeof(self) weakSelf = self;
  dispatch_source_set_event_handler(timer, ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:AcoScreenBroadcastAppGroup];
    if (strongSelf && [defaults boolForKey:@"aco.aliyun.broadcast.stop_requested"]) {
      dispatch_source_cancel(strongSelf.stopTimer);
      strongSelf.stopTimer = nil;
      NSError *stopError = [NSError errorWithDomain:@"AcoScreenBroadcast"
                                               code:1
                                           userInfo:@{NSLocalizedDescriptionKey: @"Screen sharing stopped by the host"}];
      [strongSelf finishBroadcastWithError:stopError];
    }
  });
  dispatch_resume(timer);
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer
                   withType:(RPSampleBufferType)sampleBufferType {
  // LiveKit already owns the microphone in a room; forward only the screen.
  if (sampleBufferType == RPSampleBufferTypeVideo) {
    [[AlivcReplayKitExt sharedInstance] sendSampleBuffer:sampleBuffer
                                               withType:sampleBufferType];
  }
}

- (void)broadcastFinished {
  if (self.stopTimer) {
    dispatch_source_cancel(self.stopTimer);
    self.stopTimer = nil;
  }
  NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:AcoScreenBroadcastAppGroup];
  [sharedDefaults setBool:NO forKey:@"aco.aliyun.broadcast.active"];
  [sharedDefaults setBool:NO forKey:@"aco.aliyun.broadcast.stop_requested"];
  [sharedDefaults synchronize];
  [[AlivcReplayKitExt sharedInstance] finishBroadcast];
}

@end
