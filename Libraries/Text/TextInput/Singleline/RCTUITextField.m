/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTUITextField.h"

#import <React/RCTUtils.h>
#import <React/NSView+React.h>
#import <React/RCTWindow.h>

#import "RCTBackedTextInputDelegateAdapter.h"
#import "RCTFieldEditor.h"
#import "NSText+Editing.h"
#import "NSFont+LineHeight.h"

// The "field editor" is a NSTextView whose delegate is this NSTextField.
@interface NSTextField () <NSTextViewDelegate>
@end

@interface RCTUITextFieldCell : NSTextFieldCell
@property (nullable, assign) RCTUITextField *controlView;
- (void)setTextAttributes:(RCTTextAttributes *)textAttributes;
@end

@interface RCTUITextField (RCTFieldEditor) <RCTFieldEditorDelegate>
- (RCTFieldEditor *)currentEditor;
- (RCTUITextFieldCell *)cell;
@end

@implementation RCTUITextField {
  RCTBackedTextFieldDelegateAdapter *_textInputDelegateAdapter;
}

+ (Class)cellClass
{
  return [RCTUITextFieldCell class];
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_textDidChange)
                                                 name:NSControlTextDidChangeNotification
                                               object:self];

    self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.allowsEditingTextAttributes = NO;
    self.drawsBackground = NO;
    self.focusRingType = NSFocusRingTypeNone;
    self.bordered = NO;
    self.bezeled = NO;

    self.cell.scrollable = YES;
    self.cell.usesSingleLineMode = YES;

    _textInputDelegateAdapter = [[RCTBackedTextFieldDelegateAdapter alloc] initWithTextField:self];
  }

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)_textDidChange
{
  _textWasPasted = NO;
}

#pragma mark - Overrides

- (void)setTextAttributes:(RCTTextAttributes *)textAttributes
{
  _textAttributes = textAttributes;

  self.font = textAttributes.effectiveFont;
  self.textColor = textAttributes.effectiveForegroundColor;
  self.backgroundColor = nil;
  self.alignment = textAttributes.alignment;
  
  self.cell.textAttributes = textAttributes;
}

- (NSRange)selectedTextRange
{
  return self.currentEditor.selectedRange;
}

- (void)setSelectedTextRange:(NSRange)selectedTextRange notifyDelegate:(BOOL)notifyDelegate
{
  if (!notifyDelegate) {
    // We have to notify an adapter that following selection change was initiated programmatically,
    // so the adapter must not generate a notification for it.
    [_textInputDelegateAdapter skipNextTextInputDidChangeSelectionEventWithTextRange:selectedTextRange];
  }

  self.currentEditor.selectedRange = selectedTextRange;
  [_textInputDelegateAdapter selectedTextRangeWasSet];
}

- (void)textViewDidChangeSelection:(NSNotification *)notification
{
  [super textViewDidChangeSelection:notification];
  [_textInputDelegateAdapter selectedTextRangeWasSet];
}

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)range replacementString:(NSString *)string
{
  if ([super textView:textView shouldChangeTextInRange:range replacementString:string]) {
    return [_textInputDelegateAdapter shouldChangeTextInRange:range replacementText:string];
  }
  return NO;
}

- (void)textDidEndEditing:(NSNotification *)notification
{
  [super textDidEndEditing:notification];
  if (self.currentEditor == nil) {
    [_textInputDelegateAdapter textFieldDidBlur];
  }
}

- (void)mouseDown:(NSEvent *)event
{
  RCTWindow *window = (RCTWindow *)self.window;
  // BUGFIX: Avoid handling mouseDown events not meant for us.
  if ([window.clickOrigin isDescendantOf:self]) {
    [super mouseDown:event];
  }
}

// Do nothing here, as it messes with RCTWindow cursor support.
- (void)resetCursorRects {}

- (BOOL)becomeFirstResponder
{
  if ([super becomeFirstResponder]) {
    // Move the cursor to the end of the current text. Note: Mouse clicks override this selection (which is intended).
    self.currentEditor.selectedRange = NSMakeRange(self.stringValue.length, 0);

    self.currentEditor.textContainerInset = (NSSize){_paddingInsets.left, _paddingInsets.top};
    [_textInputDelegateAdapter performSelector:@selector(textFieldDidFocus) withObject:nil afterDelay:0.0];
    return YES;
  }
  return NO;
}

- (void)setFrame:(NSRect)frame
{
  if ([self.textAlignVertical isEqualToString:@"center"]) {
    CGFloat lineHeight = self.font.lineHeight;
    CGFloat heightDelta = frame.size.height - lineHeight;
    if (heightDelta > 0) {
      frame.origin.y += (heightDelta / 2) - (lineHeight / 16);
    }
  }

  // The baseline is always 13 pixels from the view's top edge, so that strings with
  // mixed font sizes are aligned by their baselines. But we want align text so its
  // ascender is always touching the view's top edge by default.
  frame.origin.y += self.font.ascender - 13.0;

  // HACK: The text naturally has 2 pixels of left/right padding.
  frame.origin.x -= 2;
  frame.size.width += 4;

  [super setFrame:frame];
}

#pragma mark - RCTBackedTextInputViewProtocol

- (NSAttributedString *)attributedText
{
  return self.attributedStringValue;
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
  self.attributedStringValue = attributedText;
}

- (void)selectAll:(nullable id)sender
{
  [self.currentEditor selectAll:sender];
}

#pragma mark - RCTFieldEditorDelegate

- (void)fieldEditor:(RCTFieldEditor *)editor didPaste:(NSString *)text
{
  _textWasPasted = YES;
}

- (void)fieldEditorDidReturn:(RCTFieldEditor *)editor
{
  if ([self.textInputDelegate textInputShouldReturn]) {
    [self.textInputDelegate textInputDidReturn];
    [self.currentEditor endEditing:NO];
  }
}

@end

@interface NSTextFieldCell ()
- (id)_textAttributes;
@end

@implementation RCTUITextFieldCell
{
  RCTFieldEditor *_fieldEditor;
  NSDictionary *_effectiveTextAttributes;
}

@dynamic controlView;

static inline CGRect NSEdgeInsetsInsetRect(CGRect rect, NSEdgeInsets insets) {
  rect.origin.x    += insets.left;
  rect.origin.y    += insets.top;
  rect.size.width  -= (insets.left + insets.right);
  rect.size.height -= (insets.top  + insets.bottom);
  return rect;
}

- (NSRect)drawingRectForBounds:(NSRect)bounds
{
  NSRect rect = [super drawingRectForBounds:bounds];
  return NSEdgeInsetsInsetRect(rect, self.controlView.paddingInsets);
}

- (NSTextView *)fieldEditorForView:(NSView *)controlView
{
  if (_fieldEditor == nil) {
    _fieldEditor = [RCTFieldEditor new];
  }
  return _fieldEditor;
}

- (id)_textAttributes
{
  return _effectiveTextAttributes ?: [super _textAttributes];
}

- (void)setTextAttributes:(RCTTextAttributes *)textAttributes
{
  _effectiveTextAttributes = textAttributes.effectiveTextAttributes;

  NSTextView *fieldEditor = [self fieldEditorForView:self.controlView];

  fieldEditor.defaultParagraphStyle = _effectiveTextAttributes[NSParagraphStyleAttributeName];
  fieldEditor.typingAttributes = _effectiveTextAttributes;
  fieldEditor.backgroundColor = NSColor.clearColor;

  NSTextStorage *string = fieldEditor.textStorage;

  [string beginEditing];
  [string addAttributes:_effectiveTextAttributes range:NSMakeRange(0, string.length)];
  [string endEditing];
}

@end
