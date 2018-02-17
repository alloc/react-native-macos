/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <AppKit/AppKit.h>

#import <React/RCTFrameUpdate.h>

@class RCTBridge;

@interface RCTTouchHandler : NSGestureRecognizer

- (instancetype)initWithBridge:(RCTBridge *)bridge NS_DESIGNATED_INITIALIZER;

- (void)attachToView:(NSView *)view;
- (void)detachFromView:(NSView *)view;

- (void)cancel;

- (void)mouseMoved:(NSEvent *)theEvent;

@end
