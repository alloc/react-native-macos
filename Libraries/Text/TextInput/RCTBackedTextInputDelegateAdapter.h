/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <AppKit/AppKit.h>

#import "RCTBackedTextInputViewProtocol.h"
#import "RCTBackedTextInputDelegate.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - RCTBackedTextFieldDelegateAdapter (for NSTextField)

@interface RCTBackedTextFieldDelegateAdapter : NSObject

- (instancetype)initWithTextField:(NSTextField<RCTBackedTextInputViewProtocol> *)backedTextInputView;

- (void)skipNextTextInputDidChangeSelectionEventWithTextRange:(NSRange)textRange;
- (void)selectedTextRangeWasSet;
- (void)textFieldDidFocus;
- (void)textFieldDidBlur;
- (BOOL)shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;

@end

#pragma mark - RCTBackedTextViewDelegateAdapter (for NSTextView)

@interface RCTBackedTextViewDelegateAdapter : NSObject

- (instancetype)initWithTextView:(NSTextView<RCTBackedTextInputViewProtocol> *)backedTextInputView;

- (void)skipNextTextInputDidChangeSelectionEventWithTextRange:(NSRange)textRange;
- (void)textViewDidFocus;

@end

NS_ASSUME_NONNULL_END
