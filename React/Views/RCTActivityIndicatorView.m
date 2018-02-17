/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTActivityIndicatorView.h"

@implementation RCTActivityIndicatorView {
}

- (void)setHidden:(BOOL)hidden
{
  [super setHidden: hidden];
}

-(void)workaroundForLayer {
  CALayer *layer = [self layer];
  CALayer *backgroundLayer = [[layer sublayers] firstObject];
  [backgroundLayer setHidden:YES];
}

-(void)layout {
  [self workaroundForLayer];
}

@end
