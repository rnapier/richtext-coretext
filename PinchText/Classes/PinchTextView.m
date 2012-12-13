//
//  PinchTextView.m
//  TextDemo
//
//  Created by Rob on 9/7/10.
//  Copyright 2010 Rob Napier. All rights reserved.
//

#import "PinchTextView.h"
#import <malloc/malloc.h>
#import <Accelerate/Accelerate.h>

static const CFRange kRangeZero = {0,0};

@interface PinchTextView ()

@property (nonatomic, readonly) CTTypesetterRef typesetter;
@property (nonatomic, readwrite, strong) NSSet *touchPoints;
@property (nonatomic, readwrite, assign) CGPoint *adjustmentBuffer;
@end

@implementation PinchTextView

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self != nil) {
    [self finishInit];
  }
  return self;
}

- (void)awakeFromNib {
  [self finishInit];
}

- (void)finishInit {
#if TARGET_OS_IPHONE
  // Flip the view's context. Core Text runs bottom to top, even on iPad, and
  // the view is much simpler if we do everything in Mac coordinates.
  CGAffineTransform transform = CGAffineTransformMakeScale(1, -1);
  CGAffineTransformTranslate(transform, 0, -self.bounds.size.height);
  self.transform = transform;
#endif
  //  self.contentScaleFactor = 1.0;  // If you want it to be near-realtime. :D
}

- (void)dealloc {
  CFRelease(_typesetter), _typesetter = nil;
}

void AddPointToPositions(CGPoint *positions, NSUInteger count, CGPoint textOrigin) {
  float *xStart = (float *)positions;
  float *yStart = xStart + 1;
  vDSP_vsadd(xStart, 2, &(textOrigin.x), xStart, 2, count);
  vDSP_vsadd(yStart, 2, &(textOrigin.y), yStart, 2, count);
}

void SubtractPointFromPositions(CGPoint *positions, NSUInteger count, CGPoint textOrigin) {
  textOrigin.x = -textOrigin.x;
  textOrigin.y = -textOrigin.y;
  AddPointToPositions(positions, count, textOrigin);
}

CGFloat *GetAdjustmentBuffer(NSUInteger count) {
  // Static memory so we don't malloc/free constantly. Grow it to the largest size we ever need
  static CGFloat *adjust = NULL;
  
  size_t adjustSize = sizeof(CGPoint) * count;
  if (!adjust || malloc_size(adjust) < adjustSize) {
    adjust = realloc(adjust, adjustSize);
  }
  return adjust;
}

void AdjustViewPositionsForPoint(CGPoint *positions, NSUInteger count, CGPoint touchPoint) {
  CGFloat *adjustment = GetAdjustmentBuffer(count);
  
  // Tuning variables
  CGFloat scale = 1000;
  CGFloat highClip = 20;
  CGFloat lowClip = -highClip;
  
  // adjust = position - touchPoint
  memcpy(adjustment, positions, sizeof(CGPoint) * count);
  SubtractPointFromPositions((CGPoint *)adjustment, count, touchPoint);
  
  // Convert to polar coordinates (distance/angle)
  vDSP_polar(adjustment, 2, adjustment, 2, count);
  
  // Scale distance
  vDSP_svdiv(&scale, adjustment, 2, adjustment, 2, count);
  
  // Clip distances to range
  vDSP_vclip(adjustment, 2, &lowClip, &highClip, adjustment, 2, count);
  
  // Convert back to rectangular cordinates (x,y)
  vDSP_rect(adjustment, 2, adjustment, 2, count);
  
  // Apply adjustment
  vDSP_vsub(adjustment, 1, (float*)positions, 1, (float*)positions, 1, count * 2);
}

void AdjustTextPositionsForPoints(CGPoint *positions, NSUInteger count,
                                  CGPoint textOrigin, NSSet *touchPoints) {
  // Text space -> View Space
  AddPointToPositions(positions, count, textOrigin);
  
  // Apply all the touches
  for (NSValue *touchPointValue in touchPoints) {
    AdjustViewPositionsForPoint(positions, count, [touchPointValue CGPointValue]);
  }
  
  // View Space -> Text Space
  SubtractPointFromPositions(positions, count, textOrigin);
}

void SetContextFontFromRun(CGContextRef context, CTRunRef run) {
  // Set the font
  CTFontRef runFont = CFDictionaryGetValue(CTRunGetAttributes(run),
                                           kCTFontAttributeName);
  CGFontRef cgFont = CTFontCopyGraphicsFont(runFont, NULL); // FIXME: We could optimize this by caching fonts we know we use.
  CGContextSetFont(context, cgFont);
  CGContextSetFontSize(context, CTFontGetSize(runFont));
  CFRelease(cgFont);
}

CGPoint *GetPositionsForRun(CTRunRef run) {
  static CGPoint *positionsBuffer = NULL;
  
  // This is slightly dangerous. We're getting a pointer to the internal
  // data, and yes, we're modifying it. But it avoids copying the memory
  // in most cases, which can get expensive.
  // Setup our buffers
  CGPoint *positions = (CGPoint*)CTRunGetPositionsPtr(run);
  if (positions == NULL) {
    size_t positionsBufferSize = sizeof(CGPoint) * CTRunGetGlyphCount(run);
    if (!positionsBuffer || malloc_size(positionsBuffer) < positionsBufferSize) {
      positionsBuffer = realloc(positionsBuffer, positionsBufferSize);
    }
    CTRunGetPositions(run, kRangeZero, positionsBuffer);
    positions = positionsBuffer;
  }
  return positions;
}

const CGGlyph *GetGlyphsForRun(CTRunRef run) {
  static CGGlyph *glyphsBuffer = NULL;
  
  // This one is less dangerous since we don't modify it, and we keep the const
  // to remind ourselves that it's not to be modified lightly.
  const CGGlyph *glyphs = CTRunGetGlyphsPtr(run);
  if (glyphs == NULL) {
    size_t glyphsBufferSize = sizeof(CGGlyph) * CTRunGetGlyphCount(run);
    if (malloc_size(glyphsBuffer) < glyphsBufferSize) {
      glyphsBuffer = realloc(glyphsBuffer, glyphsBufferSize);
    }
    CTRunGetGlyphs(run, kRangeZero, (CGGlyph*)glyphs);
    glyphs = glyphsBuffer;
  }
  return glyphs;
}

CTLineRef CreateLineWithTypesetterAtIndex(CTTypesetterRef typesetter, CFIndex startIndex,
                                          CGFloat boundsWidth, CGFloat *ascent,
                                          CGFloat *descent, CGFloat *leading) {
  
  // Calculate the line
  CFIndex lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, startIndex, boundsWidth);
  CTLineRef line = CTTypesetterCreateLine(typesetter, CFRangeMake(startIndex, lineCharacterCount));
  
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

- (void)drawRect:(CGRect)rect {
  
  if (self.attributedString == nil) {
    return;
  }
  
  // Initialize the context (always initialize your text matrix)
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSetTextMatrix(context, CGAffineTransformIdentity);
  
  // Cache any calls we can avoid in the loop
  NSSet *touchPoints = self.touchPoints;
  BOOL touchIsActive = (touchPoints != nil);
  CTTypesetterRef typesetter = self.typesetter;
  
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
    CTLineRef line = CreateLineWithTypesetterAtIndex(typesetter, startIndex, boundsWidth,
                                                     &ascent, &descent, &leading);
    
    // Move forward to the baseline
    textOrigin.y -= ascent;
    CGContextSetTextPosition(context, textOrigin.x, textOrigin.y);
    
    // Handle each glyph run
    for (id runID in (__bridge id)CTLineGetGlyphRuns(line)) {
      CTRunRef run = (__bridge CTRunRef)runID;
      
      SetContextFontFromRun(context, run);
      
      CGPoint *positions = GetPositionsForRun(run);
      
      const CGGlyph *glyphs = GetGlyphsForRun(run);
      
      CFIndex glyphCount = CTRunGetGlyphCount(run);
      
      if (touchIsActive) {
        AdjustTextPositionsForPoints(positions, glyphCount, textOrigin, touchPoints);
      }
      
      CGContextShowGlyphsAtPositions(context, glyphs, positions, glyphCount);
    }
    
    // Move the index beyond the line break.
    startIndex += CTLineGetStringRange(line).length;
    textOrigin.y -= descent + leading + 1; // +1 matches best to CTFramesetter's behavior
    CFRelease(line);
  }
}

- (void)updateTouchPointWithTouches:(NSSet *)touches {
  NSMutableSet *points = [NSMutableSet new];
  for (UITouch *touch in touches) {
    CGPoint location = [touch locationInView:self];
    [points addObject:[NSValue valueWithCGPoint:location]];
  }
  
  self.touchPoints = points;
  [self setNeedsDisplay];
}

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

- (void)setAttributedString:(NSAttributedString *)attributedString {
  if (attributedString != _attributedString) {
    _attributedString = attributedString;
    
    if (_typesetter != NULL) {
      CFRelease(_typesetter);
    }
    _typesetter = CTTypesetterCreateWithAttributedString((__bridge CFTypeRef)_attributedString);
  }
}

@end