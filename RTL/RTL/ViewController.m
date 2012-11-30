//
//  ViewController.m
//  RTL
//
//  Created by Rob Napier on 11/9/12.
//  Copyright (c) 2012 Rob Napier. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
  [super viewDidLoad];

  NSString *format1 = @"Hello, %@. How are you?";
  
  self.label1e.text = [NSString stringWithFormat:format1, @"John"];
  self.label1a.text = [NSString stringWithFormat:format1, @"سمير"];

  NSString *format2 = @"%@, how are you?";
  self.label2e.text = [NSString stringWithFormat:format2, @"John"];
  self.label2a.text = [NSString stringWithFormat:format2, @"سمير"];
  
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

@end
