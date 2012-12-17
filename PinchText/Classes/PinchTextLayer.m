//
//  PinchTextLayer.m
//

#import "PinchTextLayer.h"
#import <CoreText/CoreText.h>
#import <malloc/malloc.h>
#import <Accelerate/Accelerate.h>
#import <QuartzCore/QuartzCore.h>
#import "TouchPoint.h"
#import <objc/runtime.h>

static const CFRange kRangeZero = {0, 0};
static const NSUInteger kMaxTouches = 10;

@interface PinchTextLayer ()
@property (nonatomic, readwrite, assign) CGFloat touchPointScale0;
@property (nonatomic, readwrite, assign) CGFloat touchPointScale1;
@property (nonatomic, readwrite, assign) CGFloat touchPointScale2;
@property (nonatomic, readwrite, assign) CGFloat touchPointScale3;
@property (nonatomic, readwrite, assign) CGFloat touchPointScale4;
@property (nonatomic, readwrite, assign) CGFloat touchPointScale5;
@property (nonatomic, readwrite, assign) CGFloat touchPointScale6;
@property (nonatomic, readwrite, assign) CGFloat touchPointScale7;
@property (nonatomic, readwrite, assign) CGFloat touchPointScale8;
@property (nonatomic, readwrite, assign) CGFloat touchPointScale9;
@property (nonatomic, readwrite, strong) __attribute__((NSObject)) CTTypesetterRef typesetter;
@end

@implementation PinchTextLayer
{
  CGFloat *_adjustmentBuffer;
  CGPoint *_positionsBuffer;
  CGGlyph *_glyphsBuffer;
}

@dynamic touchPoints;
@dynamic touchPointScale0;
@dynamic touchPointScale1;
@dynamic touchPointScale2;
@dynamic touchPointScale3;
@dynamic touchPointScale4;
@dynamic touchPointScale5;
@dynamic touchPointScale6;
@dynamic touchPointScale7;
@dynamic touchPointScale8;
@dynamic touchPointScale9;

#pragma mark -
#pragma mark Drawing

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

- (void)drawInContext:(CGContextRef)context
{
  if (self.attributedString == nil) {
    return;
  }
  
  // Initialize the context (always initialize your text matrix)
  CGContextSetTextMatrix(context, CGAffineTransformIdentity);
  //CGContextSetShouldSmoothFonts(context, true);
  CGContextSetShouldAntialias(context, true);
  
  // Work out the geometry
  CGRect insetBounds = CGRectInset([self bounds], 40.0, 40.0);
  CGFloat boundsWidth = CGRectGetWidth(insetBounds);
  
  // Start in the upper-left corner
  CGPoint textOrigin = CGPointMake(CGRectGetMinX(insetBounds),
                                   CGRectGetMaxY(insetBounds));
  
  CFIndex startIndex = 0;
  NSUInteger stringLength = self.attributedString.length;
  while (startIndex < stringLength && textOrigin.y > insetBounds.origin.y) {
    CGFloat ascent;
    CGFloat descent;
    CGFloat leading;
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
  double lineWidth = CTLineGetTypographicBounds(line, &(*ascent), &(*descent), &(*leading));
  
  // Full-justify if the text isn't too short.
  if ((lineWidth / boundsWidth) > 0.85) {
    CTLineRef justifiedLine = CTLineCreateJustifiedLine(line, 1.0, boundsWidth);
    CFRelease(line);
    line = justifiedLine;
  }
  return line;
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

- (float)scaleForTouchPoint:(TouchPoint *)touchPoint {
  return [[self valueForKey:[NSString stringWithFormat:@"touchPointScale%d", touchPoint.tag]] floatValue];  // FIXME: Handle non-animating
}

- (void)adjustViewPositions:(CGPoint *)positions count:(NSUInteger)count forTouchPoint:(TouchPoint *)touchPoint
{
  CGFloat *adjustment = [self adjustmentBufferForCount:count];
  CGPoint point = touchPoint.point;
  float scale = [self scaleForTouchPoint:touchPoint];
  
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

- (void)setPrimitiveAttributedString:(NSAttributedString *)attributedString {
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

- (id)initWithLayer:(id)layer {
  self = [super initWithLayer:layer];
  [self setTypesetter:[layer typesetter]];
  [self setPrimitiveAttributedString:[[layer attributedString] copy]];
  [self setTouchPoints:[[layer touchPoints] copy]];
  return self;
}

#pragma mark -
#pragma CALayer

+ (BOOL)needsDisplayForKey:(NSString *)key {
  if ([key isEqualToString:@"touchPoints"] || [key hasPrefix:@"touchPointScale"]) { // FIXME: HACK
    return YES;
  }
  return [super needsDisplayForKey:key];
}

- (TouchPoint *)touchPointForTag:(NSUInteger)tag {
  for (TouchPoint *touchPoint in self.touchPoints) {
    if (touchPoint.tag == tag) {
      return touchPoint;
    }
  }
  return nil;
}

- (NSUInteger)firstAvailableTag {
  for (NSUInteger tag = 0; tag < kMaxTouches; tag++) {
    if (! [self touchPointForTag:tag]) {
      return tag;
    }
  }
  return NSNotFound;
}

- (void)addTouchPoints:(NSSet *)touchPoints {
  for (TouchPoint *touchPoint in touchPoints) {
    NSUInteger tag = [self firstAvailableTag];  // FIXME: Handle NSNotFound
    touchPoint.tag = tag;
    NSString *keypath = [NSString stringWithFormat:@"touchPointScale%d", tag];
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:keypath];
    anim.duration = 2;
    anim.fromValue = @0;
    anim.toValue = @(touchPoint.scale);
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.delegate = self;
    [self addAnimation:anim forKey:keypath];
    [self setValue:@(touchPoint.scale) forKey:keypath];
  
    if (! self.touchPoints) {
      self.touchPoints = [touchPoints copy];
    }
    else {
      self.touchPoints = [self.touchPoints setByAddingObjectsFromSet:touchPoints];
    }
  }
}

@end
