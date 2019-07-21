/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTWindow.h"

#import "RCTUtils.h"
#import "RCTMouseEvent.h"
#import "RCTTouchEvent.h"
#import "RCTFieldEditor.h"
#import "NSView+React.h"

@implementation RCTWindow
{
  RCTBridge *_bridge;

  NSMutableDictionary *_mouseInfo;
  NSView *_hoverTarget;
  NSView *_clickTarget;
  NSEventType _clickType;
  uint16_t _coalescingKey;

  BOOL _inContentView;
  BOOL _enabled;
}

RCT_NOT_IMPLEMENTED(- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backingStoreType defer:(BOOL)flag)

- (instancetype)initWithBridge:(RCTBridge *)bridge
                   contentRect:(NSRect)contentRect
                     styleMask:(NSWindowStyleMask)style
                         defer:(BOOL)defer
{
  self = [super initWithContentRect:contentRect
                          styleMask:style
                            backing:NSBackingStoreBuffered
                              defer:defer];

  if (self) {
    _bridge = bridge;

    _mouseInfo = [NSMutableDictionary new];
    _mouseInfo[@"changedTouches"] = @[]; // Required for "mouseMove" events
    _mouseInfo[@"identifier"] = @0; // Required for "touch*" events

    self.initialFirstResponder = nil;
    self.autorecalculatesKeyViewLoop = YES;

    // The owner must set "contentView" manually.
    super.contentView = nil;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_javaScriptDidLoad:)
                                                 name:RCTJavaScriptDidLoadNotification
                                               object:bridge];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_bridgeWillReload:)
                                                 name:RCTBridgeWillReloadNotification
                                               object:bridge];
  }

  return self;
}

@dynamic contentView;

- (NSView *)rootView
{
  return self.contentView.contentView;
}

- (void)sendEvent:(NSEvent *)event
{
  // Avoid sending JS events too early.
  if (_enabled == NO) {
    return [super sendEvent:event];
  }

  NSEventType type = event.type;

  if (type == NSEventTypeMouseEntered) {
    if (event.trackingArea.owner == self.contentView) {
      _inContentView = YES;
    }
    return [super sendEvent:event];
  }

  if (type == NSEventTypeMouseExited) {
    if (event.trackingArea.owner == self.contentView) {
      _inContentView = NO;

      if (_clickTarget) {
        if (_clickType == NSEventTypeLeftMouseDown) {
          [self _sendTouchEvent:@"touchCancel"];
        }
        _clickTarget = nil;
        _clickType = 0;
      }

      [self _setHoverTarget:nil];
    }
    return [super sendEvent:event];
  }

  if (
    type != NSEventTypeMouseMoved &&
    type != NSEventTypeLeftMouseDragged &&
    type != NSEventTypeLeftMouseUp &&
    type != NSEventTypeLeftMouseDown &&
    type != NSEventTypeRightMouseUp &&
    type != NSEventTypeRightMouseDown
  ) {
    return [super sendEvent:event];
  }

  // Perform a hitTest before sendEvent in case a field editor is active.
  NSView *targetView = [self hitTest:event.locationInWindow withEvent:event];
  [super sendEvent:event];

  if (_clickTarget) {
    if (type == NSEventTypeLeftMouseDragged) {
      if (_clickType == NSEventTypeLeftMouseDown) {
        [self _sendTouchEvent:@"touchMove"];
      }
      return;
    }
  } else {
    if (type == NSEventTypeMouseMoved) {
      if (_inContentView == NO) {
        return; // Ignore "mouseMove" events outside the "contentView"
      }

      [self _setHoverTarget:targetView];
      return;
    }

    if (targetView == nil) {
      return;
    }

    if (type == NSEventTypeLeftMouseDown || type == NSEventTypeRightMouseDown) {
      // When the "firstResponder" is a NSTextView, "mouseUp" and "mouseDragged" events are swallowed,
      // so we should skip tracking of "mouseDown" events in order to avoid corrupted state.
      if ([self.firstResponder isKindOfClass:NSTextView.class]) {
        NSView *fieldEditor = (NSView *)self.firstResponder;
        if ([_clickOrigin isDescendantOf:fieldEditor]) {
          return;
        }

        // Blur the field editor when clicking outside it, except when "prefersFocus" is true.
        BOOL isReactInput = [fieldEditor isKindOfClass:[RCTFieldEditor class]];
        if (!isReactInput || !((RCTFieldEditor *)fieldEditor).delegate.prefersFocus) {
          [self makeFirstResponder:nil];
        }
      }

      if (type == NSEventTypeLeftMouseDown) {
        [self _sendTouchEvent:@"touchStart"];
      }

      _clickTarget = targetView;
      _clickType = type;
      return;
    }
  }

  if (type == NSEventTypeLeftMouseUp) {
    if (_clickType == NSEventTypeLeftMouseDown) {
      [self _sendTouchEvent:@"touchEnd"];
      _clickTarget = nil;
      _clickType = 0;
    }

    // Update the "hoveredView" now, instead of waiting for the next "mouseMove" event.
    [self _setHoverTarget:targetView];
    return;
  }

  if (type == NSEventTypeRightMouseUp) {
    if (_clickType == NSEventTypeRightMouseDown) {
      // Right clicks must end in the same React "ancestor chain" they started in.
      if ([_clickTarget isDescendantOf:targetView]) {
        [self _sendMouseEvent:@"contextMenu"];
      }
      _clickTarget = nil;
      _clickType = 0;
    }

    // Update the "hoveredView" now, instead of waiting for the next "mouseMove" event.
    [self _setHoverTarget:targetView];
    return;
  }
}

#pragma mark - Private methods

static inline BOOL hasFlag(NSUInteger flags, NSUInteger flag) {
  return (flags & flag) == flag;
}

- (NSView *)hitTest:(NSPoint)point withEvent:(NSEvent *)event
{
  NSView *targetView = _clickOrigin ?: [self.rootView hitTest:point];
  // The "clickOrigin" is used for special handling of field editors. It only exists between mouseUp and mouseDown events.
  if (event.type == NSEventTypeLeftMouseDown || event.type == NSEventTypeRightMouseDown) {
    _clickOrigin = targetView;
  } else if (event.type == NSEventTypeLeftMouseUp || event.type == NSEventMaskRightMouseUp) {
    _clickOrigin = nil;
  }
  // The "targetView" must be a React-managed view.
  while (targetView && !targetView.reactTag) {
    targetView = targetView.superview;
  }

  // By convention, all coordinates, whether they be touch coordinates, or
  // measurement coordinates are with respect to the root view.
  CGPoint absoluteLocation = [self.rootView convertPoint:point fromView:nil];
  CGPoint relativeLocation = targetView.layer
    ? [self.rootView.layer convertPoint:absoluteLocation toLayer:targetView.layer]
    : [self.rootView convertPoint:absoluteLocation toView:targetView];

  _mouseInfo[@"pageX"] = @(RCTSanitizeNaNValue(absoluteLocation.x, @"pageX"));
  _mouseInfo[@"pageY"] = @(RCTSanitizeNaNValue(absoluteLocation.y, @"pageY"));
  _mouseInfo[@"locationX"] = @(RCTSanitizeNaNValue(relativeLocation.x, @"locationX"));
  _mouseInfo[@"locationY"] = @(RCTSanitizeNaNValue(relativeLocation.y, @"locationY"));
  _mouseInfo[@"timestamp"] = @(event.timestamp * 1000); // in ms, for JS
  _mouseInfo[@"target"] = targetView.reactTag;
  _mouseInfo[@"relatedTarget"] = nil;

  NSUInteger flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
  _mouseInfo[@"altKey"] = @(hasFlag(flags, NSEventModifierFlagOption));
  _mouseInfo[@"ctrlKey"] = @(hasFlag(flags, NSEventModifierFlagControl));
  _mouseInfo[@"metaKey"] = @(hasFlag(flags, NSEventModifierFlagCommand));
  _mouseInfo[@"shiftKey"] = @(hasFlag(flags, NSEventModifierFlagShift));

  return targetView;
}

- (void)_setHoverTarget:(NSView *)view
{
  NSNumber *target = view.reactTag;
  NSNumber *relatedTarget;

  if (_hoverTarget) {
    relatedTarget = view == _hoverTarget ? nil : _hoverTarget.reactTag;
    if (relatedTarget) {
      _mouseInfo[@"target"] = relatedTarget;
      _mouseInfo[@"relatedTarget"] = target;

      _hoverTarget = nil;
      [self _sendMouseEvent:@"mouseOut"];
    }
  }

  if (view) {
    _mouseInfo[@"target"] = target;
    _mouseInfo[@"relatedTarget"] = relatedTarget;

    if (_hoverTarget == nil) {
      _hoverTarget = view;
      [self _sendMouseEvent:@"mouseOver"];

      // Ensure "mouseMove" events have no "relatedTarget" property.
      _mouseInfo[@"relatedTarget"] = nil;
    }

    [self _sendMouseEvent:@"mouseMove"];
  }
}

- (void)_sendMouseEvent:(NSString *)eventName
{
  RCTMouseEvent *event = [[RCTMouseEvent alloc] initWithEventName:eventName
                                                           target:_mouseInfo[@"target"]
                                                         userInfo:_mouseInfo
                                                    coalescingKey:_coalescingKey];

  if (![eventName isEqualToString:@"mouseMove"]) {
    _coalescingKey++;
  }

  [_bridge.eventDispatcher sendEvent:event];
}

- (void)_sendTouchEvent:(NSString *)eventName
{
  RCTTouchEvent *event = [[RCTTouchEvent alloc] initWithEventName:eventName
                                                         reactTag:self.rootView.reactTag
                                                     reactTouches:@[_mouseInfo]
                                                   changedIndexes:@[@0]
                                                    coalescingKey:_coalescingKey];

  if (![eventName isEqualToString:@"touchMove"]) {
    _coalescingKey++;
  }

  [_bridge.eventDispatcher sendEvent:event];
}

- (void)_javaScriptDidLoad:(__unused NSNotification *)notification
{
  _enabled = YES;
}

- (void)_bridgeWillReload:(__unused NSNotification *)notification
{
  _enabled = NO;
}

@end
