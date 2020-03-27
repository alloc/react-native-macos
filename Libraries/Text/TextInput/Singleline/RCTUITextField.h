/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <AppKit/AppKit.h>

#import "RCTBackedTextInputViewProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * Just regular NSTextField... but much better!
 */
@interface RCTUITextField : NSTextField <RCTBackedTextInputViewProtocol>

- (instancetype)initWithCoder:(NSCoder *)decoder NS_UNAVAILABLE;

@property (nonatomic, weak) id<RCTBackedTextInputDelegate> textInputDelegate;

@property (nonatomic, assign) BOOL caretHidden;
@property (nonatomic, assign, readonly) BOOL textWasPasted;
// @property (nonatomic, strong, nullable) NSColor *placeholderColor;
@property (nonatomic, assign) NSEdgeInsets paddingInsets;
@property (nonatomic, strong, nullable) RCTTextAttributes *textAttributes;

/* macOS only */
@property (nonatomic, assign) BOOL prefersFocus;
@property (nonatomic, copy, nullable) NSString *textAlignVertical;

@end

NS_ASSUME_NONNULL_END
