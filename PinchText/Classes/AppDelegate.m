//
//  TextDemoAppDelegate.m
//  Demonstrates PinchTextView
//

#import "AppDelegate.h"
#import "PinchTextView.h"

@implementation AppDelegate

- (id)randomValueFromArray:(NSArray *)array
{
  return array[arc4random_uniform(array.count)];
}

- (UIColor *)randomColor
{
  NSArray *colors = @[
  [UIColor blackColor],
  [UIColor darkGrayColor],
  [UIColor lightGrayColor],
  [UIColor grayColor],
  [UIColor redColor],
  [UIColor blueColor],
  [UIColor cyanColor],
  [UIColor magentaColor],
  [UIColor orangeColor],
  [UIColor purpleColor],
  [UIColor brownColor]];
  
  return [self randomValueFromArray:colors];
}

- (CGFloat)randomSize
{
  return arc4random_uniform(18) + 18;
}

- (UIFont *)randomFontWithSize:(CGFloat)size
{
  NSString *family = [self randomValueFromArray:[UIFont familyNames]];
  NSString *fontName = [self randomValueFromArray:[UIFont fontNamesForFamilyName:family]];
  return [UIFont fontWithName:fontName size:size];
}

- (NSAttributedString *)richTextForString:(NSString *)text
{
  UIFont *defaultFont = [UIFont systemFontOfSize:[UIFont systemFontSize]];
  NSDictionary *defaultAttributes = @{ NSFontAttributeName : defaultFont };

  NSMutableAttributedString *richText = [[NSMutableAttributedString alloc] initWithString:text
                                                                               attributes:defaultAttributes];

  NSMutableDictionary *attributes = [[richText attributesAtIndex:0 effectiveRange:NULL] mutableCopy];
  [richText.string enumerateSubstringsInRange:NSMakeRange(0, richText.length)
                                     options:NSStringEnumerationBySentences
                                  usingBlock:^(NSString *substring,
                                               NSRange substringRange,
                                               NSRange enclosingRange,
                                               BOOL *stop) {
                                    u_int32_t dice = arc4random_uniform(100);
                                    if (dice > 25) {
                                      if (dice < 50) {
                                        attributes[NSForegroundColorAttributeName] = [self randomColor];
                                      }
                                      else if (dice < 75) {
                                        UIFont *oldFont = attributes[NSFontAttributeName];
                                        attributes[NSFontAttributeName] = [oldFont fontWithSize:[self randomSize]];
                                      }
                                      else {
                                        UIFont *currentFont = attributes[NSFontAttributeName];
                                        attributes[NSFontAttributeName] = [self randomFontWithSize:currentFont.pointSize];
                                      }
                                    }
                                    [richText setAttributes:attributes range:substringRange];
                                  }];
  return richText;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  NSString *path = [[NSBundle mainBundle] pathForResource:@"Lipsum" ofType:@"txt"];
  NSString *text = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
  [self.view setAttributedString:[self richTextForString:text]];
  [self.window makeKeyAndVisible];
  return YES;
}

@end
