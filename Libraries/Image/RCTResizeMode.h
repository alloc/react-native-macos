/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <React/RCTConvert.h>

typedef NS_ENUM(NSInteger, RCTResizeMode) {
  RCTResizeModeContain = 0,
  RCTResizeModeCover = 1,
  RCTResizeModeStretch = 2,
  RCTResizeModeCenter = 3,
  RCTResizeModeRepeat = -1,
};

@interface RCTConvert(RCTResizeMode)

+ (RCTResizeMode)RCTResizeMode:(id)json;

@end
