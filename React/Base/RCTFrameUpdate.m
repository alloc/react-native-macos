/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <QuartzCore/CVDisplayLink.h>
#import <Foundation/Foundation.h>
#import "RCTFrameUpdate.h"

#import "RCTUtils.h"
#import "AppKit/AppKit.h"

@implementation RCTFrameUpdate

RCT_NOT_IMPLEMENTED(- (instancetype)init)

- (instancetype)initWithTimer:(NSTimer *)timer
{
  if ((self = [super init])) {
    _timestamp = timer.fireDate.timeIntervalSince1970;
    _deltaTime = timer.timeInterval;
  }
  return self;
}

@end
