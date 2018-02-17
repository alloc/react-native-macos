/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */


#import <AppKit/AppKit.h>

#import <React/RCTComponent.h>

@interface RCTSwitch : NSButton

@property (nonatomic, assign) BOOL wasOn;
@property (nonatomic, copy) RCTBubblingEventBlock onChange;

@end
