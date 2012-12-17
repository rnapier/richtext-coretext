//
//  PinchTextView.m
//
//  Displays an attributed string and pinches it towards touches.

#import "PinchTextView.h"

#import <QuartzCore/QuartzCore.h>

#import "PinchTextLayer.h"
#import "TouchPoint.h"

@implementation PinchTextView

#pragma mark -
#pragma mark UIView

+ (Class)layerClass
{
  return [PinchTextLayer class];
}

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
  self.layer.geometryFlipped = YES;
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

#pragma mark -
#pragma mark Accessors

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