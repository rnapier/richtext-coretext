MTStringAttributes
==================

An easier way to create an attributes dictionary for NSAttributedString


## Installation

In your Podfile, add this line:

    pod "MTStringAttributes"

pod? => https://github.com/CocoaPods/CocoaPods/


## Example Usage

    #include <MTStringAttributes.h>

Create an attributes object

    MTStringAttributes *attributes = [[MTStringAttributes alloc] init];

Set some basic properties

    attributes.font             = nil;
    attributes.textColor        = [UIColor redColor];
    attributes.backgroundColor  = [UIColor blackColor];
    attributes.strikethrough    = YES;
    attributes.underline        = YES;

Some more advanced stuff

    attributes.ligatures        = YES;
    attributes.kern             = @(1);
    attributes.outlineColor     = [UIColor blueColor];
    attributes.outlineWidth     = @(2);

I might break out the properties for paragraph style later, but for now, provide an object

    NSParagraphStyle *ps        = [[NSParagraphStyle alloc] init]
    ps.alignment                = NSTextAlignmentLeft;
    attributes.paragraphStyle   = ps;

Shadow

    attributes.shadowBlurRadius = @(1.4);
    attributes.shadowColor      = [UIColor grayColor];
    attributes.shadowOffsetX    = @(0.2);
    attributes.shadowOffsetY    = @(0.3);

Finally

    NSAttributedString *str     = [[NSAttributedString alloc] initWithString:@"The attributed string!"
                                                                  attributes:[attributes dictionary]];


## Parser


Relying on [Slash](https://github.com/chrisdevereux/Slash), MTStringParser allows you to add styles to
tags and then generate attributed strings from markup of those tags.

```
#include <MTStringParser.h>

[[MTStringParser sharedParser] addStyleWithTagName:@"red"
                                              font:[UIFont systemFontOfSize:12]
                                             color:[UIColor redColor]];

NSAttributedString *string = [[MTStringParser sharedParser]
                                attributedStringFromMarkup:@"This is a <red>red section</red>"];
```

###And like a beautiful symphony, they work together like so:

Easily create a string attributes object

    MTStringAttributes *attributes  = [[MTStringAttributes alloc] init];
    attributes.font                 = [UIFont fontWithName:@"HelveticaNeue" size:14];
    attributes.textColor            = [UIColor blackColor];

Add this as the default for the whole string we're about to parse

    [[MTStringParser sharedParser] setDefaultAttributes:attributes];

Define a style for a tag called `<relative-time>` that uses this font and has this color:

    [[MTStringParser sharedParser] addStyleWithTagName:@"relative-time"
                                                  font:[UIFont fontWithName:@"HelveticaNeue-Bold" size:14]
                                                 color:[UIColor colorWithRed:215.0/255.0 green:0 blue:0 alpha:1]];

And easily add another tag that has a font, color, background color and is underlined:

    [[MTStringParser sharedparser] addStyleWithTagName:@"em"
                                                  font:[UIFont systemFontOfSize:14]
                                                 color:[UIColor whiteColor]
                                       backgroundColor:[UIColor blackColor]
                                         strikethrough:NO
                                             underline:YES];

Now write the markup using the tags you defined styles for:

    NSString *markup = [NSString stringWithFormat:@"You can have a <em>complex<em> string that  \
    uses <em>tags</em> to define where you want <em>styles</em> to be defined. You needed       \
    this <relative-time>%@</relative-time>.", timeAgo];

And (  ( (BOOM) )  ), your attributed string:

    NSAttributedString *attributedString = [[MTStringParser sharedParser] attributedStringFromMarkup:markup];

## Contributing

Please update and run the tests before submitting a pull request. Thanks.

## Author

[Adam Kirk](https://github.com/atomkirk) ([@atomkirk](https://twitter.com/atomkirk))
