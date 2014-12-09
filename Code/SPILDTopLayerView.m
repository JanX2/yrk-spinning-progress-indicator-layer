//
//  SPILDTopLayerView.m
//  SPILDemo
//
//  Copyright 2009 Kelan Champagne. All rights reserved.
//

#import "SPILDTopLayerView.h"

#import "YRKSpinningProgressIndicatorLayer.h"


@interface SPILDTopLayerView ()

- (void)setupLayers;

- (void)usePlainBackground;
- (void)useQCBackground;

@end


@implementation SPILDTopLayerView


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Init, Dealloc, etc
//------------------------------------------------------------------------------

- (void)dealloc
{
    [_rootLayer removeFromSuperlayer];

    [_progressIndicatorLayer removeFromSuperlayer];
    [_plainBackgroundLayer removeFromSuperlayer];
    [_qcBackgroundLayer removeFromSuperlayer];
}

- (void)awakeFromNib
{
    [self setupLayers];
}


- (void)setupLayers
{
    _rootLayer = [CALayer layer];
    [self setLayer:_rootLayer];
    [self setWantsLayer:YES];

    // Create the plain background layer
    _plainBackgroundLayer = [CALayer layer];
    _plainBackgroundLayer.name = @"plainBackgroundLayer";
    _plainBackgroundLayer.anchorPoint = CGPointMake(0.0, 0.0);
    _plainBackgroundLayer.position = CGPointMake(0, 0);
    _plainBackgroundLayer.bounds = [[self layer] bounds];
    _plainBackgroundLayer.autoresizingMask = (kCALayerWidthSizable|kCALayerHeightSizable);
    _plainBackgroundLayer.zPosition = 0;
    CGColorRef cgColor = [[NSColor blackColor] CGColor];
    _plainBackgroundLayer.backgroundColor = cgColor;
    [_rootLayer addSublayer:_plainBackgroundLayer];

    // Start with QC background
    //[self useQCBackground];
    [self usePlainBackground];

    // Put a SpinningProgressIndicatorLayer in front of everything
    _progressIndicatorLayer = [[YRKSpinningProgressIndicatorLayer alloc] initWithIndeterminateCycleDuration:2.0 // This is the value that Screen Sharing uses.
                                                                                       determinateTweenTime:NAN];
    _progressIndicatorLayer.name = @"progressIndicatorLayer";
    _progressIndicatorLayer.anchorPoint = CGPointMake(0.0, 0.0);
    _progressIndicatorLayer.position = CGPointMake(0, 0);
    _progressIndicatorLayer.bounds = [[self layer] bounds];
    _progressIndicatorLayer.autoresizingMask = (kCALayerWidthSizable|kCALayerHeightSizable);
    _progressIndicatorLayer.zPosition = 10; // make sure it goes in front of the background layer
    [_rootLayer addSublayer:_progressIndicatorLayer];
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark UI event handling
//------------------------------------------------------------------------------

// Need to handle mouse events to trap/block input.

- (void)mouseDown:(NSEvent *)event
{
    //NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)mouseDragged:(NSEvent *)event
{
    //NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)mouseUp:(NSEvent *)event
{
    //NSLog(@"%@", NSStringFromSelector(_cmd));
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Toggling Background
//------------------------------------------------------------------------------

- (IBAction)toggleBackground:(id)sender
{
    if ([[sender selectedCell] tag] == 1) {
        [self useQCBackground];
    }
    else if ([[sender selectedCell] tag] == 2) {
        [self usePlainBackground];
    }
}

- (void)usePlainBackground
{
    // Hide the QC background and show the plain one
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    _qcBackgroundLayer.hidden = YES;
    _plainBackgroundLayer.hidden = NO;
    [CATransaction commit];

    // destroy the QC background completely, so we can test the CPU usage of just the progress indicator itself
    [_qcBackgroundLayer removeFromSuperlayer];
    _qcBackgroundLayer = nil;
    
    self.isAnimatingBackground = NO;
}

- (void)useQCBackground
{
    // Create the QC background layer
    _qcBackgroundLayer = [QCCompositionLayer compositionLayerWithFile:
               [[NSBundle mainBundle] pathForResource:@"Background" ofType:@"qtz"]];
    _qcBackgroundLayer.name = @"qcBackgroundLayer";
    _qcBackgroundLayer.anchorPoint = CGPointMake(0.0, 0.0);
    _qcBackgroundLayer.position = CGPointMake(0, 0);
    _qcBackgroundLayer.bounds = [[self layer] bounds];
    _qcBackgroundLayer.autoresizingMask = (kCALayerWidthSizable|kCALayerHeightSizable);
    _qcBackgroundLayer.zPosition = 0;
    [_rootLayer addSublayer:_qcBackgroundLayer];

    // Hide the plain background and show the QC one
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    _qcBackgroundLayer.hidden = NO;
    _plainBackgroundLayer.hidden = YES;
    [CATransaction commit];

    self.isAnimatingBackground = YES;
}

- (void)setPlainBackgroundColor:(NSColor *)newColor
{
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    CGColorRef cgColor = [newColor CGColor];
    _plainBackgroundLayer.backgroundColor = cgColor;
    [CATransaction commit];
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Properties
//------------------------------------------------------------------------------
@synthesize rootLayer = _rootLayer;
@synthesize progressIndicatorLayer = _progressIndicatorLayer;
@synthesize isAnimatingBackground = _isAnimatingBackground;

@end
