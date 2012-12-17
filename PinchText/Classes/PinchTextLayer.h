//
//  PinchTextLayer.h
//  Displays an attributed string and pinches it towards touches.
//

#import <QuartzCore/QuartzCore.h>

@interface PinchTextLayer : CALayer
@property (nonatomic, readwrite, copy) NSAttributedString *attributedString;
@property (nonatomic, readwrite, copy) NSSet *touchPoints;

- (void)addTouchPoints:(NSSet *)touchPoints;
@end
