//
//  YRKSpinningProgressIndicatorLayer.h
//  SPILDemo
//
//  Copyright 2009 Kelan Champagne. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>


@interface YRKSpinningProgressIndicatorLayer : CALayer {
    BOOL _isDeterminate;

    NSTimeInterval _indeterminateCycleDuration;
    
    CGColorRef _foreColor;
    float _fullOpacity;
    float _indeterminateMinimumOpacity;

    NSUInteger _numFins;
}

- (instancetype)initWithIndeterminateCycleDuration:(CFTimeInterval)indeterminateCycleDuration
                              determinateTweenTime:(CFTimeInterval)determinateTweenTime;

- (void)toggleProgressAnimation;
- (void)startProgressAnimation;
- (void)stopProgressAnimation;

// Properties and Accessors
@property (readonly, assign) BOOL isRunning;
@property (readwrite, assign) BOOL isDeterminate;
@property (readwrite, assign) double maxValue;
@property (readwrite, assign) double doubleValue;
@property (readwrite, assign) CFTimeInterval determinateTweenTime; // Smoothes animation to new doubleValue. 0.0: disable smooth transition, hard jump.
@property (readwrite, copy) NSColor *color;  // "copy" because we don't retain it -- we create a CGColor from it

@end
