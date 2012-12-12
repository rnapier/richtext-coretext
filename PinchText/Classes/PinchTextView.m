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

CGPoint GetPinchedPointForPoint(CGRect bounds, CGPoint point, CGPoint textOrigin, CGPoint touchPoint) {
  // Text space -> view space
  CGPoint pinchedPoint = point;
  pinchedPoint.x += textOrigin.x;
  pinchedPoint.y += textOrigin.y;
  
  CGFloat r_touch = sqrtf(hypotf(pinchedPoint.x - touchPoint.x,
                           pinchedPoint.y - touchPoint.y));
  CGFloat theta_touch = atan2f(pinchedPoint.y - touchPoint.y,
                         pinchedPoint.x - touchPoint.x);
    
  CGFloat d_minX = pinchedPoint.x;
  CGFloat d_maxX = CGRectGetMaxX(bounds) - pinchedPoint.x;
  CGFloat d_minY = pinchedPoint.y;
  CGFloat d_maxY = CGRectGetMaxY(bounds) - pinchedPoint.y;
  
  CGPoint closestEdge;
  if (d_minX <= d_maxX && d_minX <= d_minY && d_minX <= d_maxY) {
    closestEdge = CGPointMake(CGRectGetMinX(bounds), pinchedPoint.y);
  }
  else if (d_maxX <= d_minY && d_maxX <= d_maxY) {
    closestEdge = CGPointMake(CGRectGetMaxX(bounds), pinchedPoint.y);
  }
  else if (d_minY <= d_maxY) {
    closestEdge = CGPointMake(pinchedPoint.x, CGRectGetMinY(bounds));
  }
  else {
    closestEdge = CGPointMake(pinchedPoint.x, CGRectGetMaxY(bounds));
  }
  
  CGFloat r_edge = sqrtf(hypotf(pinchedPoint.x - closestEdge.x,
                                pinchedPoint.y - closestEdge.y));
  
  CGFloat scale = 0.5;
  CGFloat multiplier = (1.f/r_touch) * scale * r_edge * r_edge;
  pinchedPoint.x -= cosf(theta_touch) * multiplier;
  pinchedPoint.y -= sinf(theta_touch) * multiplier;

  // view space -> text space
  pinchedPoint.x -= textOrigin.x;
  pinchedPoint.y -= textOrigin.y;
  
  return pinchedPoint;
}

void UpdatePositions(CGPoint *positions, NSUInteger count, CGPoint textOrigin, NSSet *touchPoints, CGRect bounds) {
  static CGFloat *adjust = NULL;
  size_t adjustSize = sizeof(CGPoint) * count;
  if (!adjust || malloc_size(adjust) < adjustSize) {
    adjust = realloc(adjust, adjustSize);
  }
  
  float *xStart = (float *)positions;
  float *yStart = xStart + 1;
  CGFloat scale = 500;
  CGFloat highClip = 20;
  CGFloat lowClip = -highClip;

  // Text space -> view space
  vDSP_vsadd(xStart, 2, &(textOrigin.x), xStart, 2, count);
  vDSP_vsadd(yStart, 2, &(textOrigin.y), yStart, 2, count);
  
  for (NSValue *touchPointValue in touchPoints) {
    memcpy(adjust, positions, sizeof(CGPoint) * count);
    CGPoint touchPoint = [touchPointValue CGPointValue];

    float negTouchPointX = -touchPoint.x;
    float negTouchPointY = -touchPoint.y;
    vDSP_vsadd(adjust, 2, &negTouchPointX, adjust, 2, count);
    vDSP_vsadd(adjust + 1, 2, &negTouchPointY, adjust + 1, 2, count);
  
    vDSP_polar(adjust, 2, adjust, 2, count);
    
    vDSP_svdiv(&scale, adjust, 2, adjust, 2, count);
    
    vDSP_vclip(adjust, 2, &lowClip, &highClip, adjust, 2, count);
    
    vDSP_rect(adjust, 2, adjust, 2, count);
  
    vDSP_vsub(adjust, 1, (float*)positions, 1, (float*)positions, 1, count * 2);
  }
  
  // view space -> text space
  textOrigin.x = -textOrigin.x;
  textOrigin.y = -textOrigin.y;
  vDSP_vsadd(xStart, 2, &(textOrigin.x), xStart, 2, count);
  vDSP_vsadd(yStart, 2, &(textOrigin.y), yStart, 2, count);
  
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
  NSSet *touchPoints = self.touchPoints;
  BOOL touchIsActive = (touchPoints != nil);
  
  // Work out the geometry
  CGRect insetBounds = CGRectInset([self bounds], 40.0, 40.0);
  CGFloat boundsWidth = CGRectGetWidth(insetBounds);

  // Draw the border
  CGContextStrokeRect(context, insetBounds);
  
  // Start in the upper-left corner
  CGPoint textOrigin = CGPointMake(CGRectGetMinX(insetBounds),
                                   CGRectGetMaxY(insetBounds));


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
    textOrigin.y -= ascent;
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
        UpdatePositions(positions, glyphCount, textOrigin, touchPoints, insetBounds);
      }
      
      CGContextShowGlyphsAtPositions(context, glyphs, positions, glyphCount);
    }
    
    // Move the index beyond the line break.
    start += count;
    textOrigin.y -= descent + leading + 1; // +1 matches best to CTFramesetter's behavior
    CFRelease(line);
  }
  free(positionsBuffer);
  free(glyphsBuffer);
}

- (void)updateTouchPointWithTouches:(NSSet *)touches
{
  NSMutableSet *points = [NSMutableSet new];
  [touches enumerateObjectsUsingBlock:^(UITouch *touch, BOOL *stop) {
    [points addObject:[NSValue valueWithCGPoint:[touch locationInView:self]]];
  }];
  
  self.touchPoints = points;
  [self setNeedsDisplay];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  [self updateTouchPointWithTouches:[event allTouches]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  [self updateTouchPointWithTouches:[event allTouches]];
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