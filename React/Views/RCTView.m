/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTView.h"
#import <CoreImage/CIFilterBuiltins.h>

#import "RCTAutoInsetsProtocol.h"
#import "RCTBlurFilter.h"
#import "RCTBorderDrawing.h"
#import "RCTConvert.h"
#import "RCTLog.h"
#import "RCTUtils.h"
#import "NSView+React.h"
#import "UIImageUtils.h"
#import "RCTI18nUtil.h"

@implementation NSView (RCTViewUnmounting)

- (void)react_remountAllSubviews
{
  // Normal views don't support unmounting, so all
  // this does is forward message to our subviews,
  // in case any of those do support it

  for (NSView *subview in self.subviews) {
    [subview react_remountAllSubviews];
  }
}

- (void)react_updateClippedSubviewsWithClipRect:(CGRect)clipRect relativeToView:(NSView *)clipView
{
  // Even though we don't support subview unmounting
  // we do support clipsToBounds, so if that's enabled
  // we'll update the clipping

  if (self.clipsToBounds && self.subviews.count > 0) {
    clipRect = [clipView convertRect:clipRect toView:self];
    clipRect = CGRectIntersection(clipRect, self.bounds);
    clipView = self;
  }

  // Normal views don't support unmounting, so all
  // this does is forward message to our subviews,
  // in case any of those do support it

  for (NSView *subview in self.subviews) {
    [subview react_updateClippedSubviewsWithClipRect:clipRect relativeToView:clipView];
  }
}

- (NSView *)react_findClipView
{
  NSView *testView = self;
  NSView *clipView = nil;
  CGRect clipRect = self.bounds;

  // We will only look for a clipping view up the view hierarchy until we hit the root view.
  while (testView) {
    if (testView.clipsToBounds) {
      if (clipView) {
        CGRect testRect = [clipView convertRect:clipRect toView:testView];
        if (!CGRectContainsRect(testView.bounds, testRect)) {
          clipView = testView;
          clipRect = CGRectIntersection(testView.bounds, testRect);
        }
      } else {
        clipView = testView;
        clipRect = [self convertRect:self.bounds toView:clipView];
      }
    }
    if ([testView isReactRootView]) {
      break;
    }
    testView = testView.superview;
  }
  return clipView ?: self.window.contentView;
}

@end

static NSString *RCTRecursiveAccessibilityLabel(NSView *view)
{
  NSMutableString *str = [NSMutableString stringWithString:@""];
  for (NSView *subview in view.subviews) {
    NSString *label = subview.accessibilityLabel;
    if (!label) {
      label = RCTRecursiveAccessibilityLabel(subview);
    }
    if (label && label.length > 0) {
      if (str.length > 0) {
        [str appendString:@" "];
      }
      [str appendString:label];
    }
  }
  return str;
}

@implementation RCTView
{
  NSColor *_backgroundColor;
  CIFilter *_backgroundBlur;
  NSImage *_borderImage;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    _borderWidth = -1;
    _borderTopWidth = -1;
    _borderRightWidth = -1;
    _borderBottomWidth = -1;
    _borderLeftWidth = -1;
    _borderStartWidth = -1;
    _borderEndWidth = -1;
    _borderTopLeftRadius = -1;
    _borderTopRightRadius = -1;
    _borderTopStartRadius = -1;
    _borderTopEndRadius = -1;
    _borderBottomLeftRadius = -1;
    _borderBottomRightRadius = -1;
    _borderBottomStartRadius = -1;
    _borderBottomEndRadius = -1;
    _borderStyle = RCTBorderStyleSolid;
    _hitTestEdgeInsets = NSEdgeInsetsZero;
    _transform = CATransform3DIdentity;
    self.clipsToBounds = NO;
  }

  return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:unused)

- (void)setReactTag:(NSNumber *)reactTag
{
  // The default view has no reactTag.
  if (!reactTag && !self.reactTag) {
    [self ensureLayerExists];
  }

  super.reactTag = reactTag;
}

- (void)setReactLayoutDirection:(NSUserInterfaceLayoutDirection)layoutDirection
{
  if (_reactLayoutDirection != layoutDirection) {
    _reactLayoutDirection = layoutDirection;
    [self.layer setNeedsDisplay];
  }

//  if ([self respondsToSelector:@selector(setSemanticContentAttribute:)]) {
//    self.semanticContentAttribute =
//      layoutDirection == UIUserInterfaceLayoutDirectionLeftToRight ?
//        UISemanticContentAttributeForceLeftToRight :
//        UISemanticContentAttributeForceRightToLeft;
//  }
}

- (NSString *)accessibilityLabel
{
  NSString *label = super.accessibilityLabel;
  if (label) {
    return label;
  }
  return RCTRecursiveAccessibilityLabel(self);
}

- (BOOL)isFlipped
{
  return YES;
}

- (void)drawRect:(__unused NSRect)dirtyRect {}

- (void)setCursor:(RCTCursor)cursor
{
  _cursor = cursor;
  [super setCursor:cursor];
}

- (void)setTransform:(CATransform3D)transform
{
  _transform = transform;
  [self ensureLayerExists];
  [self applyTransform:self.layer];
}

- (NSView *)hitTest:(CGPoint)point
{
  if (self.isHidden || _pointerEvents == RCTPointerEventsNone) {
    return nil;
  }

  // Convert to our coordinates.
  CGPoint convertedPoint = self.layer
    ? [self.layer convertPoint:point fromLayer:self.layer.superlayer]
    : [self convertPoint:point fromView:self.superview];

  // `hitSubview` is the topmost subview which was hit. The hit point can
  // be outside the bounds of `view` (e.g., if -clipsToBounds is NO).
  NSView *hitSubview = nil;
  BOOL isPointInside = [self pointInside:convertedPoint];
  BOOL needsHitSubview = _pointerEvents != RCTPointerEventsBoxOnly;
  if (needsHitSubview && (![self clipsToBounds] || isPointInside)) {
    // Take z-index into account when calculating the touch target.
    NSArray<NSView *> *sortedSubviews = [self reactZIndexSortedSubviews];

    // The default behaviour of UIKit is that if a view does not contain a point,
    // then no subviews will be returned from hit testing, even if they contain
    // the hit point. By doing hit testing directly on the subviews, we bypass
    // the strict containment policy (i.e., UIKit guarantees that every ancestor
    // of the hit view will return YES from -pointInside:withEvent:). See:
    //  - https://developer.apple.com/library/ios/qa/qa2013/qa1812.html
    for (NSView *subview in [sortedSubviews reverseObjectEnumerator]) {
      hitSubview = [subview hitTest:convertedPoint];
      if (hitSubview != nil) {
        break;
      }
    }
  }

  return hitSubview ?: (isPointInside && _pointerEvents != RCTPointerEventsBoxNone ? self : nil);
}

static inline CGRect NSEdgeInsetsInsetRect(CGRect rect, NSEdgeInsets insets) {
  rect.origin.x    += insets.left;
  rect.origin.y    += insets.top;
  rect.size.width  -= (insets.left + insets.right);
  rect.size.height -= (insets.top  + insets.bottom);
  return rect;
}

- (BOOL)pointInside:(CGPoint)point
{
  CGRect hitFrame = NSEdgeInsetsInsetRect(self.bounds, self.hitTestEdgeInsets);
  return CGRectContainsPoint(hitFrame, point);
}

- (NSView *)reactAccessibilityElement
{
  return self;
}

- (BOOL)isAccessibilityElement
{
  if (self.reactAccessibilityElement == self) {
    return [super isAccessibilityElement];
  }

  return NO;
}

- (BOOL)accessibilityActivate
{
  if (_onAccessibilityTap) {
    _onAccessibilityTap(nil);
    return YES;
  } else {
    return NO;
  }
}

- (BOOL)accessibilityPerformMagicTap
{
  if (_onMagicTap) {
    _onMagicTap(nil);
    return YES;
  } else {
    return NO;
  }
}

- (NSString *)description
{
  NSString *superDescription = super.description;
  NSRange semicolonRange = [superDescription rangeOfString:@";"];
  NSString *replacement = [NSString stringWithFormat:@"; reactTag: %@;", self.reactTag];

  if ([superDescription length] > 0 && semicolonRange.length > 0) {
    return [superDescription stringByReplacingCharactersInRange:semicolonRange withString:replacement];
  }
  return [NSString stringWithFormat:@"reactTag: %@;", self.reactTag];
}

#pragma mark - Statics for dealing with layoutGuides

+ (void)autoAdjustInsetsForView:(NSView<RCTAutoInsetsProtocol> *)parentView
                 withScrollView:(NSScrollView *)scrollView
                   updateOffset:(BOOL)updateOffset
{
  NSEdgeInsets baseInset = parentView.contentInset;
  CGFloat previousInsetTop = scrollView.contentInsets.top;
  //CGPoint contentOffset = scrollView.contentOffset;

  if (parentView.automaticallyAdjustContentInsets) {
    NSEdgeInsets autoInset = [self contentInsetsForView:parentView];
    baseInset.top += autoInset.top;
    baseInset.bottom += autoInset.bottom;
    baseInset.left += autoInset.left;
    baseInset.right += autoInset.right;
  }
  scrollView.contentInsets = baseInset;
  //scrollView.scrollIndicatorInsets = baseInset;

  if (updateOffset) {
    // If we're adjusting the top inset, then let's also adjust the contentOffset so that the view
    // elements above the top guide do not cover the content.
    // This is generally only needed when your views are initially laid out, for
    // manual changes to contentOffset, you can optionally disable this step
    CGFloat currentInsetTop = scrollView.contentInsets.top;
    if (currentInsetTop != previousInsetTop) {
      //contentOffset.y -= (currentInsetTop - previousInsetTop);
      //scrollView.contentOffset = contentOffset;
    }
  }
}

+ (NSEdgeInsets)contentInsetsForView:(__unused NSView *)view
{
  NSLog(@"contentInsetsForView not implemented");
//  while (view) {
//    NSViewController *controller = view.reactViewController;
//    if (controller) {
//      return (NSEdgeInsets){
//        controller.topLayoutGuide.length, 0,
//        controller.bottomLayoutGuide.length, 0
//      };
//    }
//    view = view.superview;
//  }
  return NSEdgeInsetsZero;
}

#pragma mark - View unmounting

- (void)react_remountAllSubviews
{
  if (_removeClippedSubviews) {
    for (NSView *view in self.reactSubviews) {
      if (view.superview != self) {
        [self addSubview:view];
        [view react_remountAllSubviews];
      }
    }
  } else {
    // If _removeClippedSubviews is false, we must already be showing all subviews
    [super react_remountAllSubviews];
  }
}

- (void)react_updateClippedSubviewsWithClipRect:(CGRect)clipRect relativeToView:(NSView *)clipView
{
  // TODO (#5906496): for scrollviews (the primary use-case) we could
  // optimize this by only doing a range check along the scroll axis,
  // instead of comparing the whole frame

  if (!_removeClippedSubviews) {
    // Use default behavior if unmounting is disabled
    return [super react_updateClippedSubviewsWithClipRect:clipRect relativeToView:clipView];
  }

  if (self.reactSubviews.count == 0) {
    // Do nothing if we have no subviews
    return;
  }

  if (CGSizeEqualToSize(self.bounds.size, CGSizeZero)) {
    // Do nothing if layout hasn't happened yet
    return;
  }

  // Convert clipping rect to local coordinates
  clipRect = [clipView convertRect:clipRect toView:self];
  clipRect = CGRectIntersection(clipRect, self.bounds);
  clipView = self;

  // Mount / unmount views
  for (NSView *view in self.reactSubviews) {
    if (!CGSizeEqualToSize(CGRectIntersection(clipRect, view.frame).size, CGSizeZero)) {
      // View is at least partially visible, so remount it if unmounted
      [self addSubview:view];

      // Then test its subviews
      if (CGRectContainsRect(clipRect, view.frame)) {
        // View is fully visible, so remount all subviews
        [view react_remountAllSubviews];
      } else {
        // View is partially visible, so update clipped subviews
        [view react_updateClippedSubviewsWithClipRect:clipRect relativeToView:clipView];
      }

    } else if (view.superview) {

      // View is completely outside the clipRect, so unmount it
      [view removeFromSuperview];
    }
  }
}

- (void)setRemoveClippedSubviews:(BOOL)removeClippedSubviews
{
  if (!removeClippedSubviews && _removeClippedSubviews) {
    [self react_remountAllSubviews];
  }
  _removeClippedSubviews = removeClippedSubviews;
}

- (void)didUpdateReactSubviews
{
  if (_removeClippedSubviews) {
    [self updateClippedSubviews];
  } else {
    [super didUpdateReactSubviews];
  }
}

- (void)updateClippedSubviews
{
  // Find a suitable view to use for clipping
  NSView *clipView = [self react_findClipView];
  if (clipView) {
    [self react_updateClippedSubviewsWithClipRect:clipView.bounds relativeToView:clipView];
  }
}

- (void)layout
{
  // TODO (#5906496): this a nasty performance drain, but necessary
  // to prevent gaps appearing when the loading spinner disappears.
  // We might be able to fix this another way by triggering a call
  // to updateClippedSubviews manually after loading

  [super layout];

  if (_removeClippedSubviews) {
    [self updateClippedSubviews];
  }

}

- (NSColor *)backgroundColor
{
  return _backgroundColor;
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
{
  if (CGColorEqualToColor(_backgroundColor.CGColor, backgroundColor.CGColor)) {
    return;
  }
  _backgroundColor = backgroundColor;

  if (_borderImage) {
    [self borderDidUpdate];
  } else {
    [self ensureLayerExists];
    self.layer.backgroundColor = backgroundColor.CGColor;
  }
}

- (void)setBackgroundBlurRadius:(CGFloat)blurRadius
{
  _backgroundBlurRadius = blurRadius;

  if (_backgroundBlur == nil) {
    _backgroundBlur = [RCTBlurFilter new];
    _backgroundBlur.name = @"blur";

    [self ensureLayerExists];
    self.backgroundFilters = @[_backgroundBlur];
  }
  
  [self.layer setValue:@(blurRadius)
            forKeyPath:@"backgroundFilters.blur.inputRadius"];
}

#pragma mark - Rendering

- (void)reactSetFrame:(CGRect)frame
{
  // TODO: understand if we need to be able to disable live resizing for certain use
  //  if (self.inLiveResize && !self.respondsToLiveResizing) {
  //    return;
  //  }
  // If frame is zero, or below the threshold where the border radii can
  // be rendered as a stretchable image, we'll need to re-render.
  // TODO: detect up-front if re-rendering is necessary
  CGSize oldSize = self.bounds.size;
  [super reactSetFrame:frame];
  if (!CGSizeEqualToSize(self.bounds.size, oldSize)) {
    if (_redrawsBorderImageOnSizeChange) {
      _borderImage = nil;
    }
    [self.layer setNeedsDisplay];
  } else if (!CATransform3DIsIdentity(_transform)) {
    [self applyTransform:self.layer];
  }
}

- (void)applyTransform:(CALayer *)layer
{
  if (!CATransform3DEqualToTransform(_transform, layer.transform)) {
    layer.transform = _transform;
    // Enable edge antialiasing in perspective transforms
    layer.edgeAntialiasingMask = !(_transform.m34 == 0.0f);
  }
}

- (void)viewDidChangeBackingProperties
{
  CGFloat scale = self.window.backingScaleFactor;
  if (scale != self.layer.contentsScale) {
    [self borderDidUpdate];
  }
  if (self.layer.shouldRasterize) {
    self.layer.rasterizationScale = scale;
  }
}

- (CALayer *)makeBackingLayer
{
  return [CALayer layer];
}

- (void)displayLayer:(CALayer *)layer
{
  // Applying the transform here ensures it's not overridden by AppKit internals.
  [self applyTransform:layer];

  // Ensure the anchorPoint is in the center.
  layer.position = (CGPoint){CGRectGetMidX(self.frame), CGRectGetMidY(self.frame)};
  layer.anchorPoint = (CGPoint){0.5, 0.5};

  if (CGSizeEqualToSize(layer.bounds.size, CGSizeZero)) {
    return;
  }
  
  if (RCTLayerHasShadow(self.layer)) {
    // If view has a solid background color, calculate shadow path from border
    if (CGColorGetAlpha(self.backgroundColor.CGColor) > 0.999) {
      [self updateShadowPath];
    } else {
      // Can't accurately calculate box shadow, so fall back to pixel-based shadow
      self.layer.shadowPath = nil;

#if DEBUG
      RCTLogAdvice(@"View #%@ of type %@ has a shadow set but cannot calculate "
        "shadow efficiently. Consider setting a background color to "
        "fix this, or apply the shadow to a more specific component.",
        self.reactTag, [self class]);
#endif
    }
  }
  
  if (_borderImage == nil) {
    const RCTCornerRadii cornerRadii = [self cornerRadii];
    const NSEdgeInsets borderInsets = [self bordersAsInsets];
    const RCTBorderColors borderColors = [self borderColors];
    
    BOOL needsBorderImage =
      RCTBordersAreVisible(borderInsets, borderColors) ||
        (!self.clipsToBounds &&
          (cornerRadii.topLeft > 0 ||
            !RCTCornerRadiiAreEqual(cornerRadii)));
    
    if (needsBorderImage) {
      RCTSetScreen(self.window.screen);
      NSImage *image = [self createBorderImage:layer.bounds.size
                                   cornerRadii:cornerRadii
                                  borderInsets:borderInsets
                                  borderColors:borderColors];

      if (RCTRunningInTestEnvironment()) {
        const CGSize size = self.bounds.size;
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
        [image drawInRect:(CGRect){CGPointZero, size}];
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
      }

      _borderImage = image;

      CGFloat screenScale = RCTScreenScale();
      NSEdgeInsets capInsets = image.capInsets;

      CGRect contentsCenter;
      if (NSEdgeInsetsEqual(capInsets, NSEdgeInsetsZero)) {
        contentsCenter = CGRectMake(0, 0, 1, 1);
      } else {
        CGSize size = image.size;
        contentsCenter = CGRectMake(
          capInsets.left / size.width,
          capInsets.top / size.height,
          screenScale / size.width,
          screenScale / size.height
        );
      }

      layer.backgroundColor = NULL;
      layer.contents = image;
      layer.contentsScale = screenScale;
      layer.contentsCenter = contentsCenter;
      layer.needsDisplayOnBoundsChange = YES;
      layer.magnificationFilter = kCAFilterNearest;
      layer.minificationFilter = kCAFilterNearest;
    } else {
      layer.backgroundColor = _backgroundColor.CGColor;
      layer.contents = nil;
      layer.needsDisplayOnBoundsChange = NO;
    }

    [self updateClippingForLayer:layer];
  }
}

#pragma mark - Shadows

static BOOL RCTLayerHasShadow(CALayer *layer)
{
  return layer.shadowOpacity * CGColorGetAlpha(layer.shadowColor) > 0;
}

- (void)updateShadowPath
{
  const RCTCornerRadii cornerRadii = [self cornerRadii];
  const RCTCornerInsets cornerInsets = RCTGetCornerInsets(cornerRadii, NSEdgeInsetsZero);
  CGPathRef shadowPath = RCTPathCreateWithRoundedRect(self.bounds, cornerInsets, NULL);
  self.layer.shadowPath = shadowPath;
  CGPathRelease(shadowPath);
}

#pragma mark - Clipping

- (void)setClipsToBounds:(BOOL)clipsToBounds
{
  super.clipsToBounds = clipsToBounds;

  if (_borderImage) {
    [self borderDidUpdate];
  }
}

- (void)updateClippingForLayer:(CALayer *)layer
{
  CALayer *mask = nil;
  CGFloat cornerRadius = 0;
  if (self.clipsToBounds) {
    const RCTCornerRadii cornerRadii = [self cornerRadii];
    if (RCTCornerRadiiAreEqual(cornerRadii)) {
      cornerRadius = cornerRadii.topLeft;
    } else {
      CAShapeLayer *shapeLayer = [CAShapeLayer layer];
      CGPathRef path = RCTPathCreateWithRoundedRect(self.bounds, RCTGetCornerInsets(cornerRadii, NSEdgeInsetsZero), NULL);
      shapeLayer.path = path;
      CGPathRelease(path);
      mask = shapeLayer;
    }
  }
  layer.cornerRadius = cornerRadius;
  layer.mask = mask;
}

#pragma mark - Context Menu

- (void)contextMenuItemClicked:(NSMenuItem *)sender
{
  NSDictionary *menuItem = (NSDictionary *)sender.representedObject;
  if (_onContextMenuItemClick) {
    _onContextMenuItemClick(@{@"menuItem": menuItem});
  } else {
    RCTLogWarn(@"Set onContextMenuItemClick to handle this event");
  }
}

#pragma mark - Dragging

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pboard;
  NSDragOperation sourceDragMask;
  sourceDragMask = [sender draggingSourceOperationMask];
  pboard = [sender draggingPasteboard];

  _onDragEnter(@{
                 @"sourceDragMask": @(sourceDragMask),
                 });
  if ( [[pboard types] containsObject:NSColorPboardType] ) {
    if (sourceDragMask & NSDragOperationGeneric) {
      return NSDragOperationGeneric;
    }
  }
  if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
    if (sourceDragMask & NSDragOperationLink) {
      return NSDragOperationLink;
    } else if (sourceDragMask & NSDragOperationCopy) {
      return NSDragOperationCopy;
    }
  }
  return NSDragOperationNone;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
  _onDragLeave(@{@"sourceDragMask": @([sender draggingSourceOperationMask])});
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pboard = [sender draggingPasteboard];

  if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
    NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
    _onDrop(@{@"files": files });
  }
  return YES;
}

#pragma mark - Borders

static CGFloat RCTDefaultIfNegativeTo(CGFloat defaultValue, CGFloat x) {
  return x >= 0 ? x : defaultValue;
};

- (NSEdgeInsets)bordersAsInsets
{
  const CGFloat borderWidth = MAX(0, _borderWidth);
  const BOOL isRTL = _reactLayoutDirection == NSUserInterfaceLayoutDirectionRightToLeft;

  if ([[RCTI18nUtil sharedInstance] doLeftAndRightSwapInRTL]) {
    const CGFloat borderStartWidth = RCTDefaultIfNegativeTo(_borderLeftWidth, _borderStartWidth);
    const CGFloat borderEndWidth = RCTDefaultIfNegativeTo(_borderRightWidth, _borderEndWidth);

    const CGFloat directionAwareBorderLeftWidth = isRTL ? borderEndWidth : borderStartWidth;
    const CGFloat directionAwareBorderRightWidth = isRTL ? borderStartWidth : borderEndWidth;

    return (NSEdgeInsets) {
      RCTDefaultIfNegativeTo(borderWidth, _borderTopWidth),
      RCTDefaultIfNegativeTo(borderWidth, directionAwareBorderLeftWidth),
      RCTDefaultIfNegativeTo(borderWidth, _borderBottomWidth),
      RCTDefaultIfNegativeTo(borderWidth, directionAwareBorderRightWidth),
    };
  }

  const CGFloat directionAwareBorderLeftWidth = isRTL ? _borderEndWidth : _borderStartWidth;
  const CGFloat directionAwareBorderRightWidth = isRTL ? _borderStartWidth : _borderEndWidth;

  return (NSEdgeInsets) {
    RCTDefaultIfNegativeTo(borderWidth, _borderTopWidth),
    RCTDefaultIfNegativeTo(borderWidth, RCTDefaultIfNegativeTo(_borderLeftWidth, directionAwareBorderLeftWidth)),
    RCTDefaultIfNegativeTo(borderWidth, _borderBottomWidth),
    RCTDefaultIfNegativeTo(borderWidth, RCTDefaultIfNegativeTo(_borderRightWidth, directionAwareBorderRightWidth)),
  };
}

- (RCTCornerRadii)cornerRadii
{
  const BOOL isRTL = _reactLayoutDirection == NSUserInterfaceLayoutDirectionRightToLeft;
  const CGFloat radius = MAX(0, _borderRadius);

  CGFloat topLeftRadius;
  CGFloat topRightRadius;
  CGFloat bottomLeftRadius;
  CGFloat bottomRightRadius;

  if ([[RCTI18nUtil sharedInstance] doLeftAndRightSwapInRTL]) {
    const CGFloat topStartRadius = RCTDefaultIfNegativeTo(_borderTopLeftRadius, _borderTopStartRadius);
    const CGFloat topEndRadius = RCTDefaultIfNegativeTo(_borderTopRightRadius, _borderTopEndRadius);
    const CGFloat bottomStartRadius = RCTDefaultIfNegativeTo(_borderBottomLeftRadius, _borderBottomStartRadius);
    const CGFloat bottomEndRadius = RCTDefaultIfNegativeTo(_borderBottomRightRadius, _borderBottomEndRadius);

    const CGFloat directionAwareTopLeftRadius = isRTL ? topEndRadius : topStartRadius;
    const CGFloat directionAwareTopRightRadius = isRTL ? topStartRadius : topEndRadius;
    const CGFloat directionAwareBottomLeftRadius = isRTL ? bottomEndRadius : bottomStartRadius;
    const CGFloat directionAwareBottomRightRadius = isRTL ? bottomStartRadius : bottomEndRadius;

    topLeftRadius = RCTDefaultIfNegativeTo(radius, directionAwareTopLeftRadius);
    topRightRadius = RCTDefaultIfNegativeTo(radius, directionAwareTopRightRadius);
    bottomLeftRadius = RCTDefaultIfNegativeTo(radius, directionAwareBottomLeftRadius);
    bottomRightRadius = RCTDefaultIfNegativeTo(radius, directionAwareBottomRightRadius);
  } else {
    const CGFloat directionAwareTopLeftRadius = isRTL ? _borderTopEndRadius : _borderTopStartRadius;
    const CGFloat directionAwareTopRightRadius = isRTL ? _borderTopStartRadius : _borderTopEndRadius;
    const CGFloat directionAwareBottomLeftRadius = isRTL ? _borderBottomEndRadius : _borderBottomStartRadius;
    const CGFloat directionAwareBottomRightRadius = isRTL ? _borderBottomStartRadius : _borderBottomEndRadius;

    topLeftRadius = RCTDefaultIfNegativeTo(radius, RCTDefaultIfNegativeTo(_borderTopLeftRadius, directionAwareTopLeftRadius));
    topRightRadius = RCTDefaultIfNegativeTo(radius, RCTDefaultIfNegativeTo(_borderTopRightRadius, directionAwareTopRightRadius));
    bottomLeftRadius = RCTDefaultIfNegativeTo(radius, RCTDefaultIfNegativeTo(_borderBottomLeftRadius, directionAwareBottomLeftRadius));
    bottomRightRadius = RCTDefaultIfNegativeTo(radius, RCTDefaultIfNegativeTo(_borderBottomRightRadius, directionAwareBottomRightRadius));
  }

  // Get scale factors required to prevent radii from overlapping
  const CGSize size = self.bounds.size;
  const CGFloat topScaleFactor = RCTZeroIfNaN(MIN(1, size.width / (topLeftRadius + topRightRadius)));
  const CGFloat bottomScaleFactor = RCTZeroIfNaN(MIN(1, size.width / (bottomLeftRadius + bottomRightRadius)));
  const CGFloat rightScaleFactor = RCTZeroIfNaN(MIN(1, size.height / (topRightRadius + bottomRightRadius)));
  const CGFloat leftScaleFactor = RCTZeroIfNaN(MIN(1, size.height / (topLeftRadius + bottomLeftRadius)));

  // Return scaled radii
  return (RCTCornerRadii){
    topLeftRadius * MIN(topScaleFactor, leftScaleFactor),
    topRightRadius * MIN(topScaleFactor, rightScaleFactor),
    bottomLeftRadius * MIN(bottomScaleFactor, leftScaleFactor),
    bottomRightRadius * MIN(bottomScaleFactor, rightScaleFactor),
  };
}

- (RCTBorderColors)borderColors
{
  const BOOL isRTL = _reactLayoutDirection == NSUserInterfaceLayoutDirectionRightToLeft;

  if ([[RCTI18nUtil sharedInstance] doLeftAndRightSwapInRTL]) {
    const CGColorRef borderStartColor = _borderStartColor ?: _borderLeftColor;
    const CGColorRef borderEndColor = _borderEndColor ?: _borderRightColor;

    const CGColorRef directionAwareBorderLeftColor = isRTL ? borderEndColor : borderStartColor;
    const CGColorRef directionAwareBorderRightColor = isRTL ? borderStartColor : borderEndColor;

    return (RCTBorderColors){
      _borderTopColor ?: _borderColor,
      directionAwareBorderLeftColor ?: _borderColor,
      _borderBottomColor ?: _borderColor,
      directionAwareBorderRightColor ?: _borderColor,
    };
  }

  const CGColorRef directionAwareBorderLeftColor = isRTL ? _borderEndColor : _borderStartColor;
  const CGColorRef directionAwareBorderRightColor = isRTL ? _borderStartColor : _borderEndColor;

  return (RCTBorderColors){
    _borderTopColor ?: _borderColor,
    directionAwareBorderLeftColor ?: _borderLeftColor ?: _borderColor,
    _borderBottomColor ?: _borderColor,
    directionAwareBorderRightColor ?: _borderRightColor ?: _borderColor,
  };
}

- (NSImage *)createBorderImage:(NSSize)size
                   cornerRadii:(RCTCornerRadii)cornerRadii
                  borderInsets:(NSEdgeInsets)borderInsets
                  borderColors:(RCTBorderColors)borderColors
{
  return RCTGetBorderImage(
    _borderStyle,
    size,
    cornerRadii,
    borderInsets,
    borderColors,
    _backgroundColor.CGColor,
    self.clipsToBounds
  );
}

- (void)borderDidUpdate
{
  _borderImage = nil;

  [self ensureLayerExists];
  [self.layer setNeedsDisplay];
}

#pragma mark - Border Color

#define setBorderColor(side)                                \
  - (void)setBorder##side##Color:(CGColorRef)color          \
  {                                                         \
    if (CGColorEqualToColor(_border##side##Color, color)) { \
      return;                                               \
    }                                                       \
    CGColorRelease(_border##side##Color);                   \
    _border##side##Color = CGColorRetain(color);            \
    [self borderDidUpdate];                                 \
  }

setBorderColor()
setBorderColor(Top)
setBorderColor(Right)
setBorderColor(Bottom)
setBorderColor(Left)
setBorderColor(Start)
setBorderColor(End)

#pragma mark - Border Width

#define setBorderWidth(side)                    \
  - (void)setBorder##side##Width:(CGFloat)width \
  {                                             \
    if (_border##side##Width == width) {        \
      return;                                   \
    }                                           \
    _border##side##Width = width;               \
    [self borderDidUpdate];                     \
  }

setBorderWidth()
setBorderWidth(Top)
setBorderWidth(Right)
setBorderWidth(Bottom)
setBorderWidth(Left)
setBorderWidth(Start)
setBorderWidth(End)

#pragma mark - Border Radius

#define setBorderRadius(side)                     \
  - (void)setBorder##side##Radius:(CGFloat)radius \
  {                                               \
    if (_border##side##Radius == radius) {        \
      return;                                     \
    }                                             \
    _border##side##Radius = radius;               \
    [self borderDidUpdate];                       \
  }

setBorderRadius()
setBorderRadius(TopLeft)
setBorderRadius(TopRight)
setBorderRadius(TopStart)
setBorderRadius(TopEnd)
setBorderRadius(BottomLeft)
setBorderRadius(BottomRight)
setBorderRadius(BottomStart)
setBorderRadius(BottomEnd)

#pragma mark - Border Style

#define setBorderStyle(side)                           \
  - (void)setBorder##side##Style:(RCTBorderStyle)style \
  {                                                    \
    if (_border##side##Style == style) {               \
      return;                                          \
    }                                                  \
    _border##side##Style = style;                      \
    [self borderDidUpdate];                            \
  }

setBorderStyle()

- (void)dealloc
{
  CGColorRelease(_borderColor);
  CGColorRelease(_borderTopColor);
  CGColorRelease(_borderRightColor);
  CGColorRelease(_borderBottomColor);
  CGColorRelease(_borderLeftColor);
  CGColorRelease(_borderStartColor);
  CGColorRelease(_borderEndColor);
}

@end
