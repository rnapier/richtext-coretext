//
//  TouchPoint.m
//  Represents a touched point (including scale)
//

#import "TouchPoint.h"

@implementation TouchPoint

+ (TouchPoint *)touchPointForTouch:(UITouch *)aTouch inView:(UIView *)aView scale:(CGFloat)aScale
{
  TouchPoint *touchPoint = [TouchPoint new];
  touchPoint.touch = aTouch;
  touchPoint.scale = aScale;
  touchPoint.point = [aTouch locationInView:aView];
  return touchPoint;
}

- (NSString *)identifier {
  return [NSString stringWithFormat:@"%p", self];
}

@end
