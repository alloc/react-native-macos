/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AppKit/AppKit.h>

#import "RCTBridge.h"
#import "RCTRootView.h"

@interface RCTWindow : NSWindow

- (instancetype)initWithBridge:(RCTBridge *)bridge
                   contentRect:(NSRect)contentRect
                     styleMask:(NSWindowStyleMask)style
                         defer:(BOOL)defer NS_DESIGNATED_INITIALIZER;

@property (atomic) RCTRootView *contentView;

// Only exists between mouseDown and mouseUp events (may not be a React view)
@property (nonatomic, readonly) NSView *clickOrigin;

// Used in RCTViewManager for the WindowDrag component.
@property (nonatomic, readonly) NSEvent *lastLeftMouseEvent;

// The view directly under the mouse.
@property (nonatomic, readonly) NSView *hoverTarget;

// Updates the hover target while scrolling.
- (void)scrollViewDidScroll;

@end
