//
//  PinchTextView.h
//  Displays an attributed string and pinches it towards touches.
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

@interface PinchTextView : UIView
@property (nonatomic, readwrite, copy) NSAttributedString *attributedString;
@end
