/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTTextView.h"

#import <QuartzCore/QuartzCore.h>

#import <React/RCTUtils.h>
#import <React/NSView+React.h>
#import <React/NSBezierPath+CGPath.h>

#import "RCTTextShadowView.h"

@implementation RCTTextView
{
  CAShapeLayer *_highlightLayer;


  NSArray<NSView *> *_Nullable _descendantViews;
  NSTextStorage *_Nullable _textStorage;
  CGRect _contentFrame;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
//    self.isAccessibilityElement = YES;
//    self.accessibilityTraits |= UIAccessibilityTraitStaticText;
//    self.contentMode = UIViewContentModeRedraw;
  }
  return self;
}

- (NSString *)description
{
  NSString *superDescription = super.description;
  NSRange rightBracketRange = [superDescription rangeOfString:@">"];
  NSString *replacement = [NSString stringWithFormat:@"; reactTag: %@; text: %@>", self.reactTag, _textStorage.string];
  return [superDescription stringByReplacingCharactersInRange:rightBracketRange withString:replacement];
}

















- (void)reactSetFrame:(CGRect)frame
{
  // Text looks super weird if its frame is animated.
  // This disables the frame animation, without affecting opacity, etc.
  [CALayer performWithoutAnimation:^{
    [super reactSetFrame:frame];
  }];
}

- (void)setTransform:(CATransform3D)transform
{
  _transform = transform;
  [self ensureLayerExists];
  [self applyTransform:self.layer];
}

- (void)applyTransform:(CALayer *)layer
{
  if (!CATransform3DEqualToTransform(_transform, layer.transform)) {
    layer.transform = _transform;
    // Enable edge antialiasing in perspective transforms
    layer.edgeAntialiasingMask = !(_transform.m34 == 0.0f);
  }
}

- (void)didUpdateReactSubviews
{
  // Do nothing, as subviews are managed by `setTextStorage:` method
}

- (void)setTextStorage:(NSTextStorage *)textStorage
          contentFrame:(CGRect)contentFrame
       descendantViews:(NSArray<NSView *> *)descendantViews
{
  // On macOS when a large number of flex layouts are being performed, such
  // as when a window is being resized, AppKit can throw an uncaught exception
  // (-[NSConcretePointerArray pointerAtIndex:]: attempt to access pointer at index ...)
  // during the dealloc of NSLayoutManager.  The _textStorage and its
  // associated NSLayoutManager dealloc later in an autorelease pool.
  // Manually removing the layout manager from _textStorage prior to release
  // works around this issue in AppKit.
  NSArray<NSLayoutManager *> *managers = [_textStorage layoutManagers];
  for (NSLayoutManager *manager in managers) {
    [_textStorage removeLayoutManager:manager];
  }

  _textStorage = textStorage;
  _contentFrame = contentFrame;

  // FIXME: Optimize this.
  for (NSView *view in _descendantViews) {
    [view removeFromSuperview];
  }

  _descendantViews = descendantViews;

  for (NSView *view in descendantViews) {
    [self addSubview:view];
  }

  [self setNeedsDisplay:YES];
}

- (void)drawRect:(CGRect)rect
{
  if (!_textStorage) {
    return;
  }


  NSLayoutManager *layoutManager = _textStorage.layoutManagers.firstObject;
  NSTextContainer *textContainer = layoutManager.textContainers.firstObject;

  NSRange glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
  [layoutManager drawBackgroundForGlyphRange:glyphRange atPoint:_contentFrame.origin];
  [layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:_contentFrame.origin];

  __block NSBezierPath *highlightPath = nil;
  NSRange characterRange = [layoutManager characterRangeForGlyphRange:glyphRange
                                                     actualGlyphRange:NULL];
  [_textStorage enumerateAttribute:RCTTextAttributesIsHighlightedAttributeName
                           inRange:characterRange
                           options:0
                        usingBlock:
    ^(NSNumber *value, NSRange range, __unused BOOL *stop) {
      if (!value.boolValue) {
        return;
      }

      [layoutManager enumerateEnclosingRectsForGlyphRange:range
                                 withinSelectedGlyphRange:range
                                          inTextContainer:textContainer
                                               usingBlock:
        ^(CGRect enclosingRect, __unused BOOL *anotherStop) {
          NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:CGRectInset(enclosingRect, -2, -2) xRadius:2 yRadius:2];
          if (highlightPath) {
            [highlightPath appendBezierPath:path];
          } else {
            highlightPath = path;
          }
        }
      ];
  }];

  if (highlightPath) {
    if (!_highlightLayer) {
      _highlightLayer = [CAShapeLayer layer];
      _highlightLayer.fillColor = [NSColor colorWithWhite:0 alpha:0.25].CGColor;
      [self.layer addSublayer:_highlightLayer];
    }
    _highlightLayer.position = _contentFrame.origin;
    CGMutablePathRef path = CGPathCreateMutable();
    [highlightPath applyToCGPath:path];
    _highlightLayer.path = path;
    CGPathRelease(path);
  } else {
    [_highlightLayer removeFromSuperlayer];
    _highlightLayer = nil;
  }
}


- (NSNumber *)reactTagAtPoint:(CGPoint)point
{
  NSNumber *reactTag = self.reactTag;

  CGFloat fraction;
  NSLayoutManager *layoutManager = _textStorage.layoutManagers.firstObject;
  NSTextContainer *textContainer = layoutManager.textContainers.firstObject;
  NSUInteger characterIndex = [layoutManager characterIndexForPoint:point
                                                    inTextContainer:textContainer
                           fractionOfDistanceBetweenInsertionPoints:&fraction];

  // If the point is not before (fraction == 0.0) the first character and not
  // after (fraction == 1.0) the last character, then the attribute is valid.
  if (_textStorage.length > 0 && (fraction > 0 || characterIndex > 0) && (fraction < 1 || characterIndex < _textStorage.length - 1)) {
    reactTag = [_textStorage attribute:RCTTextAttributesTagAttributeName atIndex:characterIndex effectiveRange:NULL];
  }

  return reactTag;
}

- (void)viewDidMoveToWindow
{
  [super viewDidMoveToWindow];

  if (!self.window) {
    self.layer.contents = nil;
    if (_highlightLayer) {
      [_highlightLayer removeFromSuperlayer];
      _highlightLayer = nil;
    }
  } else if (_textStorage) {
    [self setNeedsDisplay:YES];
  }
}

#pragma mark - Accessibility

- (NSString *)accessibilityLabel
{
  NSString *superAccessibilityLabel = [super accessibilityLabel];
  if (superAccessibilityLabel) {
    return superAccessibilityLabel;
  }
  return _textStorage.string;
}

































- (BOOL)canBecomeFirstResponder
{
  return _selectable;
}

- (BOOL)tryToPerform:(SEL)action with:(id)object
{
  if (_selectable && action == @selector(copy:)) {
    return YES;
  }
  
  return [self.nextResponder tryToPerform:action with:object];
}

- (void)copy:(id)sender
{
#if !TARGET_OS_TV
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents]; [pasteboard writeObjects:@[_textStorage]];
#endif
}

- (BOOL)isFlipped
{
  return YES;
}

@end
