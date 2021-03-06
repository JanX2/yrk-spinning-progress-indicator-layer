//
//  YRKSpinningProgressIndicatorLayer.m
//  SPILDemo
//
//  Copyright 2009 Kelan Champagne. All rights reserved.
//

#import "YRKSpinningProgressIndicatorLayer.h"


@interface YRKSpinningProgressIndicatorLayer ()

// Animation
- (void)advancePosition;

// Helper Methods
- (void)setupType;
- (void)setupIndeterminate;
- (void)setupDeterminate;

- (void)removeFinLayers;
- (void)createFinLayers;

@property (nonatomic, readonly) CGRect finBoundsForCurrentBounds;
@property (nonatomic, readonly) CGPoint finAnchorPointForCurrentBounds;

- (void)setupAnimTimer;
- (void)disposeAnimTimer;

@end


@implementation YRKSpinningProgressIndicatorLayer

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Init, Dealloc, etc
//------------------------------------------------------------------------------

- (instancetype)init
{
    self = [super init];
    if (self) {
        _position = 0;
        _numFins = 12;
        _fadeDownOpacity = 0.0f;
        _isRunning = NO;
        self.color = [NSColor blackColor];
        [self setBounds:CGRectMake(0.0f, 0.0f, 10.0f, 10.0f)];
        self.isDeterminate = NO;
        self.doubleValue = 0;
        self.maxValue = 100;
    }
    return self;
}

- (void)dealloc
{
    self.color = nil;
    [self removeFinLayers];
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Overrides
//------------------------------------------------------------------------------

- (void)setBounds:(CGRect)newBounds
{
    [super setBounds:newBounds];

    // Resize the fins
    CGRect finBounds = [self finBoundsForCurrentBounds];
    CGPoint finAnchorPoint = [self finAnchorPointForCurrentBounds];
    CGPoint finPosition = CGPointMake([self bounds].size.width/2, [self bounds].size.height/2);
    CGFloat finCornerRadius = finBounds.size.width/2;

    // do the resizing all at once, immediately
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    for (CALayer *fin in _finLayers) {
        fin.bounds = finBounds;
        fin.anchorPoint = finAnchorPoint;
        fin.position = finPosition;
        fin.cornerRadius = finCornerRadius;
    }
    [CATransaction commit];
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Animation
//------------------------------------------------------------------------------

- (void)advancePosition
{
    _position++;
    if (_position >= _numFins) {
        _position = 0;
    }

    CALayer *fin = (CALayer *)_finLayers[_position];

    // Set the next fin to full opacity, but do it immediately, without any animation
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    fin.opacity = 1.0;
    [CATransaction commit];

    // Tell that fin to animate its opacity to transparent.
    fin.opacity = _fadeDownOpacity;

    [self setNeedsDisplay];
}

- (void)setupAnimTimer
{
    // Just to be safe kill any existing timer.
    [self disposeAnimTimer];

    // Why animate if not visible?  viewDidMoveToWindow will re-call this method when needed.
    _animationTimer = [NSTimer timerWithTimeInterval:(NSTimeInterval)0.05
                                               target:self
                                             selector:@selector(advancePosition)
                                             userInfo:nil
                                              repeats:YES];

    [_animationTimer setFireDate:[NSDate date]];
    [[NSRunLoop currentRunLoop] addTimer:_animationTimer forMode:NSRunLoopCommonModes];
    [[NSRunLoop currentRunLoop] addTimer:_animationTimer forMode:NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop] addTimer:_animationTimer forMode:NSEventTrackingRunLoopMode];
}

- (void)disposeAnimTimer
{
    [_animationTimer invalidate];
    _animationTimer = nil;
}

- (void)startProgressAnimation
{
    self.hidden = NO;
    _isRunning = YES;
    _position = _numFins - 1;
    
    [self setNeedsDisplay];

    [self setupAnimTimer];
}

- (void)stopProgressAnimation
{
    _isRunning = NO;

    [self disposeAnimTimer];

    [self setNeedsDisplay];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Determinate indicator drawing
//------------------------------------------------------------------------------

- (void)drawInContext:(CGContextRef)ctx
{
    CGContextClearRect(ctx, self.bounds);

    if (!_isDeterminate) {
        [super drawInContext:ctx];
        return;
    }

    CGFloat maxSize = (self.bounds.size.width >= self.bounds.size.height) ? self.bounds.size.height : self.bounds.size.width;
    CGFloat lineWidth = 1 + (0.01 * maxSize);
    CGPoint circleCenter = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    CGFloat circleRadius = (maxSize - lineWidth) / 2.1;

    CGContextSetFillColorWithColor(ctx, _foreColor);
    CGContextSetStrokeColorWithColor(ctx, _foreColor);
    CGContextSetLineWidth(ctx, lineWidth);

    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, circleCenter.x + circleRadius, circleCenter.y);
    CGContextAddEllipseInRect(ctx, CGRectMake(circleCenter.x-circleRadius, circleCenter.y-circleRadius, 2*circleRadius, 2*circleRadius));
    CGContextClosePath(ctx);
    CGContextStrokePath(ctx);

    if (_doubleValue > 0) {
        CGFloat pieRadius = circleRadius - 2 * lineWidth;
        
        CGContextBeginPath(ctx);
        CGContextMoveToPoint(ctx, circleCenter.x, circleCenter.y);
        CGContextAddLineToPoint(ctx, circleCenter.x, circleCenter.y+pieRadius);
        CGContextAddArc(ctx, circleCenter.x, circleCenter.y, pieRadius, M_PI_2, M_PI_2 - (2*M_PI*(_doubleValue/_maxValue)), 1);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
    }
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Properties and Accessors
//------------------------------------------------------------------------------

@synthesize maxValue = _maxValue;
@synthesize isRunning = _isRunning;

// Can't use @synthesize because we need to convert NSColor <-> CGColor
- (NSColor *)color
{
    // Need to convert from CGColor to NSColor
    return [NSColor colorWithCGColor:_foreColor];
}
- (void)setColor:(NSColor *)newColor
{
    // Need to convert from NSColor to CGColor
    CGColorRef cgColor = CGColorRetain([newColor CGColor]);

    if (nil != _foreColor) {
        CGColorRelease(_foreColor);
    }
    _foreColor = cgColor;

    // Update do all of the fins to this new color, at once, immediately
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    for (CALayer *fin in _finLayers) {
        fin.backgroundColor = cgColor;
    }
    [CATransaction commit];
    
    [self setNeedsDisplay];
}

// Can't use @synthesize because we need the custom setters and atomic properties
// cannot pair custom setters and synthesized getters.

- (BOOL)isDeterminate {
    return _isDeterminate;
}

- (void)setIsDeterminate:(BOOL)determinate {
    _isDeterminate = determinate;
    [self setupType];
    [self setNeedsDisplay];
}

- (double)doubleValue {
    return _doubleValue;
}

- (void)setDoubleValue:(double)doubleValue {
    _doubleValue = doubleValue;
    [self setNeedsDisplay];
}

- (void)toggleProgressAnimation
{
    if (_isRunning) {
        [self stopProgressAnimation];
    }
    else {
        [self startProgressAnimation];
    }
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Helper Methods
//------------------------------------------------------------------------------

- (void)setupType {
    if (_isDeterminate)
        [self setupDeterminate];
    else
        [self setupIndeterminate];
}

- (void)setupIndeterminate {
    [self createFinLayers];
    if (_isRunning) {
        [self setupAnimTimer];
    }
}

- (void)setupDeterminate {
    if (_isRunning) {
        [self disposeAnimTimer];
    }
    [self removeFinLayers];
    self.hidden = NO;
}

- (void)createFinLayers
{
    [self removeFinLayers];

    // Create new fin layers
    _finLayers = [[NSMutableArray alloc] initWithCapacity:_numFins];

    CGRect finBounds = [self finBoundsForCurrentBounds];
    CGPoint finAnchorPoint = [self finAnchorPointForCurrentBounds];
    CGPoint finPosition = CGPointMake([self bounds].size.width/2, [self bounds].size.height/2);
    CGFloat finCornerRadius = finBounds.size.width/2;

    for (NSUInteger i=0; i<_numFins; i++) {
        CALayer *newFin = [CALayer layer];

        newFin.bounds = finBounds;
        newFin.anchorPoint = finAnchorPoint;
        newFin.position = finPosition;
        newFin.transform = CATransform3DMakeRotation(i*(-6.282185/_numFins), 0.0, 0.0, 1.0);
        newFin.cornerRadius = finCornerRadius;
        newFin.backgroundColor = _foreColor;

        // Set the fin's initial opacity
        [CATransaction begin];
        [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
        newFin.opacity = _fadeDownOpacity;
        [CATransaction commit];

        // set the fin's fade-out time (for when it's animating)
        CABasicAnimation *anim = [CABasicAnimation animation];
        anim.duration = 0.7f;
        NSDictionary* actions = @{@"opacity": anim};
        [newFin setActions:actions];

        [self addSublayer: newFin];
        [_finLayers addObject:newFin];
    }
}

- (void)removeFinLayers
{
    for (CALayer *finLayer in _finLayers) {
        [finLayer removeFromSuperlayer];
    }
    _finLayers = nil;
}

- (CGRect)finBoundsForCurrentBounds
{
    CGSize size = [self bounds].size;
    CGFloat minSide = size.width > size.height ? size.height : size.width;
    CGFloat width = minSide * 0.095f;
    CGFloat height = minSide * 0.30f;
    return CGRectMake(0,0,width,height);
}

- (CGPoint)finAnchorPointForCurrentBounds
{
    CGSize size = [self bounds].size;
    CGFloat minSide = size.width > size.height ? size.height : size.width;
    CGFloat height = minSide * 0.30f;
    return CGPointMake(0.5, -0.9*(minSide-height)/minSide);
}

@end
