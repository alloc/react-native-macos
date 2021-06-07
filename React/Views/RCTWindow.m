/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTWindow.h"

#import "RCTLog.h"
#import "RCTUtils.h"
#import "RCTCursor.h"
#import "RCTMouseEvent.h"
#import "RCTTouchEvent.h"
#import "RCTFieldEditor.h"
#import "NSView+React.h"
#import <QuartzCore/CATransaction.h>

#pragma mark - NSView+RCTCursor

@implementation NSView (RCTCursor)

- (RCTCursor)cursor
{
  return RCTCursorInherit;
}

// NSView subclasses must synthesize their own "_cursor" ivar.
- (void)setCursor:(__unused RCTCursor)cursor
{
  RCTWindow *window = (RCTWindow *)self.window;
  if ([window isKindOfClass:[RCTWindow class]]) {
    if (self == window.cursorProvider) {
      window.cursorProvider = self;
    } else if (
      [window.hoverTarget isDescendantOf:self] &&
      [self isDescendantOf:window.cursorProvider]
    ) {
      [window updateCursorImage];
    }
  }
}

@end

#pragma mark - CATransaction (Private)

typedef enum {
  kCATransactionPhasePreLayout,
  kCATransactionPhasePreCommit,
  kCATransactionPhasePostCommit,
} CATransactionPhase;

@interface CATransaction (Private)
+ (void)addCommitHandler:(void(^)(void))block forPhase:(CATransactionPhase)phase;
@end

#pragma mark - RCTWindow

NSString *const RCTViewsDidUpdateNotification = @"RCTViewsDidUpdateNotification";

@implementation RCTWindow
{
  RCTCursor _lastCursor;
  NSMutableDictionary *_mouseInfo;
  NSView *_clickTarget;
  NSEventType _clickType;
  uint16_t _coalescingKey;
  id _hoverMonitor;

  BOOL _enabled;
  NSMutableSet<NSView *> *_updatedViews;
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
    _bridge = [bridge isKindOfClass:RCTBridge.class] ? bridge : [bridge valueForKey:@"_parentBridge"];
    _enabled = !_bridge.isLoading;
    _updatedViews = [NSMutableSet new];

    _mouseInfo = [NSMutableDictionary new];
    _mouseInfo[@"changedTouches"] = @[]; // Required for "mouseMove" events
    _mouseInfo[@"identifier"] = @0; // Required for "touch*" events

    self.initialFirstResponder = nil;
    self.autorecalculatesKeyViewLoop = YES;

    // The owner must set "contentView" manually.
    super.contentView = nil;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(RCT_windowDidChangeScreen:)
                                                 name:NSWindowDidChangeScreenNotification
                                               object:self];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(RCT_javaScriptDidLoad:)
                                                 name:RCTJavaScriptDidLoadNotification
                                               object:_bridge];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(RCT_bridgeWillReload:)
                                                 name:RCTBridgeWillReloadNotification
                                               object:_bridge];

     [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(_clearTargets)
                                                  name:NSWindowDidResignKeyNotification
                                                object:self];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_clearTargets)
                                                 name:NSApplicationDidResignActiveNotification
                                               object:nil];
  }

  return self;
}

@dynamic contentView;

- (NSView *)rootView
{
  return self.contentView.contentView;
}

- (void)close
{
  _closed = YES;
  self.contentView = nil;
  [super close];
}

- (void)sendEvent:(NSEvent *)event
{
  // Avoid sending JS events too early.
  if (_enabled == NO) {
    return [super sendEvent:event];
  }

  NSEventType type = event.type;

  if (type == NSEventTypeMouseExited) {
    if (event.trackingArea.owner == self.contentView) {
      [self _clearTargets];
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

  NSResponder *prevResponder = self.firstResponder;

  // Perform a hitTest before sendEvent in case a field editor is active.
  NSView *targetView = [self hitTest:event.locationInWindow withEvent:event];
  [super sendEvent:event];
  
  if (_clickTarget) {
    if (type == NSEventTypeLeftMouseDragged) {
      _lastLeftMouseEvent = event;
      if (_clickType == NSEventTypeLeftMouseDown) {
        [self _sendTouchEvent:@"touchMove"];
      }
      return;
    }
  } else {
    if (type == NSEventTypeMouseMoved) {
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

        // The field editor may be newly focused, or the user is clicking inside it.
        if (fieldEditor != prevResponder || [_clickOrigin isDescendantOf:fieldEditor]) {
          _clickOrigin = nil;
          return;
        }

        // Blur the field editor when clicking outside it, except when "prefersFocus" is true.
        BOOL isReactInput = [fieldEditor isKindOfClass:[RCTFieldEditor class]];
        if (isReactInput && !((RCTFieldEditor *)fieldEditor).delegate.prefersFocus) {
          [self makeFirstResponder:nil];
        }
      }

      if (type == NSEventTypeLeftMouseDown) {
        _lastLeftMouseEvent = event;
        [self _sendTouchEvent:@"touchStart"];
      }

      _clickTarget = targetView;
      _clickType = type;
      return;
    }
  }

  if (type == NSEventTypeLeftMouseUp) {
    _lastLeftMouseEvent = event;
    
    if (_clickType == NSEventTypeLeftMouseDown) {
      [self _sendTouchEvent:@"touchEnd"];
      _clickTarget = nil;
      _clickType = 0;
    }

    // Update the "hoveredView" now, instead of waiting for the next "mouseMove" event.
    [self _setHoverTarget:[self reactHitTest:event.locationInWindow]];
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
    [self _setHoverTarget:[self reactHitTest:event.locationInWindow]];
    return;
  }
}

- (void)updateCursorImage
{
  NSView *view = _hoverTarget ?: self.contentView;
  while (view) {
    if (view.cursor != RCTCursorInherit) {
      self.cursorProvider = view;
      return;
    }
    view = view.superview;
  }
}

- (void)setCursorProvider:(NSView *)view
{
  if (_hoverTarget && ![_hoverTarget isDescendantOf:view]) {
    RCTLogWarn(@"The 'cursorProvider' must contain the 'hoverTarget'");
    return;
  }
  
  _cursorProvider = view;
  
  RCTCursor cursor = view.cursor;
  if (cursor != _lastCursor) {
    _lastCursor = cursor;
    
    if (cursor == RCTCursorNone) {
      [NSCursor hide];
    } else {
      [NSCursor unhide];
      [NSCursorForRCTCursor(cursor) set];
    }
  }
}

- (void)scrollViewDidScroll
{
  // TODO: Find the new hover target.
  if (_clickTarget == nil) {
    [self _setHoverTarget:nil];
  }
}

- (void)viewDidUpdate:(NSView *)view
{
  if (_updatedViews.count == 0) {
    [CATransaction addCommitHandler:^{
      [[NSNotificationCenter defaultCenter]
          postNotificationName:RCTViewsDidUpdateNotification
                        object:self
                      userInfo:@{@"updatedViews":_updatedViews}];
      
      [_updatedViews removeAllObjects];
    } forPhase:kCATransactionPhasePreCommit];
  }
  [_updatedViews addObject:view];
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
  } else if (event.type == NSEventTypeLeftMouseUp || event.type == NSEventTypeRightMouseUp) {
    _clickOrigin = nil;
  }
  // The "targetView" must be a React-managed view.
  while (targetView && !targetView.reactTag) {
    targetView = targetView.superview;
  }
  
  if (!targetView) {
    return nil;
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

- (NSView *)reactHitTest:(NSPoint)point
{
  NSView *view = [self.rootView hitTest:point];
  while (view && !view.reactTag) {
    view = view.superview;
  }
  return view;
}

static NSCursor *NSCursorForRCTCursor(RCTCursor cursor)
{
  switch (cursor) {
    case RCTCursorDefault: return NSCursor.arrowCursor;
    case RCTCursorPointer: return NSCursor.pointingHandCursor;
    case RCTCursorText: return NSCursor.IBeamCursor;
    case RCTCursorMove: return NSCursor._moveCursor;
    case RCTCursorGrab: return NSCursor.openHandCursor;
    case RCTCursorGrabbing: return NSCursor.closedHandCursor;
    default: return nil;
  }
}

// HACK: Do nothing here to prevent AppKit default behavior of updating the cursor whenever a view moves.
- (void)_setCursorForMouseLocation:(__unused CGPoint)point {}

- (void)_clearTargets
{
  if (_clickTarget) {
    if (_clickType == NSEventTypeLeftMouseDown) {
      [self _sendTouchEvent:@"touchCancel"];
    }
    _clickTarget = nil;
    _clickType = 0;
  }

  [self _setHoverTarget:nil];
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
      if (!view) {
        [self updateCursorImage];
        if (_hoverMonitor) {
          [NSEvent removeMonitor:_hoverMonitor];
          _hoverMonitor = nil;
        }
      }
    }
  } else if (view) {
    // Clear the hover target when another app receives a MouseMoved event.
    _hoverMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskMouseMoved handler:^(NSEvent * _Nonnull event) {
      if (event.window) return;
      
      // BUGFIX: For some reason, we receive windowless events even if the app is moused over,
      //   but (luckily) we can use "hitTest:withEvent:" to avoid clearing the hover target.
      NSView *hitView = [self hitTest:event.locationInWindow withEvent:event];
      if (!hitView) {
        [self _setHoverTarget:nil];
      }
    }];
  }

  if (view) {
    _mouseInfo[@"target"] = target;
    _mouseInfo[@"relatedTarget"] = relatedTarget;

    if (_hoverTarget == nil) {
      _hoverTarget = view;
      [self _sendMouseEvent:@"mouseOver"];
      [self updateCursorImage];

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
                                                         userInfo:[_mouseInfo copy]
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
                                                     reactTouches:@[[_mouseInfo copy]]
                                                   changedIndexes:@[@0]
                                                    coalescingKey:_coalescingKey];

  if (![eventName isEqualToString:@"touchMove"]) {
    _coalescingKey++;
  }

  [_bridge.eventDispatcher sendEvent:event];
}

- (void)setContentView:(RCTRootView *)contentView
{
  [super setContentView:contentView];
  if (self.screen && [contentView respondsToSelector:@selector(setScaleFactor:)]) {
    contentView.scaleFactor = self.backingScaleFactor;
  }
}

- (void)RCT_windowDidChangeScreen:(__unused NSNotification *)notification
{
  self.contentView.scaleFactor = self.backingScaleFactor;
}

- (void)RCT_javaScriptDidLoad:(__unused NSNotification *)notification
{
  _enabled = YES;
}

- (void)RCT_bridgeWillReload:(__unused NSNotification *)notification
{
  _enabled = NO;
}

@end
