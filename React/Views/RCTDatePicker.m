/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTDatePicker.h"

#import "RCTUtils.h"
#import "NSView+React.h"

@interface RCTDatePicker ()

@property (nonatomic, copy) RCTBubblingEventBlock onChange;

@end

@implementation RCTDatePicker

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    [self setTarget:self];
    [self setAction:@selector(didChange:)];
  }
  return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:(NSCoder *)aDecoder)

- (void)didChange:(__unused id)sender
{
  if (_onChange) {
    _onChange(@{
      @"timestamp": @(self.dateValue.timeIntervalSince1970 * 1000.0),
      @"timeInterval": @(self.timeInterval)
    });
  }
}

@end
