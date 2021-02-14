/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <AppKit/AppKit.h>
#import "NSView+React.h"

#import <React/NSView+React.h>

@interface RCTPicker : NSComboBox

@property (nonatomic, copy) NSArray<NSDictionary *> *items;
@property (nonatomic, assign) NSInteger selectedIndex;

@property (nonatomic, strong) NSColor *color;
//@property (nonatomic, strong) NSFont *font;
@property (nonatomic, assign) NSTextAlignment textAlign;

@property (nonatomic, copy) RCTBubblingEventBlock onChange;

@end
