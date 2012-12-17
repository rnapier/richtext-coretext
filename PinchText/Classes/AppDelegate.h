//
//  AppDelegate.h
//  Demonstrates PinchTextView
//

#import <UIKit/UIKit.h>

@class PinchTextView;
@interface AppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, readwrite, strong) IBOutlet UIWindow *window;
@property (nonatomic, readwrite, strong) IBOutlet PinchTextView *view;

@end

