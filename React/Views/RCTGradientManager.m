/**
 * Copyright (c) 2019-present, Alec Larson
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTGradientManager.h"

#import "RCTBridge.h"
#import "RCTGradient.h"

@implementation RCTGradientManager

RCT_EXPORT_MODULE()

- (NSView *)view
{
  return [RCTGradient new];
}

RCT_EXPORT_VIEW_PROPERTY(startColor, NSColor)
RCT_EXPORT_VIEW_PROPERTY(endColor, NSColor)
RCT_EXPORT_VIEW_PROPERTY(slopeFactor, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(drawsBeforeStart, BOOL)
RCT_EXPORT_VIEW_PROPERTY(drawsAfterEnd, BOOL)
RCT_EXPORT_VIEW_PROPERTY(startPoint, CGPoint)
RCT_EXPORT_VIEW_PROPERTY(endPoint, CGPoint)

@end
