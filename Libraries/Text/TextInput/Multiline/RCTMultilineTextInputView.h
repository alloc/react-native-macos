/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTBaseTextInputView.h"

NS_ASSUME_NONNULL_BEGIN

@class RCTTextScrollView;

@interface RCTMultilineTextInputView : RCTBaseTextInputView
@property (nonatomic, copy) RCTDirectEventBlock onScroll;
@end

#pragma mark -

@protocol RCTTextScrollViewDelegate
- (void)scrollViewDidScroll:(RCTTextScrollView *)scrollView;
@end

#pragma mark -

@interface RCTTextScrollView : NSScrollView
@property (nonatomic, weak) id<RCTTextScrollViewDelegate> delegate;
@property (nonatomic, assign) BOOL scrollEnabled;
@property (readonly) NSPoint contentOffset;
@end

NS_ASSUME_NONNULL_END
