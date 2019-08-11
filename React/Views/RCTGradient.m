// The MIT License (MIT)
//
// Copyright (c) 2014 Jernej Strasner
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "RCTGradient.h"

#import "RCTLog.h"
#import "RCTUtils.h"
#import "UIImageUtils.h"

// Info struct to pass to shading function
struct _JSTFunctionInfo {
    CGFloat startColor[4];
    CGFloat endColor[4];
    CGFloat slopeFactor;
};
typedef struct _JSTFunctionInfo JSTFunctionInfo;
typedef struct _JSTFunctionInfo* JSTFunctionInfoRef;

static JSTFunctionInfoRef JSTFunctionInfoCreate() {
    return (JSTFunctionInfoRef)malloc(sizeof(JSTFunctionInfo));
}

static void JSTFunctionInfoRelease(JSTFunctionInfoRef info) {
    if (info != NULL) {
        free(info);
    }
}

// Distributes values on a slope aka. ease-in ease-out
static float JSTSlope(float x, float A)
{
    float p = powf(x, A);
    return p/(p + powf(1.0f-x, A));
}

// This is the callback of our shading function.
// info:    color and slope information
// inData:  contains a single float that gives is the current position within the gradient
// outData: we fill this with the color to display at the given position
static void JSTShadingFunction(void *infoPtr, const CGFloat *inData, CGFloat *outData)
{
    JSTFunctionInfo info = *(JSTFunctionInfo*)infoPtr; // Info struct with colors and parameters
    float p = inData[0]; // Position in gradient
    float q = JSTSlope(p, info.slopeFactor); // Slope value
    outData[0] = info.startColor[0] + (info.endColor[0] - info.startColor[0])*q;
    outData[1] = info.startColor[1] + (info.endColor[1] - info.startColor[1])*q;
    outData[2] = info.startColor[2] + (info.endColor[2] - info.startColor[2])*q;
    outData[3] = info.startColor[3] + (info.endColor[3] - info.startColor[3])*q;
}

@implementation RCTGradient
{
    CGColorSpaceRef _colorSpace;
    CGFloat _startColorComps[4];
    CGFloat _endColorComps[4];
    CGFunctionRef _function;
    JSTFunctionInfoRef _functionInfo;
    BOOL _opaque;
}

- (instancetype)init
{
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        _colorSpace = CGColorSpaceCreateDeviceRGB();
        _startColor = [NSColor clearColor];
        _endColor = [NSColor clearColor];
        _startPoint = CGPointMake(0, 0.5);
        _endPoint = CGPointMake(1, 0.5);
        _slopeFactor = 1;
    }
    return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:unused)

- (void)dealloc
{
    JSTFunctionInfoRelease(_functionInfo);
    CGFunctionRelease(_function);
    CGColorSpaceRelease(_colorSpace);
}

- (void)setStartColor:(NSColor *)startColor
{
    if (_startColor == startColor) return;
    _startColor = startColor;

    [startColor getRed:_startColorComps green:_startColorComps+1 blue:_startColorComps+2 alpha:_startColorComps+3];
}

- (void)setEndColor:(NSColor *)endColor
{
    if (_endColor == endColor) return;
    _endColor = endColor;

    [endColor getRed:_endColorComps green:_endColorComps+1 blue:_endColorComps+2 alpha:_endColorComps+3];
}

- (void)didSetProps:(NSArray<NSString *> *)changedProps
{
    for (NSString *prop in changedProps) {
        if ([prop isEqualToString:@"startColor"] ||
            [prop isEqualToString:@"endColor"] ||
            [prop isEqualToString:@"slopeFactor"]) {
            [self _createShadingFunction];
            break;
        }
    }
    [self setNeedsDisplay:YES];
}

- (BOOL)isOpaque
{
  return _endColorComps[3] == 1 && _startColorComps[3] == 1;
}

- (void)_createShadingFunction
{
    // Shading function info
    JSTFunctionInfoRelease(_functionInfo);
    _functionInfo = JSTFunctionInfoCreate();
    memcpy(_functionInfo->startColor, _startColorComps, sizeof(CGFloat)*4);
    memcpy(_functionInfo->endColor, _endColorComps, sizeof(CGFloat)*4);
    _functionInfo->slopeFactor = _slopeFactor;

    // Define the shading callbacks
    CGFunctionCallbacks callbacks = {0, JSTShadingFunction, NULL};

    // As input to our function we want 1 value in the range [0.0, 1.0].
    // This is our position within the gradient.
    size_t domainDimension = 1;
    CGFloat domain[2] = {0.0f, 1.0f};

    // The output of our shading function are 4 values, each in the range [0.0, 1.0].
    // By specifying 4 ranges here, we limit each color component to that range. Values outside of the range get clipped.
    size_t rangeDimension = 4;
    CGFloat range[8] = {
        0.0f, 1.0f, // R
        0.0f, 1.0f, // G
        0.0f, 1.0f, // B
        0.0f, 1.0f  // A
    };

    // Create the shading function
    CGFunctionRelease(_function);
    _function = CGFunctionCreate(_functionInfo, domainDimension, domain, rangeDimension, range, &callbacks);
}

- (void)displayLayer:(CALayer *)layer
{
    [super displayLayer:layer];

    const CGSize size = self.bounds.size;
    UIGraphicsBeginImageContextWithOptions(size, self.isOpaque, 0.0);

    // Preserve contents from super call.
    NSImage *contents = layer.contents;
    [contents drawInRect:self.bounds];

    // Draw the gradient.
    [self drawRect:self.bounds];

    // Fetch the drawing bitmap.
    contents = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    layer.contents = contents;
    layer.magnificationFilter = kCAFilterNearest;
    layer.needsDisplayOnBoundsChange = YES;
}

- (void)drawRect:(CGRect)rect
{
    // Prepare general variables
    CGContextRef context = UIGraphicsGetCurrentContext();

    // Create the shading object
    CGPoint startPoint = CGPointMake(_startPoint.x * rect.size.width, _startPoint.y * rect.size.height);
    CGPoint endPoint = CGPointMake(_endPoint.x * rect.size.width, _endPoint.y * rect.size.height);
    CGShadingRef shading = CGShadingCreateAxial(_colorSpace, startPoint, endPoint, _function, _drawsBeforeStart, _drawsAfterEnd);

    // Draw the shading
    CGContextDrawShading(context, shading);

    // Clean up
    CGShadingRelease(shading);
}

@end
