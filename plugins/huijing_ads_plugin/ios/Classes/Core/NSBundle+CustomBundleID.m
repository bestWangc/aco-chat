#import "NSBundle+CustomBundleID.h"
#import <objc/runtime.h>

static char kOriginalBundleIDKey;
static char kCustomBundleIDKey;

@implementation NSBundle (CustomBundleID)

- (NSString *)originalBundleID {
    NSString *value = objc_getAssociatedObject(self, &kOriginalBundleIDKey);
    if (!value) {
        value = [[self infoDictionary] objectForKey:@"CFBundleIdentifier"];
        objc_setAssociatedObject(self, &kOriginalBundleIDKey, value, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    return value;
}

- (NSString *)customBundleID {
    return objc_getAssociatedObject(self, &kCustomBundleIDKey);
}

- (void)setCustomBundleID:(NSString *)customBundleID {
    objc_setAssociatedObject(self, &kCustomBundleIDKey, customBundleID, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)custom_setBundleIdentifier:(NSString *_Nullable)bundleID {
    self.customBundleID = bundleID;
}

// 方法交换：bundleIdentifier 返回 customBundleID（如果有）
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(bundleIdentifier));
        Method swizzled = class_getInstanceMethod(self, @selector(hj_swizzled_bundleIdentifier));
        method_exchangeImplementations(original, swizzled);
    });
}

- (NSString *)hj_swizzled_bundleIdentifier {
    if (self.customBundleID) {
        return self.customBundleID;
    }
    return [self hj_swizzled_bundleIdentifier]; // 调用原始实现
}

@end