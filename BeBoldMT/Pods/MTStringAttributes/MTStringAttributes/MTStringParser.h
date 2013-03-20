//
//  MTString.h
//  MTStringAttributes
//
//  Created by Adam Kirk on 2/12/13.
//  Copyright (c) 2013 Mysterious Trousers. All rights reserved.
//

#import "MTStringAttributes.h"


@interface MTStringParser : NSObject

+ (MTStringParser *)sharedParser;


#pragma mark - Set Styles

- (void)setDefaultAttributes:(MTStringAttributes *)attributes;

- (void)setAttributes:(MTStringAttributes *)attributes forTag:(NSString *)tag;


#pragma mark - Convenience

- (void)addStyleWithTagName:(NSString *)tagName font:(id)font;

- (void)addStyleWithTagName:(NSString *)tagName
                       font:(id)font
                      color:(id)color;

- (void)addStyleWithTagName:(NSString *)tagName
                       font:(id)font
                      color:(id)color
            backgroundColor:(id)backgroundColor
              strikethrough:(BOOL)strikethrough
                  underline:(BOOL)underline;


#pragma mark - Parse Markup To Attributed String

- (NSAttributedString *)attributedStringFromMarkup:(NSString *)markup;


@end
