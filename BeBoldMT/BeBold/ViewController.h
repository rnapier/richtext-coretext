//
//  ViewController.h
//  BeBold
//
//  Created by Rob Napier on 11/7/12.
//  Copyright (c) 2012 Rob Napier. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UITextView *textView;
- (IBAction)applyBold:(id)sender;

@end
