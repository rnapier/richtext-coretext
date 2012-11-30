//
//  TextDemoAppDelegate.m
//  TextDemo
//
//  Created by Rob on 9/7/10.
//  Copyright My Company 2010. All rights reserved.
//

#import "AppDelegate.h"
#import <CoreText/CoreText.h>
#import "PinchTextView.h"

@implementation AppDelegate

@synthesize window = mWindow;
@synthesize view = mView;

static NSString *kLipsum;

+ (void)initialize
{
	if ([self class] == [AppDelegate class])
	{
		kLipsum = [[NSString alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Lipsum" ofType:@"txt"] encoding:NSUTF8StringEncoding error:NULL];
	}
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
	
	// Override point for customization after application launch

	[self.window makeKeyAndVisible];
		
	[self.view setAttributedString:[[NSAttributedString alloc] initWithString:kLipsum
                                                                 attributes:
                                  @{NSFontAttributeName:
                                  [UIFont systemFontOfSize:[UIFont systemFontSize]]}]];
    
    return YES;
}

- (void)dealloc {
	mView = nil;
	mWindow = nil;
}


@end
