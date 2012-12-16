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

- (id)randomValueFromArray:(NSArray *)array {
  return array[arc4random_uniform(array.count)];
}

- (UIColor *)randomColor {
  NSArray *colors = @[
  [UIColor blackColor],
  [UIColor darkGrayColor],
  [UIColor lightGrayColor],
  [UIColor grayColor],
  [UIColor redColor],
  [UIColor greenColor],
  [UIColor blueColor],
  [UIColor cyanColor],
  [UIColor magentaColor],
  [UIColor orangeColor],
  [UIColor purpleColor],
  [UIColor brownColor]];
  
  return [self randomValueFromArray:colors];
}

- (CGFloat)randomSize {
  return arc4random_uniform(18) + 18;
}

- (UIFont *)randomFontWithSize:(CGFloat)size {
  NSString *family = [self randomValueFromArray:[UIFont familyNames]];
  NSString *fontName = [self randomValueFromArray:[UIFont fontNamesForFamilyName:family]];
  return [UIFont fontWithName:fontName size:size];
}

- (void)adjustText:(NSMutableAttributedString *)astring {
  NSMutableDictionary *attributes = [[astring attributesAtIndex:0 effectiveRange:NULL] mutableCopy];
  [astring.string enumerateSubstringsInRange:NSMakeRange(0, astring.length)
                                     options:NSStringEnumerationByWords
                                  usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                    u_int32_t dice = arc4random_uniform(100);
                                    if (dice > 75) {
                                      if (dice < 90) {
                                        attributes[NSForegroundColorAttributeName] = [self randomColor];
                                      }
                                      else if (dice < 95) {
                                        attributes[NSFontAttributeName] = [attributes[NSFontAttributeName] fontWithSize:[self randomSize]];
                                      }
                                      else {
                                        UIFont *currentFont = attributes[NSFontAttributeName];
                                        attributes[NSFontAttributeName] = [self randomFontWithSize:currentFont.pointSize];
                                      }
                                    }
                                    [astring setAttributes:attributes range:substringRange];
                                  }];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	
	// Override point for customization after application launch
  
	[self.window makeKeyAndVisible];
  
  NSMutableAttributedString *astring = [[NSMutableAttributedString alloc] initWithString:kLipsum
                                                                              attributes:@{
                                                                     NSFontAttributeName:[UIFont systemFontOfSize:[UIFont systemFontSize]]}];

  [self adjustText:astring];
	[self.view setAttributedString:astring];
  
  return YES;
}

- (void)dealloc {
	mView = nil;
	mWindow = nil;
}


@end
