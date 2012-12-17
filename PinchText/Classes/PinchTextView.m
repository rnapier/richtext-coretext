//
//  PinchTextView.m
//
//  Displays an attributed string and pinches it towards touches.

#import "PinchTextView.h"
#import "PinchTextLayer.h"
#import "TouchPoint.h"

@implementation PinchTextView

#pragma mark -
#pragma mark Init

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self != nil) {
    [self finishInit];
  }
  return self;
}

- (void)awakeFromNib
{
  [self finishInit];
}

- (void)finishInit
{
#if TARGET_OS_IPHONE
  // Flip the view's context. Core Text runs bottom to top, even on iPad, and
  // the view is much simpler if we do everything in Mac coordinates.
  CGAffineTransform transform = CGAffineTransformMakeScale(1, -1);
  CGAffineTransformTranslate(transform, 0, -self.bounds.size.height);
  self.transform = transform;
#endif
  self.contentScaleFactor = [[UIScreen mainScreen] scale];
}

#pragma mark -
#pragma mark UIResponder

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{ 
  [self.pinchTextLayer addTouches:touches inView:self scale:1000];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  [self.pinchTextLayer updateTouches:touches inView:self];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  [self.pinchTextLayer removeTouches:touches];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
{
  [self.pinchTextLayer removeTouches:touches];
}

+ (Class)layerClass
{
  return [PinchTextLayer class];
}

- (NSAttributedString *)attributedString {
  return [self.pinchTextLayer attributedString];
}

- (void)setAttributedString:(NSAttributedString *)attributedString {
  [self.pinchTextLayer setAttributedString:attributedString];
}

- (PinchTextLayer *)pinchTextLayer {
  return (PinchTextLayer*)self.layer;
}

@end