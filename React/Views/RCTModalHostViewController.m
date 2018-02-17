
/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTModalHostViewController.h"

@implementation RCTModalHostViewController
{
  CGRect _lastViewFrame;
}

- (void)viewDidLayout
{
  [super viewDidLayout];

  if (self.initCompletionHandler && [NSApp modalWindow]) {
    self.initCompletionHandler([NSApp modalWindow]);
  }

  if (self.boundsDidChangeBlock && !CGRectEqualToRect(_lastViewFrame, self.view.frame)) {
    self.boundsDidChangeBlock(self.view.bounds);
    _lastViewFrame = self.view.frame;
  }
}

- (void)viewDidDisappear
{
  dispatch_async(dispatch_get_main_queue(), ^{
    self.closeCompletionHandler();
  });
}

@end
