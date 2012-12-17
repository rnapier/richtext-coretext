//
//  PinchTextLayer.h
//  PinchText
//
//  Created by Rob Napier on 12/16/12.
//
//

#import <QuartzCore/QuartzCore.h>

@interface PinchTextLayer : CALayer
@property (nonatomic, readwrite, strong) NSAttributedString *attributedString;
@property (nonatomic, readwrite, strong) NSSet *touchPoints;
@property (nonatomic, readwrite, assign) CGFloat pinchScale;
@end
