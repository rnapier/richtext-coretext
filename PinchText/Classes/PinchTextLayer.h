//
//  PinchTextLayer.h
//  Displays an attributed string and pinches it towards touches.
//

#import <QuartzCore/QuartzCore.h>

@interface PinchTextLayer : CALayer
@property (nonatomic, readwrite, copy) NSAttributedString *attributedString;

- (void)addTouches:(NSSet *)touches inView:(UIView *)view scale:(CGFloat)scale;
- (void)updateTouches:(NSSet *)touches inView:(UIView *)view;
- (void)removeTouches:(NSSet *)touches;
@end
