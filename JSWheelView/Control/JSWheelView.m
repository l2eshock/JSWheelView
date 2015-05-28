//
//  JSWheelView.m
//  JSWheelView
//
//  Created by JoAmS on 2015. 4. 1..
//  Copyright (c) 2015년 jooam. All rights reserved.
//

#import "JSWheelView.h"
#import "JSArcTextView.h"
#import <AudioToolbox/AudioServices.h>

#define SHOW_HANDLE_SHADOW_MASK 1

#define MAXANGLE 360
#define START_ANGLE 90
#define SKIP_FRAME_COUNT 2

#if TARGET_IPAD
#define HANDLE_WIDTH 38
#define INNER_CIRCLE_WIDTH 8
#define TOUCHABLE_WIDTH 38
#define HANDLE_MASK_PADDING 1.2
#define HANDLE_SHADOW_WIDTH 180
#else
#define HANDLE_WIDTH 26
#define INNER_CIRCLE_WIDTH 4
#define TOUCHABLE_WIDTH 26
#define HANDLE_MASK_PADDING 1
#define HANDLE_SHADOW_WIDTH 120
#endif

typedef enum{
    kWheelTrackingType_None,
    kWheelTrackingType_OutSide,
    kWheelTrackingType_Inside,
}kWheelTrackingType;

@interface JSWheelSectionData : NSObject
@property (nonatomic, strong) NSString* sectionTitle;
@property (nonatomic, strong) NSMutableArray* datas;
@end

@implementation JSWheelSectionData
@synthesize sectionTitle = _sectionTitle;
@synthesize datas = _datas;
@end

@implementation NSIndexPath (JSWheelView)
- (BOOL)isEqual:(NSIndexPath*)object
{
    if([object isKindOfClass:[NSIndexPath class]]){
        if(self.row == object.row && self.section == object.section){
            return YES;
        }
    }
    return NO;
}
- (NSString *)description
{
    return [NSString stringWithFormat:@"%p section = %d, row = %d", self, self.section, self.row];
}
@end

@interface JSWheelView ()
{
    float _radius;
    float _angle;
    NSIndexPath* _currentIndexPath;
    CGPoint _prevTouchLocation;
    UIFont* _titleFont;
    UIColor* _titleColorForNormal;
    UIColor* _titleColorForHighlight;
    float _handleShadowPadding;
    CGPoint _centerPoint;
    int _skipFrame;
    BOOL _isBeginTracking;
    kWheelTrackingType _trackingType;
    BOOL _isHandleHidden;
    
    // layers
    CAShapeLayer* _backgroundCircleLayer;
    CAGradientLayer* _innerBackgroundLayer;
    CALayer* _maskLayer;
    CAShapeLayer* _innerCircleMaskLayer;
    CAShapeLayer* _handleShadowMaskLayer;
    CAGradientLayer* _handleShadowInnerMaskLayer;
    CAShapeLayer* _handleMaskLayer;
    //variable to check whether wheel loaded from loadData.
    BOOL isLoadedDataForWheel;
    
    float _startAngle;
    float distance_beginTracking;
    
}
@property (nonatomic, strong) NSMutableArray* datas;
@property (nonatomic, strong) NSMutableArray* sectionTitles;
- (void)loadDatas;
@end

@implementation JSWheelView
@synthesize dataSource = _dataSource;
@synthesize delegate = _delegate;
@synthesize isHaptic = _isHaptic;
@synthesize showSectionAndRow = _showSectionAndRow;
@synthesize centerImageLayer = _centerImageLayer;
@synthesize datas = _datas;
@synthesize sectionTitles = _sectionTitles;
@synthesize isWheelTracking = _isWheelTracking;
@synthesize disableOuterTracking = _disableOuterTracking;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setBackgroundColor:[UIColor clearColor]];
        _datas = [NSMutableArray new];
        _sectionTitles = [NSMutableArray new];
        _radius = (MIN(self.frame.size.width, self.frame.size.height)/2) - (HANDLE_WIDTH + (INNER_CIRCLE_WIDTH*2));
        _titleFont = [UIFont systemFontOfSize:12];
        _titleColorForNormal = [UIColor grayColor];
        _titleColorForHighlight = [UIColor whiteColor];
        _centerPoint = CGPointMake(self.frame.size.width/2, self.frame.size.height/2);
        _startAngle = START_ANGLE;
        distance_beginTracking=0;
    }
    isLoadedDataForWheel=YES;
    return self;
}

#pragma mark - Draw Layers
- (void)drawBackgroundCircleLayer
{
    if(_backgroundCircleLayer == nil){
        _backgroundCircleLayer = [CAShapeLayer layer];
        _backgroundCircleLayer.backgroundColor = [UIColor colorWithRed:0.f green:0.f blue:0.f alpha:0.2f].CGColor;
        _backgroundCircleLayer.masksToBounds = YES;
        [self.layer addSublayer:_backgroundCircleLayer];
    }
    
    CGFloat size = (_radius*2) + (HANDLE_WIDTH);
    CGFloat originX = _centerPoint.x-(size/2);
    CGFloat originY = _centerPoint.y-(size/2);
    _backgroundCircleLayer.frame = CGRectMake(originX, originY, size, size);
    _backgroundCircleLayer.cornerRadius = _backgroundCircleLayer.frame.size.width/2;
}

- (void)drawInnerBackgroundLayer
{
    if(_innerBackgroundLayer == nil){
        _innerBackgroundLayer = [CAGradientLayer layer];
        _innerBackgroundLayer.startPoint = CGPointMake(0.5f, 0.0f);
        _innerBackgroundLayer.endPoint = CGPointMake(0.5f, 1.0f);
        _innerBackgroundLayer.masksToBounds = YES;
        [self setBackgroundGradientColors:defaultWheelColors];
        [self.layer addSublayer:_innerBackgroundLayer];
    }
    
    _innerBackgroundLayer.frame = _backgroundCircleLayer.frame;
    _innerBackgroundLayer.cornerRadius = _innerBackgroundLayer.frame.size.width/2;
}

- (void)drawMaskLayer
{
    if(_maskLayer == nil){
        _maskLayer = [CALayer layer];
        _maskLayer.anchorPoint = CGPointMake(0.5f, 0.5f);
        
        // inner circle
        _innerCircleMaskLayer = [CAShapeLayer layer];
        _innerCircleMaskLayer.lineWidth = INNER_CIRCLE_WIDTH;
        _innerCircleMaskLayer.strokeColor = [UIColor colorWithRed:0.f green:0.f blue:0.f alpha:1.f].CGColor;
        _innerCircleMaskLayer.fillColor = [UIColor colorWithRed:0.f green:0.f blue:0.f alpha:0.f].CGColor;
        [_maskLayer addSublayer:_innerCircleMaskLayer];
        
#if SHOW_HANDLE_SHADOW_MASK
        // handle Shadow
        _handleShadowMaskLayer = [CAShapeLayer layer];
        _handleShadowMaskLayer.anchorPoint = CGPointMake(0.5f, 0.5f);
        _handleShadowMaskLayer.lineWidth = HANDLE_WIDTH+1;
        _handleShadowMaskLayer.strokeColor = [UIColor colorWithRed:0.f green:0.f blue:0.f alpha:1.f].CGColor;
        _handleShadowMaskLayer.fillColor = [UIColor colorWithRed:0.f green:0.f blue:0.f alpha:0.f].CGColor;
        
        // handle Shadow Mask
        _handleShadowInnerMaskLayer = [CAGradientLayer layer];
        _handleShadowInnerMaskLayer.opacity = 0.8f;
        _handleShadowInnerMaskLayer.startPoint = CGPointMake(0.0f, 0.5f);
        _handleShadowInnerMaskLayer.endPoint = CGPointMake(1.0f, 0.5f);
        _handleShadowInnerMaskLayer.colors = @[(id)[[UIColor clearColor] CGColor],
                                               (id)[[UIColor blackColor] CGColor],
                                               (id)[[UIColor clearColor] CGColor]];
        _handleShadowInnerMaskLayer.locations = @[@0.2,@0.5,@0.8];
        _handleShadowMaskLayer.mask = _handleShadowInnerMaskLayer;
        
        [_maskLayer addSublayer:_handleShadowMaskLayer];
#endif
        
        // handle
        _handleMaskLayer = [CAShapeLayer layer];
        _handleMaskLayer.lineWidth = HANDLE_WIDTH+1;
        _handleMaskLayer.strokeColor = [UIColor colorWithRed:0.f green:0.f blue:0.f alpha:1.f].CGColor;
        _handleMaskLayer.fillColor = [UIColor colorWithRed:0.f green:0.f blue:0.f alpha:0.f].CGColor;
        [_maskLayer addSublayer:_handleMaskLayer];
        
        [_innerBackgroundLayer setMask:_maskLayer];
    }
    
    _maskLayer.frame = _innerBackgroundLayer.bounds;
    _innerCircleMaskLayer.frame = _maskLayer.bounds;
    
    CGPoint center = CGPointMake(CGRectGetMidX(_maskLayer.bounds), CGRectGetMidY(_maskLayer.bounds));
    
    UIBezierPath *innerCirclePath = [UIBezierPath bezierPathWithArcCenter:center
                                                                   radius:_radius - (HANDLE_WIDTH/2) - (INNER_CIRCLE_WIDTH/2)
                                                               startAngle:0.0
                                                                 endAngle:M_PI * 2.0
                                                                clockwise:YES];
    _innerCircleMaskLayer.path = [innerCirclePath CGPath];
    
#if SHOW_HANDLE_SHADOW_MASK
    UIBezierPath *handleShadowPath = [UIBezierPath bezierPathWithArcCenter:center
                                                                    radius:_radius
                                                                startAngle:[JSWheelView toRadian:-_startAngle-_angle-(HANDLE_SHADOW_WIDTH/2) withMax:MAXANGLE]
                                                                  endAngle:[JSWheelView toRadian:-_startAngle-_angle+(HANDLE_SHADOW_WIDTH/2) withMax:MAXANGLE]
                                                                 clockwise:YES];
    _handleShadowMaskLayer.path = [handleShadowPath CGPath];
    
    CGPoint point = CGPointZero;
    point.x = center.x + _radius * cos([JSWheelView toRadian:-_startAngle-_angle withMax:MAXANGLE]);
    point.y = center.y + _radius * sin([JSWheelView toRadian:-_startAngle-_angle withMax:MAXANGLE]);
    _handleShadowInnerMaskLayer.frame = CGRectMake(point.x, point.y, 0, 0);
#endif
    
    UIBezierPath *handlePath = [UIBezierPath bezierPathWithArcCenter:center
                                                              radius:_radius
                                                          startAngle:[JSWheelView toRadian:-_startAngle-_angle-HANDLE_MASK_PADDING withMax:MAXANGLE]
                                                            endAngle:[JSWheelView toRadian:-_startAngle-_angle+HANDLE_MASK_PADDING withMax:MAXANGLE]
                                                           clockwise:YES];
    _handleMaskLayer.path = [handlePath CGPath];
}

- (void)drawCenterImageLayer
{
    if(_centerImageLayer == nil){
        _centerImageLayer = [CAGradientLayer layer];
        _centerImageLayer.frame = CGRectZero;
        _centerImageLayer.startPoint = CGPointMake(0.5f, 0.0f);
        _centerImageLayer.endPoint = CGPointMake(0.5f, 1.0f);
        _centerImageLayer.colors = defaultBackgroundGradientColors;
        _centerImageLayer.locations = @[@0.0,@0.77,@1.0];
        _centerImageLayer.masksToBounds = YES;
        [self.layer addSublayer:_centerImageLayer];
    }
    
    CGFloat size = (_radius*2)-(HANDLE_WIDTH)-(INNER_CIRCLE_WIDTH*2);
    CGFloat originX = (_centerPoint.x)-(size/2);
    CGFloat originY = (_centerPoint.y)-(size/2);
    
    _centerImageLayer.frame = CGRectMake(originX, originY, size, size);
    _centerImageLayer.cornerRadius = _centerImageLayer.bounds.size.width/2;
}

#pragma mark Override Methods
- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self setHandleToAngle:0];
    
    _radius = (MIN(self.frame.size.width, self.frame.size.height)/2) - (HANDLE_WIDTH + (INNER_CIRCLE_WIDTH*2));
    _centerPoint = CGPointMake(self.frame.size.width/2, self.frame.size.height/2);
    [self drawBackgroundCircleLayer];
    [self drawInnerBackgroundLayer];
    [self drawMaskLayer];
    [self drawCenterImageLayer];
//    [self addSectionTitleViews];
//    [self updateSectionTitleViews:NO];
    isLoadedDataForWheel = NO;
    [self setHandleToIndexPath:_currentIndexPath];
    isLoadedDataForWheel = YES;
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    if(_showSectionAndRow){
        if (_datas!=nil) {
            CGContextRef ctx = UIGraphicsGetCurrentContext();
            CGContextBeginPath(ctx);
            CGContextSetLineCap(ctx, kCGLineCapButt);
            CGContextSetLineWidth(ctx, HANDLE_WIDTH);
            
            int sectionCount = [_datas count];
            float sectionAngle = (float)MAXANGLE/sectionCount;
            for (int s=0; s<sectionCount; s++) {
                float currentSectionAngle = (sectionAngle * (float)s);
                currentSectionAngle = mod(currentSectionAngle, (float)MAXANGLE);
                [[UIColor blackColor] set];
                CGContextAddArc(ctx,
                                _centerPoint.x,
                                _centerPoint.y,
                                _radius,
                                [JSWheelView toRadian:-_startAngle + currentSectionAngle-.5 withMax:MAXANGLE],
                                [JSWheelView toRadian:-_startAngle + currentSectionAngle+.5 withMax:MAXANGLE],
                                0);
                CGContextStrokePath(ctx);
                
                JSWheelSectionData* sectionData = [_datas objectAtIndex:s];
                if(sectionData){
                    int rowCount = sectionData.datas.count;
                    float rowAngle = (float)sectionAngle/rowCount;
                    for (int r=0; r<rowCount; r++){
                        float currentRowAngle = (rowAngle * (float)r)+currentSectionAngle;
                        currentRowAngle = mod(currentRowAngle, (float)MAXANGLE);
                        
                        [[UIColor lightGrayColor] set];
                        CGContextAddArc(ctx,
                                        _centerPoint.x,
                                        _centerPoint.y,
                                        _radius,
                                        [JSWheelView toRadian:-_startAngle + currentRowAngle-.1 withMax:MAXANGLE],
                                        [JSWheelView toRadian:-_startAngle + currentRowAngle+.1 withMax:MAXANGLE],
                                        0);
                        CGContextStrokePath(ctx);
                    }
                }
            }
        }
    }
}

-(BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    if(_isHandleHidden) return NO;
    
    [super beginTrackingWithTouch:touch withEvent:event];
    
    _centerPoint = CGPointMake(self.frame.size.width/2, self.frame.size.height/2);
    CGPoint touchLocation = [touch locationInView:self];
    float distanceFromCenter = [self distanceFrom:_centerPoint To:touchLocation];
    distance_beginTracking=distanceFromCenter;
    if(distanceFromCenter <= _radius+TOUCHABLE_WIDTH){
        _prevTouchLocation = [touch locationInView:self];
        [self updateSectionTitleViews:NO];
        
        if(_disableOuterTracking == NO){
            float precisionFact = fabsf(distanceFromCenter - (_radius+(HANDLE_WIDTH/2)));
            if (precisionFact <= TOUCHABLE_WIDTH) {
                _isWheelTracking = YES;
                _isBeginTracking = YES;
                [self performSelectorInBackground:@selector(moveHandle:) withObject:[NSValue valueWithCGPoint:touchLocation]];
            }
        }
        
        [self showHandleShadow];
        
        if([_delegate respondsToSelector:@selector(wheelViewDidTrackingStart:)]){
            [_delegate wheelViewDidTrackingStart:self];
        }
        
        return YES;
    }
    
    return NO;
}

-(BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    if(_isHandleHidden) return NO;
    
    [super continueTrackingWithTouch:touch withEvent:event];
    _isBeginTracking = NO;
    
    _skipFrame++;
    if(_skipFrame < SKIP_FRAME_COUNT){
        return YES;
    }
    else if(_skipFrame == SKIP_FRAME_COUNT){
        _skipFrame = 0;
    }
    
    [self showHandleShadow];
    
    CGPoint touchLocation = [touch locationInView:self];
    
    if (distance_beginTracking>_radius-(TOUCHABLE_WIDTH/2)) {
        _isWheelTracking = YES;
        _trackingType = kWheelTrackingType_OutSide;
        [self performSelectorInBackground:@selector(moveHandle:) withObject:[NSValue valueWithCGPoint:touchLocation]];
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
    else{
        _isWheelTracking = YES;
        _trackingType = kWheelTrackingType_Inside;
        
        float currentAngle = atan2(touchLocation.y-_centerPoint.y, touchLocation.x-_centerPoint.x);
        float prevAngle = atan2(_prevTouchLocation.y-_centerPoint.y, _prevTouchLocation.x-_centerPoint.x);
        
        currentAngle = [JSWheelView toDegree:currentAngle withMax:MAXANGLE];
        prevAngle = [JSWheelView toDegree:prevAngle withMax:MAXANGLE];
        
        float diff = ABS(currentAngle-prevAngle);
        if(diff >= 180){
            if(prevAngle > 0 && currentAngle < 0){
                prevAngle = currentAngle-1;
            }
            else{
                prevAngle = currentAngle+1;
            }
        }
        
        if(diff >= 20){
            BOOL clockwise = (currentAngle > prevAngle)?YES:NO;
            if(clockwise){
                [self moveToNextIndexPath];
            }
            else{
                [self moveToPrevIndexPath];
            }
            
            [self sendActionsForControlEvents:UIControlEventValueChanged];
            _prevTouchLocation = touchLocation;
        }
    }
    
    return YES;
}

-(void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    if(_isHandleHidden) return;
    
    [super endTrackingWithTouch:touch withEvent:event];
    
//    CGPoint touchLocation = [touch locationInView:self];
//    float distanceFromCenter = [self distanceFrom:_centerPoint To:touchLocation];
//    float precisionFact = fabsf(distanceFromCenter - (_radius+(HANDLE_WIDTH/2)));
//    if ( !(precisionFact <= TOUCHABLE_WIDTH ) && _trackingType==kWheelTrackingType_None ) {
//        return;
//    }
    distance_beginTracking=0;
    [self trackingEnded];
}

- (void)cancelTrackingWithEvent:(UIEvent *)event
{
    if(_isHandleHidden) return;
    
    [super cancelTrackingWithEvent:event];
    distance_beginTracking=0;
    [self trackingEnded];
}

- (void)trackingEnded
{
    _isBeginTracking = NO;
    _isWheelTracking = NO;
    _trackingType = kWheelTrackingType_None;
    _skipFrame = 0;
    _prevTouchLocation = CGPointZero;
    
    [self setHandleToIndexPath:_currentIndexPath];
    [self updateSectionTitleViews:YES];
    [self hideHandleShadow];
    
    if([_delegate respondsToSelector:@selector(wheelViewDidTrackingEnd:)]){
        [_delegate wheelViewDidTrackingEnd:self];
    }
}

#pragma mark - Setter Methods
- (void)setDataSource:(id<JSWheelViewDataSource>)dataSource
{
    _dataSource = dataSource;
    [self reloadWheelDatas];
}

- (void)setDelegate:(id<JSWheelViewDelegate>)delegate
{
    _delegate = delegate;
}

#pragma mark - Public Methods
- (void)reloadWheelDatas
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(loadDatas) object:nil];
    
    [_datas removeAllObjects];
    [self performSelector:@selector(loadDatas)];
}

- (void)setHandleToIndexPath:(NSIndexPath *)indexPath
{
    NSInteger sectionsCount = [_datas count];
    if(sectionsCount == 0 || indexPath.section >= sectionsCount) return;
    if(indexPath.row < 0 || indexPath.row >= NSNotFound) return;
    
    JSWheelSectionData* sectionData = [_datas objectAtIndex:indexPath.section];
    if(sectionData){
        NSInteger datasCount = sectionData.datas.count;
        if(indexPath.row < datasCount){
            //            BOOL isChanged = (_currentIndexPath.section != indexPath.section || _currentIndexPath.row != indexPath.row);
            _currentIndexPath = indexPath;
            _angle = [self angleWithIndexPath:indexPath];
            
            if(_trackingType == kWheelTrackingType_OutSide){
                if(_isWheelTracking == NO && _isBeginTracking == NO){
                    [self rotationHandle];
                }
            }
            else{
                [self rotationHandle];
            }
            
            id data = [sectionData.datas objectAtIndex:indexPath.row];
            [self playHaptic];
            [self updateSectionTitleViews:!_isWheelTracking];
            //call delegate only if not called from loadData
            if (isLoadedDataForWheel){
                //            if (isLoadedDataForWheel && isChanged){
                if([_delegate respondsToSelector:@selector(wheelView:didSelectDataWithIndexPath:withData:)]){
                    [_delegate wheelView:self didSelectDataWithIndexPath:indexPath withData:data];
                }
                
            }
        }
    }
}

- (void)setHandleToAngle:(float)angle
{
    _angle = angle;
    [self rotationHandle];
}

- (void)moveToNextIndexPath
{
    if(_currentIndexPath == nil) return;
    
    NSInteger section = _currentIndexPath.section;
    NSInteger row = _currentIndexPath.row;
    
    JSWheelSectionData* sectionData = [_datas objectAtIndex:section];
    if(sectionData){
        NSInteger sectionsCount = [_datas count];
        NSInteger rowsCount = [sectionData.datas count];
        if(row+1 < rowsCount){
            row++;
        }
        else if(row+1 == rowsCount || rowsCount == 0){
            section++;
            row = 0;
        }
        else if(row >= rowsCount){
            row = 0;
        }
        
        if(section == sectionsCount){
            section = 0;
        }
    }
    
    NSIndexPath* newIndexPath = [NSIndexPath indexPathForRow:row inSection:section];
    if(![newIndexPath isEqual:_currentIndexPath]){
        [self setHandleToIndexPath:newIndexPath];
    }
}

- (void)moveToPrevIndexPath
{
    if(_currentIndexPath == nil) return;
    
    NSInteger section = _currentIndexPath.section;
    NSInteger row = _currentIndexPath.row;
    
    NSInteger sectionsCount = [_datas count];
    JSWheelSectionData* sectionData = [_datas objectAtIndex:section];
    JSWheelSectionData* prevSectionData = [_datas objectAtIndex:(section-1 < 0)?sectionsCount-1:section-1];
    if(sectionData && prevSectionData){
        NSInteger prevRowsCount = [prevSectionData.datas count];
        if(row-1 > -1){
            row--;
        }
        else if(row-1 == -1 || prevRowsCount == 0){
            section--;
            row = prevRowsCount-1;
        }
        
        if(section == -1){
            section = sectionsCount-1;
        }
        
        if(row == -1){
            row = 0;
        }
    }
    
    NSIndexPath* newIndexPath = [NSIndexPath indexPathForRow:row inSection:section];
    if(![newIndexPath isEqual:_currentIndexPath]){
        [self setHandleToIndexPath:newIndexPath];
    }
}

- (void)setCenterImage:(UIImage *)image
{
    if(_centerImageLayer){
        CATransition *transition = [CATransition animation];
        transition.duration = 0.2f;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionFade;
        [_centerImageLayer addAnimation:transition forKey:nil];
        
        _centerImageLayer.contents = (id)image.CGImage;
    }
}

- (void)setBackgroundGradientColors:(NSArray *)colors
{
    if(_innerBackgroundLayer){
        _innerBackgroundLayer.colors = (colors)?colors:defaultWheelColors;
    }
}

- (void)setOuterWheelCircleColor:(UIColor *)color
{
    if(_backgroundCircleLayer){
        _backgroundCircleLayer.backgroundColor = color.CGColor;
    }
}

#pragma mark - Private Methods
- (void)loadDatas
{
    if(_dataSource == nil) return;
    
    NSInteger sectionCount = 1;
    if([_dataSource respondsToSelector:@selector(numberOfSectionsInWheelView:)]){
        sectionCount = [_dataSource numberOfSectionsInWheelView:self];
        if(sectionCount == 0){
            sectionCount = 1;
        }
    }
    
    if([_dataSource respondsToSelector:@selector(wheelViewTitleFont:)]){
        _titleFont = [_dataSource wheelViewTitleFont:self];
    }
    
    if([_dataSource respondsToSelector:@selector(wheelViewTitleColorForNormal:)]){
        _titleColorForNormal = [_dataSource wheelViewTitleColorForNormal:self];
    }
    
    if([_dataSource respondsToSelector:@selector(wheelViewTitleColorForHighlight:)]){
        _titleColorForHighlight = [_dataSource wheelViewTitleColorForHighlight:self];
    }
    
    for(int i=0; i<sectionCount; i++){
        JSWheelSectionData* sectionData = [JSWheelSectionData new];
        if([_dataSource respondsToSelector:@selector(wheelView:titleForSection:)]){
            sectionData.sectionTitle = [_dataSource wheelView:self titleForSection:i];
        }
        
        NSMutableArray* rowDatas = [NSMutableArray new];
        NSInteger rowCount = 0;
        if([_dataSource respondsToSelector:@selector(wheelView:numberOfRowsInSection:)]){
            rowCount = [_dataSource wheelView:self numberOfRowsInSection:i];
            for(int j=0; j<rowCount; j++){
                if([_dataSource respondsToSelector:@selector(wheelView:dataForWheelIndexPath:)]){
                    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:j inSection:i];
                    id data = [_dataSource wheelView:self dataForWheelIndexPath:indexPath];
                    if(data){
                        [rowDatas addObject:data];
                    }
                }
            }
        }
        [sectionData setDatas:rowDatas];
        [_datas addObject:sectionData];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSIndexPath* tempIndexPath = nil;
        if([_dataSource respondsToSelector:@selector(indexPathForAfterLoad:)]){
            tempIndexPath = [_dataSource indexPathForAfterLoad:self];
            if(tempIndexPath){
                _currentIndexPath = tempIndexPath;
            }
        }
        
//        if(![self validIndexPath:_currentIndexPath]){
//            _currentIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
//        }
        
//        if(sectionCount > 1){
//            float sectionAngle = (float)MAXANGLE/sectionCount;
//            float addingAngle = sectionAngle/2;
//            _startAngle = START_ANGLE+addingAngle;
//        }
//        else{
            _startAngle = START_ANGLE;
//        }
        
        [self addSectionTitleViews];
        if((sectionCount == 0) ||
           ((sectionCount == 1) && ([[[_datas firstObject] datas] count] == 0))){
            [self hideHandle:YES];
        }
        else if(_currentIndexPath == nil){
            [self hideHandle:NO];
        }
        else{
            //Ishita.. .
            isLoadedDataForWheel=NO;
            [self setHandleToIndexPath:_currentIndexPath];
            [self hideHandle:NO];
            isLoadedDataForWheel=YES;
            //Ishita..
        }
        
        [self setNeedsLayout];
    });
}

- (void)addSectionTitleViews
{
    if (_datas!=nil) {
        [_sectionTitles enumerateObjectsUsingBlock:^(JSArcTextView* subView, NSUInteger idx, BOOL *stop) {
            [subView removeFromSuperview];
        }];
        [_sectionTitles removeAllObjects];
        
        int sectionCount = [_datas count];
        float sectionAngle = (float)MAXANGLE/sectionCount;
        for (int s=0; s<sectionCount; s++) {
            float currentSectionAngle = (sectionAngle * (float)s);
            currentSectionAngle = mod(currentSectionAngle, (float)MAXANGLE);
            
            JSWheelSectionData* sectionData = [_datas objectAtIndex:s];
            if(sectionData){
                if([sectionData.sectionTitle length]>0){
                    [self addArcTextView:sectionData.sectionTitle withStartAngle:currentSectionAngle arcSize:sectionAngle];
                }
            }
        }
        [self updateSectionTitleViews:NO];
    }
}

- (void)updateSectionTitleViews:(BOOL)isHighlightAll
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(_sectionTitles != nil){
            NSInteger titleCount = [_sectionTitles count];
            if(titleCount > _currentIndexPath.section){
                for(int i=0; i<titleCount; i++){
                    JSArcTextView* textView = [_sectionTitles objectAtIndex:i];
                    if(isHighlightAll){
                        [textView setColor:_titleColorForNormal];
                    }
                    else{
                        if(i == _currentIndexPath.section){
                            [textView setColor:_titleColorForHighlight];
                        }
                        else{
                            [textView setColor:_titleColorForNormal];
                        }
                    }
                }
            }
        }
    });
}

- (void)moveHandle:(NSValue*)lastPointValue
{
    CGPoint lastPoint = [lastPointValue CGPointValue];
    float currentAngle = AngleFromNorth(_centerPoint, lastPoint, _startAngle, MAXANGLE);
    float angleNext = MAXANGLE - currentAngle;
    
    [self setHandleToAngle:angleNext];
    
    NSIndexPath* indexPath = [self indexPathWithAngle:angleNext];
    if(indexPath && ![indexPath isEqual:_currentIndexPath]){
        [self setHandleToIndexPath:indexPath];
    }
}

- (void)rotationHandle
{
    float rotationAngle = [JSWheelView toRadian:_angle withMax:MAXANGLE];
    [CATransaction setDisableActions:YES];
    CGAffineTransform rotationTransform = CGAffineTransformRotate(CGAffineTransformIdentity, rotationAngle);
    _maskLayer.affineTransform = rotationTransform;
}

- (void)showHandleShadow
{
#if SHOW_HANDLE_SHADOW_MASK
    if(_handleShadowPadding == 0.f){
        _handleShadowPadding = HANDLE_SHADOW_WIDTH;
        _handleShadowInnerMaskLayer.frame = CGRectMake(_handleShadowInnerMaskLayer.frame.origin.x-(_handleShadowPadding/2), _handleShadowInnerMaskLayer.frame.origin.y-(_handleShadowPadding/2), _handleShadowPadding, _handleShadowPadding);
    }
#endif
}

- (void)hideHandleShadow
{
#if SHOW_HANDLE_SHADOW_MASK
    if(_handleShadowPadding > 0.f){
        _handleShadowPadding = 0.f;
        _handleShadowInnerMaskLayer.frame = CGRectMake(_handleShadowInnerMaskLayer.frame.origin.x+(HANDLE_SHADOW_WIDTH/2), _handleShadowInnerMaskLayer.frame.origin.y+(HANDLE_SHADOW_WIDTH/2), 0, 0);
    }
#endif
    
}

- (void)hideHandle:(BOOL)isHidden
{
    _isHandleHidden = isHidden;
    _handleMaskLayer.hidden = _isHandleHidden;
    _backgroundCircleLayer.hidden = _isHandleHidden;
}

#pragma mark - Utils
- (BOOL)validWheelViewWithTouch:(UITouch*)touch {
    _centerPoint = CGPointMake(self.frame.size.width/2, self.frame.size.height/2);
    CGPoint touchLocation = [touch locationInView:self];
    float distanceFromCenter = [self distanceFrom:_centerPoint To:touchLocation];
    
    if (distanceFromCenter >= _backgroundCircleLayer.frame.size.width/2) {
        return YES;
    }
    
    return NO;
}

- (BOOL)validIndexPath:(NSIndexPath*)indexPath
{
    BOOL ret = NO;
    
    if(indexPath == nil) return NO;
    
    NSInteger section = [indexPath section];
    NSInteger row = [indexPath row];
    
    NSInteger sectionCount = [_datas count];
    
    if(section < sectionCount){
        JSWheelSectionData* sectionData = [_datas objectAtIndex:section];
        if(sectionData){
            NSInteger rowCount = [sectionData.datas count];
            if(row < rowCount){
                if([sectionData.datas objectAtIndex:row]){
                    ret = YES;
                }
            }
        }
    }
    
    return ret;
}

- (void)addArcTextView:(NSString*)text withStartAngle:(float)startAngle arcSize:(float)arcSize
{
    JSArcTextView* textView = [[JSArcTextView alloc] initWithFrame:self.bounds];
    [textView setUserInteractionEnabled:NO];
    textView.text = text;
    textView.textAttributes = @{NSFontAttributeName:_titleFont, NSForegroundColorAttributeName:_titleColorForNormal};
    textView.textAlignment = NSTextAlignmentCenter;
    textView.verticalTextAlignment = JSArcTextTypeVerticalAlignCenter;
    
    textView.baseAngle = [JSWheelView toRadian:-_startAngle+startAngle+(arcSize/2) withMax:(float)MAXANGLE];
    textView.radius = _radius;
    [self addSubview:textView];
    [_sectionTitles addObject:textView];
}

- (void)playHaptic
{
    if(_isHaptic){
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
}

- (NSIndexPath*)indexPathWithAngle:(float)angle
{
    NSInteger section = -1;
    NSInteger row = -1;
    int sectionCount = [_datas count];
    float sectionAngle = (float)MAXANGLE/sectionCount;
    for (int s=0; s<sectionCount; s++) {
        float currentSectionAngle = (sectionAngle * (float)s);
        currentSectionAngle = mod(currentSectionAngle, (float)MAXANGLE);
        if(angle >= currentSectionAngle && angle <= currentSectionAngle+sectionAngle){
            section = s;
            JSWheelSectionData* sectionData = [_datas objectAtIndex:s];
            if(sectionData){
                int rowCount = sectionData.datas.count;
                float rowAngle = (float)sectionAngle/rowCount;
                for (int r=0; r<rowCount; r++){
                    float currentRowAngle = (rowAngle * (float)r)+currentSectionAngle;
                    if(angle >= currentRowAngle-(rowAngle/2) && angle <= currentRowAngle+(rowAngle/2)){
                        row = r;
                        break;
                    }
                }
            }
            break;
        }
    }
    
    if(section != -1 && row != -1){
        return [NSIndexPath indexPathForRow:row inSection:section];
    }
    return nil;
}

- (float)angleWithIndexPath:(NSIndexPath*)indexPath
{
    float ret = 0;
    
    int sectionCount = [_datas count];
    if(sectionCount == 0){
        return ret;
    }
    
    float sectionAngle = (float)MAXANGLE/sectionCount;
    JSWheelSectionData* data = [_datas objectAtIndex:indexPath.section];
    if(data){
        int rowCount = data.datas.count;
        float rowAngle = (float)sectionAngle/((rowCount==0)?1:rowCount);
        ret = (rowAngle * (float)indexPath.row)+(sectionAngle * (float)indexPath.section);
    }
    
    return ret;
}

-(float) distanceFrom:(CGPoint) p1 To:(CGPoint) p2
{
    CGFloat xDist = (p1.x - p2.x);
    CGFloat yDist = (p1.y - p2.y);
    float distance = sqrt((xDist * xDist) + (yDist * yDist));
    return distance;
}

- (CGFloat) calculateAngleWithStartPoint:(CGPoint)startPoint endPoint:(CGPoint)endPoint
{
    CGFloat baseAngle = atan2(-(endPoint.x-startPoint.x), -(endPoint.y-startPoint.y));
    CGFloat radians = [JSWheelView toRadian:baseAngle withMax:MAXANGLE];
    CGFloat angle = radians;
    
    return angle;
}

+(float) toRadian:(float)deg  withMax:(float)max
{
    return ( (M_PI * (deg)) / (max/2) );
}

+(float) toDegree:(float)rad withMax:(float)max
{
    return ( ((max/2) * (rad)) / M_PI );
}

#define SQR(x)			( (x) * (x) )
static inline float AngleFromNorth(CGPoint p1, CGPoint p2, float start, float max)
{
    CGPoint v = CGPointMake(p2.x-p1.x,p2.y-p1.y);
    float vmag = sqrt(SQR(v.x) + SQR(v.y)), result = 0;
    v.x /= vmag;
    v.y /= vmag;
    double radians = atan2(v.y,v.x);
    result = [JSWheelView toDegree:(radians)  withMax:max] + start;
    result = (result >=0  ? result : result + max);
    result = MAXANGLE - result;
    return (result >=0  ? result : result + max);
}

static inline float mod(float f1, float f2)
{
    return (f1-f2*(int)(f1/f2));
}

@end
