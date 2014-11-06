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

    BOOL _isRunning;
    NSTimer *_animationTimer;
    NSUInteger _position;
    
    NSTimeInterval _indeterminateCycleDuration;
    
    CGColorRef _foreColor;
    CGFloat _fullOpacity;
    CGFloat _fadeDownOpacity;

    CALayer *_finLayersRoot;
    NSUInteger _numFins;
    NSMutableArray *_finLayers;

    double _maxValue;
    double _doubleValue;
}

- (void)toggleProgressAnimation;
- (void)startProgressAnimation;
- (void)stopProgressAnimation;

// Properties and Accessors
@property (readonly, assign) BOOL isRunning;
@property (readwrite, assign) BOOL isDeterminate;
@property (readwrite, assign) double maxValue;
@property (readwrite, assign) double doubleValue;
@property (readwrite, copy) NSColor *color;  // "copy" because we don't retain it -- we create a CGColor from it

@end
