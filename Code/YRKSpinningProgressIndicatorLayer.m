//
//  YRKSpinningProgressIndicatorLayer.m
//  SPILDemo
//
//  Copyright 2009 Kelan Champagne. All rights reserved.
//

#import "YRKSpinningProgressIndicatorLayer.h"


#define INDETERMINATE_FADE_ANIMATION    1

NSString * const RotationAnimationKey = @"rotationAnimation";
NSString * const FadeAnimationKey = @"opacity";

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

// Helper Methods
- (void)setupType;
- (void)setupIndeterminate;
- (void)setupDeterminate;

- (void)removeFinLayers;
- (void)createFinLayers;

@end


@implementation YRKSpinningProgressIndicatorLayer {
    NSTimer *_animationTimer;
    NSUInteger _position;
    
    CALayer *_finLayersRoot;
    NSMutableArray *_finLayers;
    NSMutableArray *_finLayerRotationValues;
    
    double _doubleValue;
    
    CALayer *_pieLayersRoot;
    CAShapeLayer *_pieOutline;
    CAShapeLayer *_pieChartShape;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Init, Dealloc, etc
//------------------------------------------------------------------------------

- (instancetype)init
{
    return [self initWithIndeterminateCycleDuration:0.7
                               determinateTweenTime:NAN]; // Use Core Animation default.
}

- (instancetype)initWithIndeterminateCycleDuration:(CFTimeInterval)indeterminateCycleDuration
                              determinateTweenTime:(CFTimeInterval)determinateTweenTime
{
    self = [super init];
    if (self) {
        _indeterminateCycleDuration = indeterminateCycleDuration;
        
        _position = 0;
        _numFins = 12;
        _finLayers = [[NSMutableArray alloc] initWithCapacity:_numFins];

        _finLayersRoot = [CALayer layer];
        //_finLayersRoot.anchorPoint = CGPointMake(0.5, 0.5); // This is the default.
        [self addSublayer:_finLayersRoot];

        _finLayerRotationValues = [NSMutableArray array];
        
        _fullOpacity = 1.0f;
        _indeterminateMinimumOpacity = 0.05f;
        _isRunning = NO;
        self.color = [NSColor blackColor];
        [self setBounds:CGRectMake(0.0f, 0.0f, 10.0f, 10.0f)];
        self.isDeterminate = NO;
        _determinateTweenTime = determinateTweenTime;
        self.maxValue = 100.0;
        self.doubleValue = 0.0;
        
        [self createFinLayers];
        
        _pieLayersRoot = [CALayer layer];
        [self createDeterminateLayers];
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

    // Do the resizing all at once, immediately.
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    
    // Resize the fins.
    const CGRect bounds = newBounds;
    YRKFinGeometry finGeo = finGeometryForBounds(bounds);

    _finLayersRoot.bounds = bounds;
    _finLayersRoot.position = yrkCGRectGetCenter(bounds);
    
    for (CALayer *fin in _finLayers) {
        fin.bounds = finGeo.bounds;
        fin.anchorPoint = finGeo.anchorPoint;
        fin.position = finGeo.position;
        fin.cornerRadius = finGeo.cornerRadius;
    }
    
    // Scale pie.
    YRKPieGeometry pieGeo = pieGeometryForBounds(self.bounds);
    
    _pieLayersRoot.bounds = pieGeo.bounds;
    _pieLayersRoot.position = yrkCGRectGetCenter(pieGeo.bounds);
    
    updatePieOutlineDimensionsForGeometry(_pieOutline, pieGeo);
    updatePieChartDimensionsForGeometry(_pieChartShape, pieGeo);
    
    [CATransaction commit];
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Animation
//------------------------------------------------------------------------------

- (void)startProgressAnimation
{
    _isRunning = YES;
    _position = _numFins - 1;
    
    [self addSublayer:_finLayersRoot];
    
    [self animateFinLayers];
}

- (void)stopProgressAnimation
{
    _isRunning = NO;

    [self deanimateFinLayers];
    
    [_finLayersRoot removeFromSuperlayer];
}

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
    
    _pieOutline.strokeColor = cgColor;
    _pieChartShape.strokeColor = cgColor;
    
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
}

- (double)doubleValue {
    return _doubleValue;
}

- (void)setDoubleValue:(double)doubleValue {
    _doubleValue = doubleValue;
    
    if (!isnan(_determinateTweenTime)) {
        [CATransaction begin];
        
        // This controls the transition from one doubleValue to the next.
        [CATransaction setAnimationDuration:_determinateTweenTime];
    }
    
    _pieChartShape.strokeEnd = doubleValue/_maxValue;
    
    if (!isnan(_determinateTweenTime)) {
        [CATransaction commit];
    }
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
    [_pieLayersRoot removeFromSuperlayer];
    [self addSublayer:_finLayersRoot];

}

- (void)setupDeterminate {
    [self stopProgressAnimation];
    
    [_finLayersRoot removeFromSuperlayer];
    [self addSublayer:_pieLayersRoot];

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
    
    [_finLayerRotationValues removeAllObjects];
    
    for (NSUInteger i = 0; i < _numFins; i++) {
        CALayer *newFin = [CALayer layer];
        
        CGFloat rotationAngle = i * rotationAngleBetweenFins;
        
        newFin.bounds = finGeo.bounds;
        newFin.anchorPoint = finGeo.anchorPoint;
        newFin.position = finGeo.position;
        newFin.transform = CATransform3DMakeRotation(rotationAngle, 0.0, 0.0, 1.0);
        newFin.cornerRadius = finGeo.cornerRadius;
        newFin.backgroundColor = _foreColor;

        [_finLayerRotationValues addObject:@(rotationAngle)];

        newFin.opacity = [self initialOpacityForFinAtIndex:i];
        
        [_finLayersRoot addSublayer:newFin];
        [_finLayers addObject:newFin];
    }

    [CATransaction commit];
}

- (CGFloat)initialOpacityForFinAtIndex:(NSUInteger)i
{
    CGFloat fadePercent = 1.0 - (CGFloat)i/(_numFins-1);
    float opacity = _indeterminateMinimumOpacity + ((_fullOpacity - _indeterminateMinimumOpacity) * fadePercent);
    return opacity;
}

- (void)animateFinLayers
{
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    
    [self deanimateFinLayers];
    
#   if INDETERMINATE_FADE_ANIMATION
    NSUInteger i = 0;
    NSNumber *fullOpacityNum = @(_fullOpacity);
    NSNumber *fadeDownOpacityNum = @(_indeterminateMinimumOpacity);
    for (CALayer *finLayer in _finLayers) {
        CFTimeInterval now = [finLayer convertTime:CACurrentMediaTime()
                                         fromLayer:nil];
        
        finLayer.opacity = _indeterminateMinimumOpacity;
        CABasicAnimation *fadeOut = [CABasicAnimation animationWithKeyPath:FadeAnimationKey];
        
        fadeOut.fromValue = fullOpacityNum;
        fadeOut.toValue = fadeDownOpacityNum;
        
        fadeOut.duration = _indeterminateCycleDuration;
        CFTimeInterval timeOffset = _indeterminateCycleDuration - (_indeterminateCycleDuration * (CFTimeInterval)i/(_numFins-1));
        fadeOut.beginTime = now - timeOffset;
        fadeOut.fillMode = kCAFillModeBackwards;
        fadeOut.repeatCount = HUGE_VALF;
        
        [finLayer addAnimation:fadeOut
                        forKey:FadeAnimationKey];
        
        i++;
    }
#   else
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
#   endif
    
    [CATransaction commit];
}

- (void)deanimateFinLayers
{
    [CATransaction begin];
    [CATransaction setValue:@YES forKey:kCATransactionDisableActions];
    
#   if INDETERMINATE_FADE_ANIMATION
    for (CALayer *finLayer in _finLayers) {
        [finLayer removeAnimationForKey:FadeAnimationKey];
    }
#   else
    [_finLayersRoot removeAnimationForKey:RotationAnimationKey];
#   endif
    
    [CATransaction commit];
}

- (void)removeFinLayers
{
    for (CALayer *finLayer in _finLayers) {
        [finLayer removeFromSuperlayer];
    }
    [_finLayers removeAllObjects];
}

// These are proportional to the size of the drawn determinate progress indicator.
const CGFloat OutlineWidthPercentage = 1.0/16;
const CGFloat PieChartPaddingPercentage = OutlineWidthPercentage/2; // The padding around the pie chart.

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
    
    // The pie chart is drawn using a circular line
    // with a line width equal to twice the radius.
    // So we draw from every point on this line, which you can picture as a centerline,
    // radius units towards and away from the center, reaching the center exactly.
    // This way, we get a full circle, if the full length of the line is draw.
    const CGFloat pieChartExtraInset = (pieGeo.outerEdgeLength * PieChartPaddingPercentage);
    const CGFloat pieChartInset = (outerRadius + pieGeo.outlineWidth + pieChartExtraInset) / 2;
    const CGFloat pieChartCenterlineRadius = outerRadius - pieChartInset;
    const CGFloat pieChartOutlineRadius = pieChartCenterlineRadius * 2;
    const CGRect pieChartRect = CGRectInset(pieGeo.bounds, pieChartInset, pieChartInset);

    CGAffineTransform pieChartTransform = CGAffineTransformForRotatingRectAroundCenter(pieChartRect, degreesToRadians(90.0));
    CGAffineTransform pieChartFlip = CGAffineTransformForScalingRectAroundCenter(pieChartRect, -1.0, 1.0); // Flip left<->right.
    pieChartTransform = CGAffineTransformConcat(pieChartTransform, pieChartFlip);
    
    CGPathRef pieChartPath = CGPathCreateWithEllipseInRect(pieChartRect, &pieChartTransform);
    pieChartShape.path = pieChartPath;
    CGPathRelease(pieChartPath);
    
    pieChartShape.lineWidth = pieChartOutlineRadius;
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
    _pieChartShape.opacity = _fullOpacity;
    updatePieOutlineDimensionsForGeometry(_pieOutline, pieGeo);
    
    // Draw only the line of the circular outline shape.
    _pieOutline.fillColor =    clearColor;
    _pieOutline.strokeColor =  foregroundColor;
    
    // Create the pie chart shape layer. It should fill from the center,
    // all the way out (excluding some extra space (equal to the width of
    // the outline)).
    _pieChartShape = [CAShapeLayer layer];
    _pieChartShape.opacity = _fullOpacity;
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
