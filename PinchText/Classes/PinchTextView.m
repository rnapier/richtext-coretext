//
//  PinchTextView.m
//  TextDemo
//
//  Created by Rob on 9/7/10.
//  Copyright 2010 Rob Napier. All rights reserved.
//

#import "PinchTextView.h"
#import <malloc/malloc.h>

static const CFRange kRangeZero = {0,0};

@interface PinchTextView ()

@property (nonatomic, readonly) CTTypesetterRef typesetter;
@property (nonatomic, readwrite, assign) CGPoint touchPoint;
- (void)finishInit;
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
}

- (void)dealloc {
  CFRelease(_typesetter), _typesetter = nil;
}

CGPoint GetPinchedPointForPoint(CGPoint point, CGPoint textOrigin, CGPoint touchPoint) {
  // Text space -> view space
  CGPoint pinchedPoint = point;
  pinchedPoint.x += textOrigin.x;
  pinchedPoint.y += textOrigin.y;
  
  CGFloat r = sqrtf(hypotf(pinchedPoint.x - touchPoint.x,
                           pinchedPoint.y - touchPoint.y)) / 4;
  CGFloat theta = atan2f(pinchedPoint.y - touchPoint.y,
                         pinchedPoint.x - touchPoint.x);
  CGFloat g = 10;
  
  pinchedPoint.x -= floorf(cosf(theta) * r * g);
  pinchedPoint.y -= floor(sinf(theta) * r * g);
  
  // view space -> text space
  pinchedPoint.x -= textOrigin.x;
  pinchedPoint.y -= textOrigin.y;
  
  return pinchedPoint;
}

- (void)drawRect:(CGRect)rect {
  
  CGPoint *positionsBuffer = NULL;
  CGGlyph *glyphsBuffer = NULL;
  
  CFAttributedStringRef attributedString = (__bridge CFAttributedStringRef)self.attributedString;
  
  if (attributedString == nil)
  {
    return;
  }
  
  // Initialize the context (always initialize your text matrix)
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSetTextMatrix(context, CGAffineTransformIdentity);
  
  // Cache any calls we can avoid in the loop
  CGPoint touchPoint = self.touchPoint;
  BOOL touchIsActive = ! CGPointEqualToPoint(touchPoint, CGPointZero);
  
  // Work out the geometry
  CGRect insetBounds = CGRectInset([self bounds], 40.0, 40.0);
  CGFloat boundsWidth = CGRectGetWidth(insetBounds);

  // Draw the border
  CGContextStrokeRect(context, insetBounds);
  
  // Start in the upper-left corner
  CGPoint textOrigin = CGPointMake(floor(CGRectGetMinX(insetBounds)),
                                     floor(CGRectGetMaxY(insetBounds)));

  CFIndex start = 0;
  NSUInteger length = CFAttributedStringGetLength(attributedString);
  while (start < length && textOrigin.y > insetBounds.origin.y) {
    // Calculate the line
    CTTypesetterRef typesetter = self.typesetter;
    CFIndex count = CTTypesetterSuggestLineBreak(typesetter, start, boundsWidth);
    CTLineRef line = CTTypesetterCreateLine(typesetter, CFRangeMake(start, count));
    
    // Fetch the typographic bounds
    CGFloat ascent;
    CGFloat descent;
    CGFloat leading;
    double lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    
    // Full-justify if the text isn't too short.
    if ((lineWidth / boundsWidth) > 0.85) {
      CTLineRef justifiedLine = CTLineCreateJustifiedLine(line, 1.0, boundsWidth);
      CFRelease(line);
      line = justifiedLine;
    }
    
    // Move forward to the baseline
    textOrigin.y -= ceil(ascent);
    CGContextSetTextPosition(context, textOrigin.x, textOrigin.y);
    
    // Get the CTRun list
    CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
    CFIndex runCount = CFArrayGetCount(glyphRuns);
    
    // Handle each glyph run
    for (CFIndex runIndex = 0; runIndex < runCount; ++runIndex) {
      // Set the font
      CTRunRef run = CFArrayGetValueAtIndex(glyphRuns, runIndex);
      CTFontRef runFont = CFDictionaryGetValue(CTRunGetAttributes(run),
                                               kCTFontAttributeName);
      CGFontRef cgFont = CTFontCopyGraphicsFont(runFont, NULL); // FIXME: We could optimize this by caching fonts we know we use.
      CGContextSetFont(context, cgFont);
      CGContextSetFontSize(context, CTFontGetSize(runFont));
      CFRelease(cgFont);
      
      CFIndex glyphCount = CTRunGetGlyphCount(run);
      
      // This is slightly dangerous. We're getting a pointer to the internal
      // data, and yes, we're modifying it. But it avoids copying the memory
      // in most cases, which can get expensive.
      CGPoint *positions = (CGPoint*)CTRunGetPositionsPtr(run);
      if (positions == NULL) {
        size_t positionsBufferSize = sizeof(CGPoint) * glyphCount;
        if (!positionsBuffer || malloc_size(positionsBuffer) < positionsBufferSize) {
          positionsBuffer = realloc(positionsBuffer, positionsBufferSize);
        }
        CTRunGetPositions(run, kRangeZero, positionsBuffer);
        positions = positionsBuffer;
      }
      
      // This one is less dangerous since we don't modify it, and we keep the const
      // to remind ourselves that it's not to be modified lightly.
      const CGGlyph *glyphs = CTRunGetGlyphsPtr(run);
      if (glyphs == NULL) {
        size_t glyphsBufferSize = sizeof(CGGlyph) * glyphCount;
        if (malloc_size(glyphsBuffer) < glyphsBufferSize) {
          glyphsBuffer = realloc(glyphsBuffer, glyphsBufferSize);
        }
        CTRunGetGlyphs(run, kRangeZero, (CGGlyph*)glyphs);
        glyphs = glyphsBuffer;
      }
      
      // Squeeze the text towards the touch-point
      if (touchIsActive) {
        for (CFIndex glyphIndex = 0; glyphIndex < glyphCount; ++glyphIndex) {
          positions[glyphIndex] = GetPinchedPointForPoint(positions[glyphIndex],
                                                          textOrigin,
                                                          touchPoint);
        }
      }
      
      CGContextShowGlyphsAtPositions(context, glyphs, positions, glyphCount);
    }
    
    // Move the index beyond the line break.
    start += count;
    textOrigin.y -= ceilf(descent + leading + 1); // +1 matches best to CTFramesetter's behavior
    CFRelease(line);
  }
  free(positionsBuffer);
  free(glyphsBuffer);
}

- (void)updateTouchPointWithTouch:(UITouch *)touch
{
  self.touchPoint = [touch locationInView:self];
  [self setNeedsDisplay];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  [self updateTouchPointWithTouch:[touches anyObject]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  [self updateTouchPointWithTouch:[touches anyObject]];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  self.touchPoint = CGPointZero;
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