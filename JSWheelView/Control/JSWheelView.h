//
//  JSWheelView.h
//  JSWheelView
//
//  Created by JoAmS on 2015. 4. 1..
//  Copyright (c) 2015년 jooam. All rights reserved.
//

#import <UIKit/UIKit.h>

#define defaultWheelColors @[\
(id)[UIColor colorWithRed:234/255.f green:45/255.f blue:35/255.f alpha:1.0f].CGColor,\
(id)[UIColor colorWithRed:101/255.f green:156/255.f blue:153/255.f alpha:1.0f].CGColor,\
(id)[UIColor colorWithRed:11/255.f green:231/255.f blue:222/255.f alpha:1.0f].CGColor,\
(id)[UIColor colorWithRed:153/255.f green:196/255.f blue:75/255.f alpha:1.0f].CGColor]

#define defaultBackgroundGradientColors @[\
(id)[UIColor colorWithRed:24/255.f green:166/255.f blue:223/255.f alpha:1.0f].CGColor,\
(id)[UIColor colorWithRed:122/255.f green:222/255.f blue:22/255.f alpha:1.0f].CGColor,\
(id)[UIColor colorWithRed:220/255.f green:189/255.f blue:11/255.f alpha:1.0f].CGColor,\
(id)[UIColor colorWithRed:112/255.f green:33/255.f blue:163/255.f alpha:1.0f].CGColor,\
(id)[UIColor colorWithRed:225/255.f green:135/255.f blue:135/255.f alpha:1.0f].CGColor]

@protocol JSWheelViewDataSource;
@protocol JSWheelViewDelegate;

@interface JSWheelView : UIControl
@property (nonatomic, weak) id<JSWheelViewDataSource> dataSource;
@property (nonatomic, weak) id<JSWheelViewDelegate> delegate;
@property (nonatomic, assign) BOOL isHaptic;
@property (nonatomic, assign) BOOL showSectionAndRow;
@property (nonatomic, strong) CAGradientLayer* centerImageLayer;
@property (nonatomic, assign, readonly) BOOL isWheelTracking;
@property (nonatomic, assign) BOOL disableOuterTracking;
- (void)reloadWheelDatas;
- (void)setHandleToIndexPath:(NSIndexPath*)indexPath;
- (void)setHandleToAngle:(float)angle;
- (void)moveToNextIndexPath;
- (void)moveToPrevIndexPath;
- (void)setCenterImage:(UIImage*)image;
- (void)setBackgroundGradientColors:(NSArray*)colors;
- (void)setOuterWheelCircleColor:(UIColor *)color;

- (BOOL)validWheelViewWithTouch:(UITouch*)touch;
@end

@protocol JSWheelViewDataSource <NSObject>
@optional
- (NSInteger)numberOfSectionsInWheelView:(JSWheelView*)wheelView;
- (NSInteger)wheelView:(JSWheelView *)wheelView numberOfRowsInSection:(NSInteger)section;
- (NSString*)wheelView:(JSWheelView *)wheelView titleForSection:(NSInteger)section;
- (UIFont*)wheelViewTitleFont:(JSWheelView *)wheelView;
- (id)wheelView:(JSWheelView *)wheelView dataForWheelIndexPath:(NSIndexPath*)indexPath;
- (NSIndexPath*)indexPathForAfterLoad:(JSWheelView*)wheelView;
@end

@protocol JSWheelViewDelegate <NSObject>
@optional
- (void)wheelView:(JSWheelView*)wheelView didSelectDataWithIndexPath:(NSIndexPath*)indexPath withData:(id)data;
- (void)wheelViewDidTrackingStart:(JSWheelView*)wheelView;
- (void)wheelViewDidTrackingEnd:(JSWheelView*)wheelView;
@end