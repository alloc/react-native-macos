/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <AppKit/AppKit.h>

@interface RCTModalHostViewController : NSViewController

@property (nonatomic, copy) void (^boundsDidChangeBlock)(CGRect newBounds);
@property (nonatomic, copy) void (^initCompletionHandler)(NSWindow *window);
@property (nonatomic, copy) void (^closeCompletionHandler)();

@end
