//
//  AlivcNotActionView.m
//  flutter_livepush_plugin
//
//  Created by ISS013602000846 on 2023/6/15.
//

#import "LiveBeautyBgView.h"

@implementation LiveBeautyBgView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    return  view == self ? nil : view;
}

@end
