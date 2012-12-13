//
//  PinchTextView.m
//
//  Displays an attributed string and pinches it towards touches.

#import "PinchTextView.h"
#import <malloc/malloc.h>
#import <Accelerate/Accelerate.h>

static const CFRange kRangeZero = {0, 0};

@interface PinchTextView ()

@property (nonatomic, readonly) CTTypesetterRef typesetter;
@property (nonatomic, readwrite, strong) NSSet *touchPoints;
@end

@implementation PinchTextView
{
  CGFloat *_adjustmentBuffer;
  CGPoint *_positionsBuffer;
  CGGlyph *_glyphsBuffer;
}

#pragma mark -
#pragma mark Drawing

- (void)drawRect:(CGRect)rect
{
  if (self.attributedString == nil) {
    return;
  }

  // Initialize the context (always initialize your text matrix)
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSetTextMatrix(context, CGAffineTransformIdentity);

  // Cache any calls we can avoid in the loop
  NSSet *touchPoints = self.touchPoints;
  BOOL touchIsActive = (touchPoints != nil);

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

    // Handle each glyph run
    for (id runID in (__bridge id)CTLineGetGlyphRuns(line)) {
      CTRunRef run = (__bridge CTRunRef)runID;

      [self applyStylesFromRun:run toContext:context];

      size_t glyphCount = (size_t)CTRunGetGlyphCount(run);

      CGPoint *positions = [self positionsForRun:run];

      if (touchIsActive) {
        [self adjustTextPositions:positions
                            count:glyphCount
                           origin:textOrigin
                      touchPoints:touchPoints];
      }

      const CGGlyph *glyphs = [self glyphsForRun:run];
      CGContextShowGlyphsAtPositions(context, glyphs, positions, glyphCount);
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

  // Set the font
  CTFontRef runFont = CFDictionaryGetValue(CTRunGetAttributes(run),
                                           kCTFontAttributeName);
  CGFontRef cgFont = CTFontCopyGraphicsFont(runFont, NULL); // FIXME: We could optimize this by caching fonts we know we use.
  CGContextSetFont(context, cgFont);
  CGContextSetFontSize(context, CTFontGetSize(runFont));
  CFRelease(cgFont);

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
  for (NSValue *touchPointValue in touchPoints) {
    [self adjustViewPositions:positions
                        count:count
                forTouchPoint:[touchPointValue CGPointValue]];
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

- (void)adjustViewPositions:(CGPoint *)positions
                      count:(NSUInteger)count
              forTouchPoint:(CGPoint)touchPoint
{
  CGFloat *adjustment = [self adjustmentBufferForCount:count];

  // Tuning variables
  CGFloat scale = 1000;
  CGFloat highClip = 20;
  CGFloat lowClip = -highClip;

  // adjust = position - touchPoint
  memcpy(adjustment, positions, sizeof(CGPoint) * count);
  [self subtractPoint:touchPoint fromPositions:(CGPoint *)adjustment count:count];

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
  //  self.contentScaleFactor = 1.0;  // If you want it to be near-realtime. :D
}

- (void)dealloc
{
  CFRelease(_typesetter), _typesetter = nil;
}

#pragma mark -
#pragma mark UIResponder

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  [self updateTouchPointWithTouches:[event touchesForView:self]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  [self updateTouchPointWithTouches:[event touchesForView:self]];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  self.touchPoints = nil;
  [self setNeedsDisplay];
}

- (void)updateTouchPointWithTouches:(NSSet *)touches
{
  NSMutableSet *points = [NSMutableSet new];
  for (UITouch *touch in touches) {
    CGPoint location = [touch locationInView:self];
    [points addObject:[NSValue valueWithCGPoint:location]];
  }
  
  self.touchPoints = points;
  [self setNeedsDisplay];
}

#pragma mark -
#pragma mark Accessors

- (void)setAttributedString:(NSAttributedString *)attributedString
{
  if (attributedString != _attributedString) {
    _attributedString = attributedString;

    if (_typesetter != NULL) {
      CFRelease(_typesetter);
    }
    _typesetter = CTTypesetterCreateWithAttributedString((__bridge CFTypeRef)_attributedString);
  }
}

@end