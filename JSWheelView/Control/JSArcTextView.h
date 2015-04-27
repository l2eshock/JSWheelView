//
//  JSArcTextView.h
//  JSWheelView
//
//  Created by JoAmS on 2015. 4. 21..
//  Copyright (c) 2015년 jooam. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    JSArcTextTypeVerticalAlignOutside,
    JSArcTextTypeVerticalAlignCenter,
    JSArcTextTypeVerticalAlignInside
} JSArcTextTypeVerticalAlignment;

@interface JSArcTextView : UIView

@property (strong, nonatomic) NSString *text;
@property (strong, nonatomic) NSDictionary *textAttributes;
@property (nonatomic) NSTextAlignment textAlignment;
@property (nonatomic) JSArcTextTypeVerticalAlignment verticalTextAlignment;
@property (nonatomic) float radius;
@property (nonatomic) float baseAngle;
@property (nonatomic) float characterSpacing;
@property (nonatomic) BOOL disableKerningCache;
- (void)clearKerningCache;
- (void) setColor:(UIColor *)color;
@end
