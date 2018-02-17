/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTSlider.h"

@implementation RCTSlider
{
  float _unclippedValue;
}

- (void)setValue:(float)value
{
  _unclippedValue = value;
  [self setDoubleValue:value];
}

- (void)setMinimumValue:(float)minimumValue
{
  self.minValue = minimumValue;
  [self setDoubleValue:_unclippedValue];
}

- (void)setMaximumValue:(float)maximumValue
{
  self.maxValue = maximumValue;
  [self setDoubleValue:_unclippedValue];
}


@end
