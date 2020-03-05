/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTTextView : NSView

@property (nonatomic, assign) BOOL selectable;
@property (nonatomic, assign) CATransform3D transform;

- (void)setTextStorage:(NSTextStorage *)textStorage
          contentFrame:(CGRect)contentFrame
       descendantViews:(NSArray<NSView *> *)descendantViews;

@end

NS_ASSUME_NONNULL_END
