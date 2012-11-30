//
//  TextDemoAppDelegate.h
//  TextDemo
//
//  Created by Rob on 9/7/10.
//  Copyright My Company 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PinchTextView;
@interface AppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, readwrite, strong) IBOutlet UIWindow *window;
@property (nonatomic, readwrite, strong) IBOutlet PinchTextView *view;

@end

