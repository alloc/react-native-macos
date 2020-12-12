/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <AppKit/AppKit.h>

#import <React/RCTBorderStyle.h>
#import <React/RCTComponent.h>
#import <React/RCTCursor.h>
#import <React/RCTPointerEvents.h>
#import <React/RCTView.h>

@protocol RCTAutoInsetsProtocol;

@class RCTView;

@interface RCTView : NSView <CALayerDelegate>

/**
 * Accessibility event handlers
 */
@property (nonatomic, copy) RCTDirectEventBlock onAccessibilityAction;
@property (nonatomic, copy) RCTDirectEventBlock onAccessibilityTap;
@property (nonatomic, copy) RCTDirectEventBlock onMagicTap;

/**
 * Accessibility properties
 */
@property (nonatomic, copy) NSArray <NSString *> *accessibilityActions;

/**
 * Used to control how touch events are processed.
 */
@property (nonatomic, assign) RCTPointerEvents pointerEvents;

- (BOOL)shouldRedrawBorderOnResize;

+ (void)autoAdjustInsetsForView:(NSView<RCTAutoInsetsProtocol> *)parentView
                 withScrollView:(NSScrollView *)scrollView
                   updateOffset:(BOOL)updateOffset;

/**
 * Find the first view controller whose view, or any subview is the specified view.
 */
+ (NSEdgeInsets)contentInsetsForView:(NSView *)curView;

- (NSEdgeInsets)bordersAsInsets;

/**
 * Layout direction of the view.
 * This is inherited from UIView+React, but we override it here
 * to improve perfomance and make subclassing/overriding possible/easier.
 */
@property (nonatomic, assign) NSUserInterfaceLayoutDirection reactLayoutDirection;

/**
 * This is an optimization used to improve performance
 * for large scrolling views with many subviews, such as a
 * list or table. If set to YES, any clipped subviews will
 * be removed from the view hierarchy whenever -updateClippedSubviews
 * is called. This would typically be triggered by a scroll event
 */
@property (nonatomic, assign) BOOL removeClippedSubviews;

/**
 * Workaround on a lot of views with layers
 */
@property (nonatomic, assign) BOOL respondsToLiveResizing;


/**
 * Hide subviews if they are outside the view bounds.
 * This is an optimisation used predominantly with RKScrollViews
 * but it is applied recursively to all subviews that have
 * removeClippedSubviews set to YES
 */
- (void)updateClippedSubviews;

/**
 * Border radii.
 */
@property (nonatomic, assign) CGFloat borderRadius;
@property (nonatomic, assign) CGFloat borderTopLeftRadius;
@property (nonatomic, assign) CGFloat borderTopRightRadius;
@property (nonatomic, assign) CGFloat borderTopStartRadius;
@property (nonatomic, assign) CGFloat borderTopEndRadius;
@property (nonatomic, assign) CGFloat borderBottomLeftRadius;
@property (nonatomic, assign) CGFloat borderBottomRightRadius;
@property (nonatomic, assign) CGFloat borderBottomStartRadius;
@property (nonatomic, assign) CGFloat borderBottomEndRadius;

/**
 * Border colors (actually retained).
 */
@property (nonatomic, assign) CGColorRef borderTopColor;
@property (nonatomic, assign) CGColorRef borderRightColor;
@property (nonatomic, assign) CGColorRef borderBottomColor;
@property (nonatomic, assign) CGColorRef borderLeftColor;
@property (nonatomic, assign) CGColorRef borderStartColor;
@property (nonatomic, assign) CGColorRef borderEndColor;
@property (nonatomic, assign) CGColorRef borderColor;

/**
 * Border widths.
 */
@property (nonatomic, assign) CGFloat borderTopWidth;
@property (nonatomic, assign) CGFloat borderRightWidth;
@property (nonatomic, assign) CGFloat borderBottomWidth;
@property (nonatomic, assign) CGFloat borderLeftWidth;
@property (nonatomic, assign) CGFloat borderStartWidth;
@property (nonatomic, assign) CGFloat borderEndWidth;
@property (nonatomic, assign) CGFloat borderWidth;

/**
 * Border styles.
 */
@property (nonatomic, assign) RCTBorderStyle borderStyle;

/**
 *  Insets used when hit testing inside this view.
 */
@property (nonatomic, assign) NSEdgeInsets hitTestEdgeInsets;

@property (nonatomic, assign) CATransform3D transform;
@property (nonatomic, copy) NSColor *backgroundColor;
@property (nonatomic, assign) CGFloat backgroundBlurRadius;
@property (nonatomic, copy) NSColor *shadowColor;
@property (nonatomic, assign) CGFloat shadowOpacity;

@property (nonatomic, copy) RCTDirectEventBlock onDragEnter;
@property (nonatomic, copy) RCTDirectEventBlock onDragLeave;
@property (nonatomic, copy) RCTDirectEventBlock onDrop;
@property (nonatomic, copy) RCTDirectEventBlock onContextMenuItemClick;

/**
 * The cursor image to show while the mouse is inside this view.
 */
@property (nonatomic, assign) RCTCursor cursor;

@end
