//
//  SPILDAppController.m
//  SPILDemo
//
//  Copyright 2009 Kelan Champagne. All rights reserved.
//

#import "SPILDAppController.h"

#import "SPILDTopLayerView.h"
#import "YRKSpinningProgressIndicatorLayer.h"

@interface SPILDAppController ()

// Helper Methods
- (void)setupDeterminateProgressTimer;
- (void)disposeDeterminateProgressTimer;

@end

@implementation SPILDAppController {
    NSUInteger _initialWaitTicks;
    NSUInteger _finalWaitTicks;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Init, Dealloc, etc
//------------------------------------------------------------------------------

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _fgColorWell.color = [NSColor blackColor];
    [self pickNewForeColor:_fgColorWell];

    _bgColorWell.color = [NSColor whiteColor];
    [self pickNewBackColor:_bgColorWell];
    
#if 0
    [_progressIndicatorType selectCell:[_progressIndicatorType cellWithTag:2]];
    [self selectDeterminateProgressIndicator:self];
#endif

    YRKSpinningProgressIndicatorLayer *progressIndicatorLayer = _mainView.progressIndicatorLayer;

    progressIndicatorLayer.determinateProgressOpacity = 0.70f;
    
    [self startStopProgressIndicator:self];
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark IB Actions
//------------------------------------------------------------------------------

- (IBAction)pickNewForeColor:(id)sender
{
    [_mainView progressIndicatorLayer].color = [sender color];
}

- (IBAction)pickNewBackColor:(id)sender
{
    [_mainView setPlainBackgroundColor:[sender color]];
}

- (IBAction)selectProgressIndicatorType:(id)sender
{
    if ([[sender selectedCell] tag] == 1) {
        [self selectIndeterminateProgressIndicator:sender];
    }
    else if ([[sender selectedCell] tag] == 2) {
        [self selectDeterminateProgressIndicator:sender];
    }
}

- (IBAction)selectIndeterminateProgressIndicator:(id)sender
{
    BOOL wasRunning = NO;
    
    if (_determinateProgressTimer != nil) {
        [self disposeDeterminateProgressTimer];
        wasRunning = YES;
    }
    
    _mainView.progressIndicatorLayer.isDeterminate = NO;
    
    if (wasRunning) {
        [self startProgressIndicator:sender];
    }
    
    [_mainView setNeedsDisplay:YES];
}

- (IBAction)selectDeterminateProgressIndicator:(id)sender
{
    BOOL wasRunning = NO;
    
    if (_mainView.progressIndicatorLayer.isRunning) {
        [self stopProgressIndicator:sender];
        wasRunning = YES;
    }
    
    _mainView.progressIndicatorLayer.isDeterminate = YES;
    
    if (wasRunning) {
        [self setupDeterminateProgressTimer];
        [self startProgressIndicator:sender];
    }
    
    [_mainView setNeedsDisplay:YES];
}

- (IBAction)startStopProgressIndicator:(id)sender
{
    if ([[_mainView progressIndicatorLayer] isRunning] || (_determinateProgressTimer != nil)) {
        // it is running, so stop it
        [self stopProgressIndicator:sender];
    }
    else {
        // it is stopped, so start it
        [self startProgressIndicator:sender];
    }
}

- (IBAction)startProgressIndicator:(id)sender
{
    if (_mainView.progressIndicatorLayer.isDeterminate) {
        [self setupDeterminateProgressTimer];
    }
    else {
        [[_mainView progressIndicatorLayer] startProgressAnimation];
    }
    
    [_startStopButton setTitle:@"Stop"];
}

- (IBAction)stopProgressIndicator:(id)sender
{
    if (_mainView.progressIndicatorLayer.isDeterminate) {
        [self disposeDeterminateProgressTimer];
        //_mainView.progressIndicatorLayer.doubleValue = 0.0;
    }
    else {
        [[_mainView progressIndicatorLayer] stopProgressAnimation];
    }
    
    [_startStopButton setTitle:@"Start"];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Helpers
//------------------------------------------------------------------------------

const NSUInteger initialWait = 20;
const NSUInteger finalWait = 40;

- (void)advanceDeterminateTimer:(NSTimer *)timer {
    // 200 times 0.05s should make a full progress in 10s.

    if (_mainView.progressIndicatorLayer.doubleValue >= _mainView.progressIndicatorLayer.maxValue) {
        if (_finalWaitTicks == 0) {
            _mainView.progressIndicatorLayer.doubleValue = 0.0;
            _initialWaitTicks = 0;
            _finalWaitTicks = finalWait;
        }
        _finalWaitTicks--;
    }
    else {
        if ((_initialWaitTicks >= initialWait) ||
            (_mainView.progressIndicatorLayer.doubleValue > 0.0)) {
#define ENABLE_CLOCK_STYLE 0
#if ENABLE_CLOCK_STYLE
            _mainView.progressIndicatorLayer.doubleValue += 5;
            _initialWaitTicks = 0;
#else
            _mainView.progressIndicatorLayer.doubleValue += 0.5;
#endif
        }
        _initialWaitTicks++;
    }
}

- (void)setupDeterminateProgressTimer {
    [self disposeDeterminateProgressTimer];
    _initialWaitTicks = 0;
    _finalWaitTicks = finalWait;

    _determinateProgressTimer = [[NSTimer alloc] initWithFireDate:[NSDate date] 
                                                         interval:0.05
                                                           target:self 
                                                         selector:@selector(advanceDeterminateTimer:) 
                                                         userInfo:nil 
                                                          repeats:YES];
    
    [[NSRunLoop currentRunLoop] addTimer:_determinateProgressTimer forMode:NSRunLoopCommonModes];
}

- (void)disposeDeterminateProgressTimer {
    [_determinateProgressTimer invalidate];
    _determinateProgressTimer = nil;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Properties
//------------------------------------------------------------------------------

@synthesize mainView = _mainView;

@end
