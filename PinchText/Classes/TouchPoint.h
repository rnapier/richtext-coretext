//
//  TouchPoint.h
//  Represents a touched point (including scale)
//

#import <Foundation/Foundation.h>

@interface TouchPoint : NSObject
@property (nonatomic, readwrite, strong) UITouch *touch;
@property (nonatomic, readwrite, assign) CGPoint point;
@property (nonatomic, readwrite, assign) CGFloat scale; // How much does this touch impact the pinch effect?

+ (TouchPoint *)touchPointForTouch:(UITouch *)touch inView:(UIView *)view scale:(CGFloat)scale;
- (NSString *)identifier;
@end
