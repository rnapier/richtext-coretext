//
//  MTString.m
//  MTStringAttributes
//
//  Created by Adam Kirk on 2/12/13.
//  Copyright (c) 2013 Mysterious Trousers. All rights reserved.
//

#import "MTStringParser.h"
#import <SLSMarkupParser.h>


@interface MTStringParser ()
@property (strong, nonatomic) NSMutableDictionary *styles;
@end


@implementation MTStringParser


- (id)init
{
    self = [super init];
    if (self) {
        _styles = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (MTStringParser *)sharedParser
{
    static MTStringParser *__parser = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __parser = [[MTStringParser alloc] init];
    });
    return __parser;
}



#pragma mark - Set Styles

- (void)setDefaultAttributes:(MTStringAttributes *)attributes
{
    _styles[@"$default"] = [attributes dictionary];
}

- (void)setAttributes:(MTStringAttributes *)attributes forTag:(NSString *)tag
{
    _styles[tag] = [attributes dictionary];
}



#pragma mark - Convenience

- (void)addStyleWithTagName:(NSString *)tagName font:(id)font
{
    MTStringAttributes *attributes = [[MTStringAttributes alloc] init];
    attributes.font = font;
    [self setAttributes:attributes forTag:tagName];
}

- (void)addStyleWithTagName:(NSString *)tagName
                       font:(id)font
                      color:(id)color
{
    MTStringAttributes *attributes = [[MTStringAttributes alloc] init];
    attributes.font         = font;
    attributes.textColor    = color;
    [self setAttributes:attributes forTag:tagName];
}

- (void)addStyleWithTagName:(NSString *)tagName
                       font:(id)font
                      color:(id)color
            backgroundColor:(id)backgroundColor
              strikethrough:(BOOL)strikethrough
                  underline:(BOOL)underline
{
    MTStringAttributes *attributes      = [[MTStringAttributes alloc] init];
    attributes.font                     = font;
    attributes.textColor                = color;
    attributes.backgroundColor          = backgroundColor;
    attributes.strikethrough            = strikethrough;
    attributes.underline                = underline;
    [self setAttributes:attributes forTag:tagName];
}


#pragma mark - Parse Markup To Attributed String

- (NSAttributedString *)attributedStringFromMarkup:(NSString *)markup
{
    NSError *error = nil;
    NSAttributedString *string = [SLSMarkupParser attributedStringWithMarkup:markup style:_styles error:&error];
    if (error) NSLog(@"%@", [error localizedDescription]);
    return string;
}


@end
