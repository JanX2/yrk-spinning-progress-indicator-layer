//
//  YRKSpinningProgressIndicatorLayer.m
//  SPILDemo
//
//  Copyright 2009 Kelan Champagne. All rights reserved.
//

#import "YRKSpinningProgressIndicatorLayer.h"


#define TRADITIONAL_MODE    0
#define TRADITIONAL_DETERMINATE   0

#if !TRADITIONAL_MODE
NSString * const RotationAnimationKey = @"rotationAnimation";
#endif

typedef struct _YRKFinGeometry {
    CGRect bounds;
    CGPoint anchorPoint;
    CGPoint position;
    CGFloat cornerRadius;
} YRKFinGeometry;

typedef struct _YRKPieGeometry {
    CGRect bounds;
    CGFloat outerEdgeLength;
    CGFloat outlineWidth;
} YRKPieGeometry;

@interface YRKSpinningProgressIndicatorLayer ()

#if TRADITIONAL_MODE
// Animation
- (void)advancePosition;
#endif

// Helper Methods
- (void)setupType;
- (void)setupIndeterminate;
- (void)setupDeterminate;

- (void)removeFinLayers;
- (void)createFinLayers;

#if TRADITIONAL_MODE
- (void)setupAnimTimer;
- (void)disposeAnimTimer;
#endif

@end


@implementation YRKSpinningProgressIndicatorLayer {
    NSTimer *_animationTimer;
    NSUInteger _position;
    
    CALayer *_finLayersRoot;
    NSMutableArray *_finLayers;
#if !TRADITIONAL_MODE
    NSMutableArray *_finLayerRotationValues;
#endif
    
    double _doubleValue;
    
#if !TRADITIONAL_DETERMINATE
    CALayer *_pieLayersRoot;
    CAShapeLayer *_pieOutline;
    CAShapeLayer *_pieChartShape;
#endif
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Init, Dealloc, etc
//------------------------------------------------------------------------------

- (instancetype)init
{
    self = [super init];
    if (self) {
        _indeterminateCycleDuration = 0.7;
        
        _position = 0;
        _numFins = 12;
        _finLayers = [[NSMutableArray alloc] initWithCapacity:_numFins];

        _finLayersRoot = [CALayer layer];
        //_finLayersRoot.anchorPoint = CGPointMake(0.5, 0.5); // This is the default.
        [self addSublayer:_finLayersRoot];

#if !TRADITIONAL_MODE
        _finLayerRotationValues = [NSMutableArray array];
#endif
        
        _fullOpacity = 1.0f;
        _fadeDownOpacity = 0.05f;
        _isRunning = NO;
        self.color = [NSColor blackColor];
        [self setBounds:CGRectMake(0.0f, 0.0f, 10.0f, 10.0f)];
        self.isDeterminate = NO;
        _determinateTweenTime = NAN; // Use Core Animation default.
        self.maxValue = 100.0;
        self.doubleValue = 0.0;
        
        [self createFinLayers];
        
#if !TRADITIONAL_DETERMINATE
        _pieLayersRoot = [CALayer layer];
        [self createDeterminateLayers];
#endif
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

    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    
    // Resize the fins
    const CGRect bounds = newBounds;
    YRKFinGeometry finGeo = finGeometryForBounds(bounds);

    _finLayersRoot.bounds = bounds;
    _finLayersRoot.position = yrkCGRectGetCenter(bounds);
    
    // do the resizing all at once, immediately
    for (CALayer *fin in _finLayers) {
        fin.bounds = finGeo.bounds;
        fin.anchorPoint = finGeo.anchorPoint;
        fin.position = finGeo.position;
        fin.cornerRadius = finGeo.cornerRadius;
    }
    
#if !TRADITIONAL_DETERMINATE
    // Scale pie.
    YRKPieGeometry pieGeo = pieGeometryForBounds(self.bounds);
    
    _pieLayersRoot.bounds = pieGeo.bounds;
    _pieLayersRoot.position = yrkCGRectGetCenter(pieGeo.bounds);
    
    updatePieOutlineDimensionsForGeometry(_pieOutline, pieGeo);
    updatePieChartDimensionsForGeometry(_pieChartShape, pieGeo);
#endif
    
    [CATransaction commit];
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Animation
//------------------------------------------------------------------------------

#if TRADITIONAL_MODE
- (void)advancePosition
{
    _position++;
    if (_position >= _numFins) {
        _position = 0;
    }
    
    CALayer *fin = (_finLayers.count > 0) ? (CALayer *)_finLayers[_position] : nil;

    // Set the next fin to full opacity, but do it immediately, without any animation
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    fin.opacity = _fullOpacity;
    [CATransaction commit];

    // Tell that fin to animate its opacity to transparent.
    fin.opacity = _fadeDownOpacity;
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
#endif

- (void)startProgressAnimation
{
    _isRunning = YES;
    _position = _numFins - 1;
    
#if TRADITIONAL_MODE
    [self setupAnimTimer];
#endif
    
    [self addSublayer:_finLayersRoot];
    
    [self animateFinLayers];
}

- (void)stopProgressAnimation
{
    _isRunning = NO;

    [self deanimateFinLayers];
    
#if TRADITIONAL_MODE
    [self disposeAnimTimer];
#endif

    [_finLayersRoot removeFromSuperlayer];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Determinate indicator drawing
//------------------------------------------------------------------------------

#if TRADITIONAL_DETERMINATE
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
#endif

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Properties and Accessors
//------------------------------------------------------------------------------

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

    // Update all of the fins to this new color, at once, immediately
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    for (CALayer *fin in _finLayers) {
        fin.backgroundColor = cgColor;
    }
    
#if !TRADITIONAL_DETERMINATE
    _pieOutline.strokeColor = cgColor;
    _pieChartShape.strokeColor = cgColor;
#endif
    
    [CATransaction commit];
}

// Can't use @synthesize because we need the custom setters and atomic properties
// cannot pair custom setters and synthesized getters.

- (BOOL)isDeterminate {
    return _isDeterminate;
}

- (void)setIsDeterminate:(BOOL)determinate {
    _isDeterminate = determinate;
    [self setupType];
#if TRADITIONAL_DETERMINATE
    [self setNeedsDisplay];
#else
    
#endif
}

- (double)doubleValue {
    return _doubleValue;
}

- (void)setDoubleValue:(double)doubleValue {
    _doubleValue = doubleValue;
#if TRADITIONAL_DETERMINATE
    [self setNeedsDisplay];
#else
    if (!isnan(_determinateTweenTime)) {
        [CATransaction begin];
        
        // This controls the transition from one doubleValue to the next.
        [CATransaction setAnimationDuration:_determinateTweenTime];
    }
    
    _pieChartShape.strokeEnd = doubleValue/_maxValue;
    
    if (!isnan(_determinateTweenTime)) {
        [CATransaction commit];
    }
#endif
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
#if !TRADITIONAL_DETERMINATE
    [_pieLayersRoot removeFromSuperlayer];
    [self addSublayer:_finLayersRoot];
#endif

#if TRADITIONAL_MODE
    if (_isRunning) {
        [self setupAnimTimer];
    }
#endif
}

- (void)setupDeterminate {
#if TRADITIONAL_MODE
    if (_isRunning) {
        [self disposeAnimTimer];
    }
#endif
    [self stopProgressAnimation];
    
#if !TRADITIONAL_DETERMINATE
    [_finLayersRoot removeFromSuperlayer];
    [self addSublayer:_pieLayersRoot];
#endif

}

- (void)createFinLayers
{
    [self removeFinLayers];
    
    const CGRect selfBounds = self.bounds;
    _finLayersRoot.bounds = selfBounds;
    _finLayersRoot.position = yrkCGRectGetCenter(selfBounds);
    
    // Create new fin layers
    const CGRect bounds = _finLayersRoot.bounds;
    YRKFinGeometry finGeo = finGeometryForBounds(bounds);
    
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    
    CGFloat rotationAngleBetweenFins = -2 * M_PI/_numFins;
    
#if !TRADITIONAL_MODE
    [_finLayerRotationValues removeAllObjects];
#endif
    
    for (NSUInteger i = 0; i < _numFins; i++) {
        CALayer *newFin = [CALayer layer];
        
        CGFloat rotationAngle = i * rotationAngleBetweenFins;
        
        newFin.bounds = finGeo.bounds;
        newFin.anchorPoint = finGeo.anchorPoint;
        newFin.position = finGeo.position;
        newFin.transform = CATransform3DMakeRotation(rotationAngle, 0.0, 0.0, 1.0);
        newFin.cornerRadius = finGeo.cornerRadius;
        newFin.backgroundColor = _foreColor;

#if TRADITIONAL_MODE
        // Set the fin's initial opacity
        newFin.opacity = _fadeDownOpacity;
#else
        [_finLayerRotationValues addObject:@(rotationAngle)];

        // Set the fin’s opacity.
        CGFloat fadePercent = 1.0 - (CGFloat)i/(_numFins-1);
        CGFloat opacity = _fadeDownOpacity + ((_fullOpacity - _fadeDownOpacity) * fadePercent);
        newFin.opacity = opacity;
#endif

        [_finLayersRoot addSublayer:newFin];
        [_finLayers addObject:newFin];
    }

    [CATransaction commit];
}

- (void)animateFinLayers
{
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    
    [self deanimateFinLayers];
    
#if TRADITIONAL_MODE
    for (CALayer *finLayer in _finLayers) {
        // Set the fin’s initial opacity.
        finLayer.opacity = _fadeDownOpacity;
        
        // set the fin's fade-out time (for when it's animating)
        CABasicAnimation *animation = [CABasicAnimation animation];
        animation.duration = _indeterminateCycleDuration;
        NSDictionary *actions = @{@"opacity": animation};
        [finLayer setActions:actions];
    }
#else
    CAKeyframeAnimation *animation;
    animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
    animation.duration = _indeterminateCycleDuration;
    animation.cumulative = NO;
    animation.repeatCount = HUGE_VALF;
    animation.values = _finLayerRotationValues;
    animation.removedOnCompletion = NO;
    animation.calculationMode = kCAAnimationDiscrete;
    
    [_finLayersRoot addAnimation:animation
                          forKey:RotationAnimationKey];
#endif
    
    [CATransaction commit];
}

- (void)deanimateFinLayers
{
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    
#if TRADITIONAL_MODE
    for (CALayer *finLayer in _finLayers) {
        [finLayer setActions:nil];
    }
#else
    [_finLayersRoot removeAnimationForKey:RotationAnimationKey];
#endif
    
    [CATransaction commit];
}

- (void)removeFinLayers
{
    for (CALayer *finLayer in _finLayers) {
        [finLayer removeFromSuperlayer];
    }
    [_finLayers removeAllObjects];
}

#if !TRADITIONAL_DETERMINATE
const CGFloat OutlineWidthPercentage = 0.01;
const CGFloat DeterminateLayersMarginPercentage = 0.98; // Selected to look good with current indeterminate settings.

static YRKPieGeometry pieGeometryForBounds(CGRect bounds){
    YRKPieGeometry pieGeo;
    
    // Make sure the circles will fit the frame.
    pieGeo.outerEdgeLength = shorterDimensionForSize(bounds.size);
    pieGeo.outerEdgeLength *= DeterminateLayersMarginPercentage;
    
    CGFloat xInset = (CGRectGetWidth(bounds) - pieGeo.outerEdgeLength) / 2;
    CGFloat yInset = (CGRectGetHeight(bounds) - pieGeo.outerEdgeLength) / 2;
    pieGeo.bounds = CGRectInset(bounds, xInset, yInset);
    
    pieGeo.outlineWidth = pieGeo.outerEdgeLength * OutlineWidthPercentage; // This used to be rounded.
    
    return pieGeo;
}

static void updatePieOutlineDimensionsForGeometry(CAShapeLayer *outlineShape, YRKPieGeometry pieGeo) {
    CGFloat outlineInset = pieGeo.outlineWidth / 2;
    CGRect outlineRect = CGRectInset(pieGeo.bounds, outlineInset, outlineInset);
    
    CGAffineTransform outlineTransform = CGAffineTransformForRotatingRectAroundCenter(outlineRect, degreesToRadians(90.0));
    CGAffineTransform outlineFlip = CGAffineTransformForScalingRectAroundCenter(outlineRect, -1.0, 1.0); // Flip left<->right.
    outlineTransform = CGAffineTransformConcat(outlineTransform, outlineFlip);
    
    CGPathRef outlinePath = CGPathCreateWithEllipseInRect(outlineRect, &outlineTransform);
    outlineShape.path = outlinePath;
    CGPathRelease(outlinePath);
    
    outlineShape.lineWidth = pieGeo.outlineWidth;
}

static void updatePieChartDimensionsForGeometry(CAShapeLayer *pieChartShape, YRKPieGeometry pieGeo) {
    const CGFloat outerRadius = pieGeo.outerEdgeLength / 2;
    
    const CGFloat pieChartInset = outerRadius / 2 + pieGeo.outlineWidth;
    CGRect pieChartRect = CGRectInset(pieGeo.bounds, pieChartInset, pieChartInset);
    
    CGAffineTransform pieChartTransform = CGAffineTransformForRotatingRectAroundCenter(pieChartRect, degreesToRadians(90.0));
    CGAffineTransform pieChartFlip = CGAffineTransformForScalingRectAroundCenter(pieChartRect, -1.0, 1.0); // Flip left<->right.
    pieChartTransform = CGAffineTransformConcat(pieChartTransform, pieChartFlip);
    
    CGPathRef pieChartPath = CGPathCreateWithEllipseInRect(pieChartRect, &pieChartTransform);
    pieChartShape.path = pieChartPath;
    CGPathRelease(pieChartPath);
    
    pieChartShape.lineWidth = (outerRadius - pieChartInset) * 2;
}

- (void)createDeterminateLayers
{
    [self removeDeterminateLayers];
    
    // Based on DRPieChartProgressView by David Rönnqvist:
    // https://github.com/JanX2/cocoaheads-coreanimation-samplecode
    
    YRKPieGeometry pieGeo = pieGeometryForBounds(self.bounds);
    
    _pieLayersRoot.bounds = pieGeo.bounds;
    _pieLayersRoot.position = yrkCGRectGetCenter(pieGeo.bounds);
    
    // Create new determinate layers.
    
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    
    CGColorRef foregroundColor = _foreColor;
    CGColorRef clearColor = [[NSColor clearColor] CGColor];
    
    // Calculate the radius for the outline. Since strokes are centered,
    // the shape needs to be inset half the stroke width.
    _pieOutline = [CAShapeLayer layer];
    updatePieOutlineDimensionsForGeometry(_pieOutline, pieGeo);
    
    // Draw only the line of the circular outline shape.
    _pieOutline.fillColor =    clearColor;
    _pieOutline.strokeColor =  foregroundColor;
    
    // Create the pie chart shape layer. It should fill from the center,
    // all the way out (excluding some extra space (equal to the width of
    // the outline)).
    _pieChartShape = [CAShapeLayer layer];
    updatePieChartDimensionsForGeometry(_pieChartShape, pieGeo);
    
    // We don't want to fill the pie chart since that will be visible
    // even when we change the stroke start and stroke end. Instead
    // we only draw the stroke with the width calculated above.
    _pieChartShape.fillColor =     clearColor;
    _pieChartShape.strokeColor =   foregroundColor;
    
    // Add sublayers.
    [_pieLayersRoot addSublayer:_pieOutline];
    [_pieLayersRoot addSublayer:_pieChartShape];
    
    _pieChartShape.strokeStart = 0.0;
    _pieChartShape.strokeEnd = 0.0;
    
    [CATransaction commit];
}

- (void)removeDeterminateLayers
{
    for (CALayer *pieLayer in _pieLayersRoot.sublayers) {
        [pieLayer removeFromSuperlayer];
    }
}

static inline CGFloat degreesToRadians(CGFloat degrees) {
    return degrees * M_PI / 180.0;
}

static CGAffineTransform CGAffineTransformForRotatingRectAroundCenter(CGRect rect, CGFloat angle) {
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    transform = CGAffineTransformTranslate(transform, CGRectGetMidX(rect), CGRectGetMidY(rect));
    transform = CGAffineTransformRotate(transform, angle);
    transform = CGAffineTransformTranslate(transform, -CGRectGetMidX(rect), -CGRectGetMidY(rect));
    
    return transform;
}

static CGAffineTransform CGAffineTransformForScalingRectAroundCenter(CGRect rect, CGFloat sx, CGFloat sy) {
	CGAffineTransform transform = CGAffineTransformIdentity;
	
	transform = CGAffineTransformTranslate(transform, CGRectGetMidX(rect), CGRectGetMidY(rect));
	transform = CGAffineTransformScale(transform, sx, sy);
	transform = CGAffineTransformTranslate(transform, -CGRectGetMidX(rect), -CGRectGetMidY(rect));
	
	return transform;
}
#endif


static YRKFinGeometry finGeometryForBounds(CGRect bounds) {
    YRKFinGeometry finGeometry;
    
    finGeometry.bounds = finBoundsForBounds(bounds);
    finGeometry.anchorPoint = finAnchorPoint();
    finGeometry.position = CGPointMake(bounds.size.width/2, bounds.size.height/2);
    finGeometry.cornerRadius = finGeometry.bounds.size.width/2;
    
    return finGeometry;
}

const CGFloat FinWidthPercent = 0.095;
const CGFloat FinHeightPercent = 0.30;
const CGFloat FinAnchorPointVerticalOffsetPercent = -0.63; // Aesthetically pleasing value. Also indirectly determines margin.

static CGRect finBoundsForBounds(CGRect bounds) {
    CGSize size = bounds.size;
    CGFloat minSide = shorterDimensionForSize(size);
    
    CGFloat width = minSide * FinWidthPercent;
    CGFloat height = minSide * FinHeightPercent;
    
    return CGRectMake(0, 0, width, height);
}

static CGPoint finAnchorPoint() {
    // Horizentally centered, vertically offset.
    return CGPointMake(0.5, FinAnchorPointVerticalOffsetPercent);
}

static CGPoint yrkCGRectGetCenter(CGRect rect) {
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

static inline CGFloat shorterDimensionForSize(CGSize size) {
    return MIN(size.width, size.height);
}

@end
