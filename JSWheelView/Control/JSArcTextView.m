//
//  JSArcTextView.m
//  JSWheelView
//
//  Created by JoAmS on 2015. 4. 21..
//  Copyright (c) 2015년 jooam. All rights reserved.
//

#import "JSArcTextView.h"

@interface JSArcTextView (){
    NSMutableDictionary* _textAttributes;
}
@property (nonatomic) CGPoint circleCenterPoint;
@property (strong,nonatomic) NSMutableDictionary *kerningCacheDictionary;
@end

@implementation JSArcTextView
@synthesize textAttributes = _textAttributes;

- (id)init
{
    self = [super init];
    if (self) {
        [self initialize];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initialize];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initialize];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layoutSubviews
{
    self.circleCenterPoint = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    //Check baseAngle in 0 ~ 180
    BOOL isMirrored = NO;
    if(self.baseAngle > 0 && self.baseAngle < M_PI){
        isMirrored = YES;
    }
    
    //Get the string size.
	CGSize stringSize = [self.text sizeWithAttributes:_textAttributes];
//	CGSize stringSize = [self.text sizeWithAttributesForAlliOS:_textAttributes];
	
    //If the radius not set, calculate the maximum radius.
    float radius = (self.radius <=0) ? [self maximumRadiusWithStringSize:stringSize andVerticalAlignment:self.verticalTextAlignment] : self.radius;
    
    //We store both radius and textRadius. Since we might need an
    //unadjusted radius for visual debugging.
    float textRadius = radius;
    
    //Handle vertical alignment bij adjusting the textRadius;
    if (self.verticalTextAlignment == JSArcTextTypeVerticalAlignInside) {
        textRadius = textRadius - stringSize.height;
    } else if (self.verticalTextAlignment == JSArcTextTypeVerticalAlignCenter) {
        if(isMirrored){
            textRadius = textRadius + stringSize.height/2;
        }
        else{
            textRadius = textRadius - stringSize.height/2;
        }
    }
    
    //Calculate the angle per charater.
    self.characterSpacing = (self.characterSpacing > 0) ? self.characterSpacing : 1;
    float circumference = 2 * textRadius * M_PI;
    float anglePerPixel = M_PI * 2 / circumference * self.characterSpacing;
    
    //Set initial angle.
    float startAngle;
    if (self.textAlignment == NSTextAlignmentRight) {
        startAngle = self.baseAngle - (stringSize.width * anglePerPixel);
    } else if(self.textAlignment == NSTextAlignmentLeft) {
        startAngle = self.baseAngle;
    } else {
        startAngle = self.baseAngle - (stringSize.width * anglePerPixel/2);
    }
    
    //Set drawing context.
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //Set helper vars.
    float characterPosition = 0;
    NSString *lastCharacter;
    
    //Loop thru characters of string.
    for (NSInteger charIdx=(isMirrored)?self.text.length-1:0; (isMirrored)?charIdx>=0:charIdx<self.text.length; (isMirrored)?charIdx--:charIdx++) {
        
        //Set current character.
        NSString *currentCharacter = [self.text substringWithRange:NSMakeRange(charIdx, 1)];
        
        //Set currenct character size & kerning.
		CGSize stringSize = [currentCharacter sizeWithAttributes:_textAttributes];
//		CGSize stringSize = [currentCharacter sizeWithAttributesForAlliOS:_textAttributes];
		
        float kerning = (lastCharacter) ? [self kerningForCharacter:currentCharacter afterCharacter:lastCharacter] : 0;
        
        //Add half of character width to characterPosition, substract kerning.
        characterPosition += (stringSize.width / 2) - kerning;
        
        //Calculate character Angle
        float angle = characterPosition * anglePerPixel + startAngle;
        
        //Calculate character drawing point.
        CGPoint characterPoint = CGPointMake(textRadius * cos(angle) + self.circleCenterPoint.x, textRadius * sin(angle) + self.circleCenterPoint.y);
        
        //Strings are always drawn from top left. Calculate the right pos to draw it on bottom center.
        CGPoint stringPoint = CGPointMake(characterPoint.x -stringSize.width/2 , characterPoint.y - stringSize.height);
        
        //Result Angle
        float resultAngle = (isMirrored)?(angle + M_PI_2 + M_PI):(angle + M_PI_2);
        
        //Save the current context and do the character rotation magic.
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, characterPoint.x, characterPoint.y);
        CGAffineTransform textTransform = CGAffineTransformMakeRotation(resultAngle);
        CGContextConcatCTM(context, textTransform);
        CGContextTranslateCTM(context, -characterPoint.x, -characterPoint.y);
        
        //Draw the character
        [currentCharacter drawAtPoint:stringPoint withAttributes:_textAttributes];
//        if(IS_IOS6){
//            UIColor* textColor = (UIColor*)[_textAttributes objectForKey:NSForegroundColorAttributeName];
//            if(textColor){
//                CGContextSetFillColorWithColor(context, textColor.CGColor);
//            }
//        }
//		[currentCharacter drawAtPointAlliOS:stringPoint withAttributes:_textAttributes];
		
        //Restore context to make sure the rotation is only applied to this character.
        CGContextRestoreGState(context);
        
        //Add the other half of the character size to the character position.
        characterPosition += stringSize.width / 2;
        
        //Stop if we've reached one full circle.
        if (characterPosition * anglePerPixel >= M_PI*2) break;
        
        //store the currentCharacter to use in the next run for kerning calculation.
        lastCharacter = currentCharacter;
    }
}

#pragma mark - Private Functions

- (void)initialize
{
    self.backgroundColor = [UIColor clearColor];
    self.verticalTextAlignment = JSArcTextTypeVerticalAlignOutside;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMemoryWarning) name: UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

- (void)handleMemoryWarning
{
    [self clearKerningCache];
}

- (float)kerningForCharacter:(NSString *)currentCharacter afterCharacter:(NSString *)previousCharacter
{
    //Create a unique cache key
    NSString *kerningCacheKey = [NSString stringWithFormat:@"%@%@", previousCharacter, currentCharacter];
    
    //Look for kerning in the cache dictionary
    NSNumber *cachedKerning = [self.kerningCacheDictionary objectForKey:kerningCacheKey];
    
    //If kerning is found: return.
    if (cachedKerning) {
        return [cachedKerning floatValue];
    }
    
    //Otherwise, calculate.
    float totalSize = [[NSString stringWithFormat:@"%@%@", previousCharacter, currentCharacter] sizeWithAttributes:_textAttributes].width;
//	float totalSize = [[NSString stringWithFormat:@"%@%@", previousCharacter, currentCharacter] sizeWithAttributesForAlliOS:self.textAttributes].width;
	
    float currentCharacterSize = [currentCharacter sizeWithAttributes:_textAttributes].width;
    float previousCharacterSize = [previousCharacter sizeWithAttributes:_textAttributes].width;
    
    float kerning = (currentCharacterSize + previousCharacterSize) - totalSize;
    
    //Store kerning in cache.
    [self.kerningCacheDictionary setValue:@(kerning) forKey:kerningCacheKey];
    
    //Return kerning.
    return kerning;
}

- (float)maximumRadiusWithStringSize:(CGSize)stringSize andVerticalAlignment:(JSArcTextTypeVerticalAlignment)verticalTextAlignment;
{
    float radius = (self.bounds.size.width <= self.bounds.size.height) ? self.bounds.size.width / 2: self.bounds.size.height / 2;
    
    if (verticalTextAlignment == JSArcTextTypeVerticalAlignOutside) {
        radius = radius - stringSize.height;
    } else if (verticalTextAlignment == JSArcTextTypeVerticalAlignCenter) {
        radius = radius - stringSize.height/2;
    }
    
    return radius;
}

#pragma mark - Public Functions

- (void)clearKerningCache
{
    self.kerningCacheDictionary = nil;
}

- (void)setColor:(UIColor *)color
{
    UIColor* presentColor = [_textAttributes valueForKey:NSForegroundColorAttributeName];
    if(!CGColorEqualToColor(presentColor.CGColor, color.CGColor)){
        [_textAttributes setValue:color forKey:NSForegroundColorAttributeName];
        [self setNeedsDisplay];
    }
}

#pragma mark - Getters & Setters

-(NSMutableDictionary *)kerningCacheDictionary
{
    if (self.disableKerningCache) return nil;
    
    if (!_kerningCacheDictionary) _kerningCacheDictionary = [NSMutableDictionary new];
    return _kerningCacheDictionary;
}

- (void)setText:(NSString *)text
{
    _text = text;
    [self setNeedsDisplay];
}

- (void)setTextAttributes:(NSDictionary *)textAttributes
{
    _textAttributes = [textAttributes mutableCopy];
    
    //since the characteristics of the font changed, we need to fluch the kerning cache.
    [self clearKerningCache];
    [self setNeedsDisplay];
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment
{
    _textAlignment = textAlignment;
    [self setNeedsDisplay];
}

- (void) setVerticalTextAlignment:(JSArcTextTypeVerticalAlignment)verticalTextAlignment
{
    _verticalTextAlignment = verticalTextAlignment;
    [self setNeedsDisplay];
}

-(void)setRadius:(float)radius
{
    _radius = radius;
    [self setNeedsDisplay];
}

- (void)setBaseAngle:(float)baseAngle
{
    _baseAngle = baseAngle;
    [self setNeedsDisplay];
}

- (void)setCharacterSpacing:(float)characterSpacing
{
    _characterSpacing = characterSpacing;
    [self setNeedsDisplay];
}

@end
