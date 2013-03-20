//
//  ViewController.m
//  BeBold
//
//  Created by Rob Napier on 11/7/12.
//  Copyright (c) 2012 Rob Napier. All rights reserved.
//

#import "ViewController.h"
#import <CoreText/CoreText.h>
#import "DTCoreText.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  NSData *html =
  [@"Be <strong>Bold!</strong> And a <span style='color:blue'>"
   @"<span style='font-size:18'>little</span> color</span> wouldn’t hurt either."
   dataUsingEncoding:NSUTF8StringEncoding];

  NSAttributedString *as = [[NSAttributedString alloc] initWithHTMLData:html
                                                                options:@{
                                                    DTDefaultFontFamily:@"Helvetica",
                                                      DTDefaultFontSize: @36,
                                                    DTUseiOS6Attributes: @YES}
                                                     documentAttributes:nil];
  self.label.attributedText = as;

  //=====

  NSString *paragraphs = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi ac urna id augue volutpat tempus at vitae libero. Donec venenatis faucibus erat, et feugiat nunc dignissim sed. Curabitur egestas quam ut ante tincidunt dignissim. Nunc non nulla eros. Donec elementum auctor augue, dapibus blandit augue sollicitudin in. Proin dictum, neque sit amet venenatis facilisis, orci ligula vestibulum dolor, non pulvinar ipsum magna quis leo. Mauris id magna dui. In vehicula gravida mattis. Aliquam semper purus quis enim feugiat sit amet dapibus nunc ultrices. Nam nec lacus et quam molestie viverra sed sit amet orci. Fusce laoreet pulvinar libero, eget commodo urna scelerisque vel. Aenean eget lectus in quam scelerisque blandit vel in ligula. Etiam ac urna sagittis risus lobortis viverra varius ac enim. Maecenas hendrerit, tellus quis tristique dignissim, nibh libero pretium dolor, non pellentesque est nibh at erat.\n"
  @"Integer eget enim at erat rhoncus volutpat a sit amet ligula. Suspendisse potenti. Curabitur faucibus vulputate nibh vel condimentum. Mauris tortor arcu, tincidunt sit amet auctor nec, consectetur vel ipsum. Proin vitae magna risus, non aliquam tortor. Nunc ut purus eu diam semper laoreet. Sed accumsan ante id elit imperdiet a vehicula nunc dapibus. Nam risus augue, tempor ut dictum at, euismod sit amet ipsum. Integer et facilisis ipsum. In nulla felis, feugiat in ultrices bibendum, fringilla quis est. Curabitur eleifend rhoncus turpis sed luctus. Donec sed nisi orci. Nam rutrum volutpat nibh, in blandit lectus ultricies eget.\n"
  @"Suspendisse potenti. Ut eu mi elit, eu tincidunt mauris. Nullam ut egestas ante. Proin suscipit convallis nisi sed convallis. Nullam convallis posuere venenatis. Curabitur in mauris nulla, in tempus est. Etiam augue metus, viverra eget cursus interdum, malesuada eu nisl. Nunc vel nibh sit amet purus blandit malesuada. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse ipsum arcu, facilisis vitae fringilla vitae, luctus non dui. Donec sit amet mauris non urna auctor tincidunt sit amet at massa. Vestibulum tempus viverra sem, quis tempor ante feugiat quis. Etiam ac ultrices diam. Duis laoreet nulla quis nibh condimentum tempus. Nullam rutrum vehicula neque, vitae tincidunt ante aliquam vel. Maecenas vel dapibus augue.";

  NSMutableParagraphStyle *wholeDocStyle = [[NSMutableParagraphStyle alloc] init];
  [wholeDocStyle setParagraphSpacing:34.0];
  [wholeDocStyle setFirstLineHeadIndent:10.0];
  [wholeDocStyle setAlignment:NSTextAlignmentJustified];

  NSMutableAttributedString *
  pas = [[NSMutableAttributedString alloc] initWithString:paragraphs
                                               attributes:
         @{NSParagraphStyleAttributeName: wholeDocStyle}];

  NSUInteger secondParagraphStart = NSMaxRange([pas.string rangeOfString:@"\n"]);

  NSMutableParagraphStyle *secondParagraphStyle = [[pas attribute:NSParagraphStyleAttributeName
                                                          atIndex:secondParagraphStart
                                                   effectiveRange:NULL] mutableCopy];
  secondParagraphStyle.headIndent += 50.0;
  secondParagraphStyle.firstLineHeadIndent += 50.0;
  secondParagraphStyle.tailIndent -= 50.0;

  [pas addAttribute:NSParagraphStyleAttributeName
              value:secondParagraphStyle
              range:NSMakeRange(secondParagraphStart, 1)];

  self.textView.attributedText = pas;
}

// Returns the bold version of a font. May return nil if there is no bold version.
UIFont *RNGetBoldFontForFont(UIFont *font) {
  UIFont *result = nil;

  CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef)(font.fontName),
                                          font.pointSize, NULL);
  if (ctFont) {
    // You can't add bold to a bold font
    // (don't really need this, since the ctBoldFont check would handle it)
    if ((CTFontGetSymbolicTraits(ctFont) & kCTFontTraitBold) == 0) {
      CTFontRef ctBoldFont = CTFontCreateCopyWithSymbolicTraits(ctFont,
                                                                font.pointSize,
                                                                NULL,
                                                                kCTFontBoldTrait,
                                                                kCTFontBoldTrait);
      if (ctBoldFont) {
        NSString *fontName = CFBridgingRelease(CTFontCopyPostScriptName(ctBoldFont));
        result = [UIFont fontWithName:fontName size:font.pointSize];
        CFRelease(ctBoldFont);
      }
    }
    CFRelease(ctFont);
  }
  return result;
}

- (IBAction)applyBold:(id)sender {
  NSMutableAttributedString *as = [self.label.attributedText mutableCopy];

  [as enumerateAttribute:NSFontAttributeName
                 inRange:NSMakeRange(0, as.length)
                 options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
              usingBlock:^(id value, NSRange range, BOOL *stop)
   {
     UIFont *font = value;
     UIFont *boldFont = RNGetBoldFontForFont(font);
     if (boldFont) {
       [as addAttribute:NSFontAttributeName value:boldFont range:range];
     }
   }];

  self.label.attributedText = as;
}
@end
