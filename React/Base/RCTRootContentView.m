/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTRootContentView.h"

#import "RCTBridge.h"
#import "RCTPerformanceLogger.h"
#import "RCTRootView.h"
#import "RCTRootViewInternal.h"
#import "RCTTouchHandler.h"
#import "RCTUIManager.h"
#import "RCTWindow.h"
#import "NSView+React.h"

@interface RCTRootContentView ()
@property (nullable, readonly, assign) RCTRootView *superview;
@end

@implementation RCTRootContentView

- (instancetype)initWithFrame:(CGRect)frame
                       bridge:(RCTBridge *)bridge
                     reactTag:(NSNumber *)reactTag
               sizeFlexiblity:(RCTRootViewSizeFlexibility)sizeFlexibility
{
  if ((self = [super initWithFrame:frame])) {
    _bridge = bridge;
    self.reactTag = reactTag;
    _sizeFlexibility = sizeFlexibility;
    [_bridge.uiManager registerRootView:self];
  }
  return self;
}

RCT_NOT_IMPLEMENTED(-(instancetype)initWithFrame:(CGRect)frame)
RCT_NOT_IMPLEMENTED(-(instancetype)initWithCoder:(nonnull NSCoder *)aDecoder)

- (void)layout
{
  [super layout];
  [self updateAvailableSize];
}

@dynamic superview;

- (void)addSubview:(NSView *)subview
{
  [super addSubview:subview];
  [_bridge.performanceLogger markStopForTag:RCTPLTTI];

  if (self.subviews.count == 1) {
    [subview addObserver:self
              forKeyPath:@"frame"
                 options:NSKeyValueObservingOptionInitial
                 context:nil];
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    if (!self->_contentHasAppeared) {
      self->_contentHasAppeared = YES;
      [[NSNotificationCenter defaultCenter] postNotificationName:RCTContentDidAppearNotification
                                                          object:self.superview];
    }
  });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
  if ([object isKindOfClass:[NSView class]]) {
    NSView *subview = (NSView *)object;
    if ([keyPath isEqualToString:@"frame"]) {
      CGSize size = self.frame.size;
      if (_sizeFlexibility & RCTRootViewSizeFlexibilityWidth) {
        size.width = subview.frame.size.width;
      }
      if (_sizeFlexibility & RCTRootViewSizeFlexibilityHeight) {
        size.height = subview.frame.size.height;
      }
      self.frameSize = size;
      [self.window setContentSize:size];
    }
  }
}

- (void)setSizeFlexibility:(RCTRootViewSizeFlexibility)sizeFlexibility
{
  if (_sizeFlexibility == sizeFlexibility) {
    return;
  }

  _sizeFlexibility = sizeFlexibility;
  [self setNeedsLayout: YES];
}

- (CGSize)availableSize
{
  CGSize size = self.bounds.size;
  return CGSizeMake(
      _sizeFlexibility & RCTRootViewSizeFlexibilityWidth ? INFINITY : size.width,
      _sizeFlexibility & RCTRootViewSizeFlexibilityHeight ? INFINITY : size.height
    );
}

- (void)updateAvailableSize
{
  if (!self.reactTag || !_bridge.isValid) {
    return;
  }

  [_bridge.uiManager setAvailableSize:self.availableSize forRootView:self];
}

- (NSView *)hitTest:(CGPoint)point
{
  // Flip the coordinate system to top-left origin.
  NSPoint convertedPoint = [self convertPoint:point fromView:nil];

  NSView *hitView = [super hitTest:convertedPoint];
  return _passThroughTouches && hitView == self ? nil : hitView;
}

- (void)invalidate
{
  //if (self.userInteractionEnabled) {
    // self.userInteractionEnabled = NO;
    [(RCTRootView *)self.superview contentViewInvalidated];
    [_bridge enqueueJSCall:@"AppRegistry"
                    method:@"unmountApplicationComponentAtRootTag"
                      args:@[self.reactTag]
                completion:NULL];
  //}
}

- (void)viewDidMoveToWindow
{
  if (self.window == nil) {
    return;
  }
  // RCTWindow handles all touches within
  if ([self.window isKindOfClass:RCTWindow.class] == NO) {
    if (_touchHandler == nil) {
      _touchHandler = [[RCTTouchHandler alloc] initWithBridge:_bridge];
      [_touchHandler attachToView:self];
    }
  } else if (_touchHandler) {
    [_touchHandler detachFromView:self];
    _touchHandler = nil;
  }
}

@end
