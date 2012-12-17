//
//  TouchPoint.h
//  Represents a touched point (including scale)
//

#import <Foundation/Foundation.h>

@interface TouchPoint : NSObject
@property (nonatomic, readwrite, strong) UITouch *touch;
@property (nonatomic, readwrite, assign) CGPoint point;
@property (nonatomic, readwrite, assign) CGFloat scale;
@property (nonatomic, readonly) NSString *identifier;

+ (TouchPoint *)touchPointForTouch:(UITouch *)touch inView:(UIView *)view scale:(CGFloat)scale;
@end
