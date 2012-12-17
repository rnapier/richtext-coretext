//
//  PinchTextLayer.m
//

#import "PinchTextLayer.h"

#import <CoreText/CoreText.h>
#import <malloc/malloc.h>
#import <Accelerate/Accelerate.h>

#import "TouchPoint.h"

static const CFRange kRangeZero = {0, 0};
static NSString *const kTouchPointScalesName = @"touchPointScales";
static NSString *const kTouchPointRemoveKey = @"TouchPointRemove";

@interface PinchTextLayer ()
@property (nonatomic, readwrite, strong) NSMutableSet *touchPoints;
@property (nonatomic, readwrite, strong) __attribute__((NSObject)) CTTypesetterRef typesetter;

// Dummy property so we can animate it. See setValue:forKeyPath:
@property (nonatomic, readwrite, strong) NSMutableDictionary *touchPointScales;
@end

@implementation PinchTextLayer
{
  CGFloat *_adjustmentBuffer;
  CGPoint *_positionsBuffer;
  CGGlyph *_glyphsBuffer;
}

// Anything you want Core Animation to animate must be @dynamic.
// We're lying to Core Animation here, but it still needs to be @dynamic.
@dynamic touchPointScales;

#pragma mark -
#pragma mark Main drawing

- (void)drawInContext:(CGContextRef)context
{
  if (self.attributedString == nil) {
    return;
  }
  
  // Initialize the context (always initialize your text matrix)
  CGContextSetTextMatrix(context, CGAffineTransformIdentity);
  
  // Work out the geometry
  CGRect insetBounds = CGRectInset([self bounds], 40.0, 40.0);
  CGFloat boundsWidth = CGRectGetWidth(insetBounds);
  
  // Start in the upper-left corner
  CGPoint textOrigin = CGPointMake(CGRectGetMinX(insetBounds),
                                   CGRectGetMaxY(insetBounds));
  
  CFIndex startIndex = 0;
  NSUInteger stringLength = self.attributedString.length;
  while (startIndex < stringLength && textOrigin.y > insetBounds.origin.y) {
    CGFloat ascent, descent, leading;
    CTLineRef line = [self copyLineAtIndex:startIndex
                                  forWidth:boundsWidth
                                    ascent:&ascent
                                   descent:&descent
                                   leading:&leading];
    
    // Move forward to the baseline
    textOrigin.y -= ascent;
    CGContextSetTextPosition(context, textOrigin.x, textOrigin.y);
    
    // Draw each glyph run
    for (id runID in (__bridge id)CTLineGetGlyphRuns(line)) {
      [self drawRun:(__bridge CTRunRef)runID inContext:context textOrigin:textOrigin];
    }
    
    // Move the index beyond the line break.
    startIndex += CTLineGetStringRange(line).length;
    textOrigin.y -= descent + leading + 1; // +1 matches best to CTFramesetter's behavior
    CFRelease(line);
  }
}

#pragma mark -
#pragma mark Typesetting

- (CTLineRef)copyLineAtIndex:(CFIndex)startIndex
                    forWidth:(CGFloat)boundsWidth
                      ascent:(CGFloat *)ascent
                     descent:(CGFloat *)descent
                     leading:(CGFloat *)leading
{
  // Calculate the line
  CFIndex lineCharacterCount = CTTypesetterSuggestLineBreak(self.typesetter, startIndex, boundsWidth);
  CTLineRef line = CTTypesetterCreateLine(self.typesetter, CFRangeMake(startIndex, lineCharacterCount));
  
  // Fetch the typographic bounds
  CTLineGetTypographicBounds(line, &(*ascent), &(*descent), &(*leading));
  
  // Full-justify all but last line of paragraphs
  NSString *string = self.attributedString.string;
  NSUInteger endingLocation = startIndex + lineCharacterCount;
  if (endingLocation >= string.length || [string characterAtIndex:endingLocation] != '\n') {
    CTLineRef justifiedLine = CTLineCreateJustifiedLine(line, 1.0, boundsWidth);
    CFRelease(line);
    line = justifiedLine;
  }
  return line;
}

#pragma mark -
#pragma mark Draw runs

- (void)drawRun:(CTRunRef)run inContext:(CGContextRef)context textOrigin:(CGPoint)textOrigin
{
  [self applyStylesFromRun:run toContext:context];
  
  size_t glyphCount = (size_t)CTRunGetGlyphCount(run);
  
  CGPoint *positions = [self positionsForRun:run];
  
  [self adjustTextPositions:positions
                      count:glyphCount
                     origin:textOrigin
                touchPoints:self.touchPoints];
  
  const CGGlyph *glyphs = [self glyphsForRun:run];
  CGContextShowGlyphsAtPositions(context, glyphs, positions, glyphCount);
}


#pragma mark -
#pragma mark Styles

- (void)applyStylesFromRun:(CTRunRef)run
                 toContext:(CGContextRef)context
{
  NSDictionary *attributes = (__bridge id)CTRunGetAttributes(run);
  
  // Set the font
  CTFontRef runFont = (__bridge CTFontRef)attributes[NSFontAttributeName];
  CGFontRef cgFont = CTFontCopyGraphicsFont(runFont, NULL); // FIXME: We could optimize this by caching fonts we know we use.
  CGContextSetFont(context, cgFont);
  CGContextSetFontSize(context, CTFontGetSize(runFont));
  CFRelease(cgFont);
  
  // Set the color
  UIColor *color = attributes[NSForegroundColorAttributeName];
  CGContextSetFillColorWithColor(context, color.CGColor);
  
  // Any other style setting would go here
}

#pragma mark -
#pragma mark Positioning

- (CGPoint *)positionsForRun:(CTRunRef)run
{
  // This is slightly dangerous. We're getting a pointer to the internal
  // data, and yes, we're modifying it. But it avoids copying the memory
  // in most cases, which can get expensive.
  // Setup our buffers
  CGPoint *positions = (CGPoint *)CTRunGetPositionsPtr(run);
  if (positions == NULL) {
    ResizeBufferToAtLeast((void **)&_positionsBuffer, sizeof(CGPoint) * CTRunGetGlyphCount(run));
    CTRunGetPositions(run, kRangeZero, _positionsBuffer);
    positions = _positionsBuffer;
  }
  return positions;
}

- (void)adjustTextPositions:(CGPoint *)positions
                      count:(NSUInteger)count
                     origin:(CGPoint)textOrigin
                touchPoints:(NSSet *)touchPoints
{
  // Text space -> View Space
  [self addPoint:textOrigin toPositions:positions count:count];
  
  // Apply all the touches
  for (TouchPoint *touchPoint in touchPoints) {
    [self adjustViewPositions:positions count:count forTouchPoint:touchPoint];
  }
  
  // View Space -> Text Space
  [self subtractPoint:textOrigin fromPositions:positions count:count];
}

- (void)addPoint:(CGPoint)point
     toPositions:(CGPoint *)positions
           count:(NSUInteger)count
{
  float *xStart = (float *)positions;
  float *yStart = xStart + 1;
  vDSP_vsadd(xStart, 2, &(point.x), xStart, 2, count);
  vDSP_vsadd(yStart, 2, &(point.y), yStart, 2, count);
}

- (void)subtractPoint:(CGPoint)point
        fromPositions:(CGPoint *)positions
                count:(NSUInteger)count
{
  point.x = -point.x;
  point.y = -point.y;
  [self addPoint:point toPositions:positions count:count];
}

- (void)adjustViewPositions:(CGPoint *)positions count:(NSUInteger)count forTouchPoint:(TouchPoint *)touchPoint
{
  CGFloat *adjustment = [self adjustmentBufferForCount:count];
  CGPoint point = touchPoint.point;
  float scale = touchPoint.scale;
  
  // Tuning variables
  CGFloat highClip = 20;
  CGFloat lowClip = -highClip;
  
  // adjust = position - touchPoint
  memcpy(adjustment, positions, sizeof(CGPoint) * count);
  [self subtractPoint:point fromPositions:(CGPoint *)adjustment count:count];
  
  // Convert to polar coordinates (distance/angle)
  vDSP_polar(adjustment, 2, adjustment, 2, count);
  
  // Scale distance
  vDSP_svdiv(&scale, adjustment, 2, adjustment, 2, count);
  
  // Clip distances to range
  vDSP_vclip(adjustment, 2, &lowClip, &highClip, adjustment, 2, count);
  
  // Convert back to rectangular cordinates (x,y)
  vDSP_rect(adjustment, 2, adjustment, 2, count);
  
  // Apply adjustment
  vDSP_vsub(adjustment, 1, (float *)positions, 1, (float *)positions, 1, count * 2);
}

#pragma mark -
#pragma mark Glyphs

- (const CGGlyph *)glyphsForRun:(CTRunRef)run
{
  // This one is less dangerous since we don't modify it, and we keep the const
  // to remind ourselves that it's not to be modified lightly.
  const CGGlyph *glyphs = CTRunGetGlyphsPtr(run);
  if (glyphs == NULL) {
    ResizeBufferToAtLeast((void **)&_glyphsBuffer, sizeof(CGGlyph) * CTRunGetGlyphCount(run));
    CTRunGetGlyphs(run, kRangeZero, _glyphsBuffer);
    glyphs = _glyphsBuffer;
  }
  return glyphs;
}

#pragma mark -
#pragma mark Buffers

void ResizeBufferToAtLeast(void **buffer, size_t size) {
  if (!*buffer || malloc_size(*buffer) < size) {
    *buffer = realloc(*buffer, size);
  }
}

- (CGFloat *)adjustmentBufferForCount:(NSUInteger)count
{
  ResizeBufferToAtLeast((void **)&_adjustmentBuffer, sizeof(CGPoint) * count);
  return _adjustmentBuffer;
}

#pragma mark -
#pragma mark Accessors

- (void)setPrimitiveAttributedString:(NSAttributedString *)attributedString
{
  _attributedString = attributedString;
}

- (void)setAttributedString:(NSAttributedString *)attributedString
{
  if (attributedString != _attributedString) {
    _attributedString = attributedString;
    self.typesetter = CTTypesetterCreateWithAttributedString((__bridge CFTypeRef)_attributedString);
    [self setNeedsDisplay];
  }
}

#pragma mark -
#pragma mark Init/Dealloc

- (id)init
{
  self = [super init];
  if (self) {
    self.touchPoints = [NSMutableSet new];
  }
  return self;
}

- (id)initWithLayer:(id)layer
{
  self = [super initWithLayer:layer];
  [self setTypesetter:[layer typesetter]];
  [self setPrimitiveAttributedString:[[layer attributedString] copy]];
  [self setTouchPoints:[[layer touchPoints] copy]];
  return self;
}

#pragma mark -
#pragma mark CALayer

+ (BOOL)needsDisplayForKey:(NSString *)key
{
  if ([key isEqualToString:kTouchPointScalesName]) {
    return YES;
  }
  else {
    return [super needsDisplayForKey:key];
  }
}

#pragma mark -
#pragma mark KVC

- (void)setValue:(id)value forKeyPath:(NSString *)keyPath
{
  if ([keyPath hasPrefix:[kTouchPointScalesName stringByAppendingString:@"."]]) {
    NSString *identifier = [self identifierForKeyPath:keyPath];
    TouchPoint *touchPoint = [self touchPointForIdentifier:identifier];
    touchPoint.scale = [value floatValue];
  }
  else {
    [super setValue:value forKeyPath:keyPath];
  }
}

- (NSString *)identifierForKeyPath:(NSString *)keyPath {
  return [keyPath substringFromIndex:[keyPath rangeOfString:@"."].location + 1];
}

#pragma mark -
#pragma mark Touch handling

- (TouchPoint *)touchPointForIdentifier:(NSString *)identifier
{
  for (TouchPoint *touchPoint in self.touchPoints) {
    if ([[touchPoint identifier] isEqualToString:identifier]) {
      return touchPoint;
    }
  }
  return nil;
}

- (NSString *)touchPointScalesKeyPathForTouchPoint:(TouchPoint *)touchPoint
{
  return [kTouchPointScalesName stringByAppendingFormat:@".%@", [touchPoint identifier]];
}

- (TouchPoint *)touchPointForTouch:(UITouch *)touch
{
  for (TouchPoint *touchPoint in self.touchPoints) {
    if (touchPoint.touch == touch) {
      return touchPoint;
    }
  }
  return nil;
}

- (void)addTouches:(NSSet *)touches inView:(UIView *)view scale:(CGFloat)scale
{
  for (UITouch *touch in touches) {
    TouchPoint *touchPoint = [TouchPoint touchPointForTouch:touch inView:view scale:scale];
    NSString *keyPath = [self touchPointScalesKeyPathForTouchPoint:touchPoint];
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:keyPath];
    anim.duration = 0.1;
    anim.fromValue = @0;
    anim.toValue = @(touchPoint.scale);
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.delegate = self;
    [self addAnimation:anim forKey:keyPath];
    [self setValue:@(touchPoint.scale) forKey:keyPath];
    
    [self.touchPoints addObject:touchPoint];
  }
}

- (void)updateTouches:(NSSet *)touches inView:(UIView *)view
{
  for (UITouch *touch in touches) {
    TouchPoint *touchPoint = [self touchPointForTouch:touch];
    touchPoint.point = [touch locationInView:view];
  }
  [self setNeedsDisplay];
}

- (void)removeTouches:(NSSet *)touches
{
  for (UITouch *touch in touches) {
    TouchPoint *touchPoint = [self touchPointForTouch:touch];
    NSString *keyPath = [self touchPointScalesKeyPathForTouchPoint:touchPoint];

    [CATransaction begin];
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:keyPath];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.duration = .5;
    CGFloat currentScale = touchPoint.scale;
    animation.values = @[@(currentScale), @(-currentScale / 20), @0];
    animation.calculationMode = kCAAnimationCubic;
    [CATransaction setCompletionBlock:^{ [self.touchPoints removeObject:touchPoint]; }];
    [self addAnimation:animation forKey:keyPath];
    [CATransaction commit];
  }
}

@end
