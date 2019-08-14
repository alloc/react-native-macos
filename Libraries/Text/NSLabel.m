/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2015 Leonard Hecker
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "NSLabel.h"

#import <React/RCTDefines.h>

@implementation NSLabel
{
  CGRect _contentRect;
}

#pragma mark - NSView overrides

- (instancetype)init
{
  return [self initWithFrame:NSZeroRect];
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
  if (self = [super initWithFrame:frameRect]) {
    _font            = self.defaultFont;
    _textColor       = self.defaultTextColor;
    _backgroundColor = self.defaultBackgroundColor;
    _numberOfLines   = 1;
    _alignment       = NSTextAlignmentLeft;
    _lineBreakMode   = NSLineBreakByTruncatingTail;
    _contentRect     = CGRectNull;
  }

  return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:(NSCoder *)coder)

- (BOOL)isOpaque
{
  return self.backgroundColor.alphaComponent == 1.0;
}

- (BOOL)isFlipped
{
  return YES;
}

- (CGFloat)baselineOffsetFromBottom
{
  return self.contentRect.origin.y;
}

- (NSSize)intrinsicContentSize
{
  return self.contentRect.size;
}

- (void)invalidateIntrinsicContentSize
{
  _contentRect = CGRectNull;
  [super invalidateIntrinsicContentSize];
}

#define SCALED_CEIL(n, scale) ceil((n) * scale) / scale

- (void)drawRect:(NSRect)dirtyRect
{
  NSRect bounds = self.bounds;

  if (_backgroundColor != NSColor.clearColor) {
    [_backgroundColor setFill];
    NSRectFillUsingOperation(bounds, NSCompositeSourceOver);
  }

  if (_text || _attributedText) {
    NSRect contentRect = self.contentRect;

    // https://github.com/lhecker/NSLabel/commit/4f4bb3588051952a0c99f38741dc1e4c7b5a0052#r34695340
    CGFloat scale = self.window.backingScaleFactor;
    CGFloat bottom = SCALED_CEIL(contentRect.size.height, scale);
    CGFloat baselineX = -SCALED_CEIL(contentRect.origin.x, scale);
    CGFloat baselineY = -SCALED_CEIL(contentRect.origin.y, scale);

    NSRect drawRect = (NSRect){
      // The origin represents the baseline.
      {baselineX, bottom - baselineY},
      // The available size for proper alignment.
      bounds.size,
    };

    if (_text) {
      [_text drawWithRect:drawRect options:self.drawingOptions attributes:self.textAttributes context:nil];
    } else {
      [_attributedText drawWithRect:drawRect options:self.drawingOptions];
    }
  }
}

#pragma mark - Private

// invalidated by [NSLabel invalidateIntrinsicContentSize]
- (NSRect)contentRect
{
  if (CGRectIsNull(_contentRect) && (_text || _attributedText)) {
    // TODO: Use infinite width when limited to one line?
    _contentRect = _text
      ? [_text boundingRectWithSize:self.bounds.size options:self.drawingOptions attributes:self.textAttributes context:nil]
      : [_attributedText boundingRectWithSize:self.bounds.size options:self.drawingOptions context:nil];
  }

  return _contentRect;
}

- (NSDictionary *)textAttributes
{
  NSMutableParagraphStyle* style = [NSMutableParagraphStyle new];
  style.alignment = _alignment;
  style.lineBreakMode = _lineBreakMode;
  return @{
    NSFontAttributeName            : _font,
    NSForegroundColorAttributeName : _textColor,
    NSBackgroundColorAttributeName : _backgroundColor,
    NSParagraphStyleAttributeName  : style,
  };
}

- (NSStringDrawingOptions)drawingOptions
{
  NSStringDrawingOptions options = NSStringDrawingUsesFontLeading;

  if (self.numberOfLines == 0) {
    // TODO: This probably affects drawRect origin
    options |= NSStringDrawingUsesLineFragmentOrigin;
  }

  return options;
}

- (NSFont*)defaultFont
{
  return [NSFont labelFontOfSize:12.0];
}

- (NSColor*)defaultTextColor
{
  return [NSColor blackColor];
}

- (NSColor*)defaultBackgroundColor
{
  return [NSColor clearColor];
}

#pragma mark - Display setters

- (void)setText:(NSString*)text
{
  _text = [text copy];
  _attributedText = nil;
  [self invalidateIntrinsicContentSize];
  [self setNeedsDisplay:YES];
}

- (void)setAttributedText:(NSAttributedString*)attributedText
{
  _text = nil;
  _attributedText = [attributedText copy];
  [self invalidateIntrinsicContentSize];
  [self setNeedsDisplay:YES];
}

- (void)setFont:(NSFont*)font
{
  _font = font ? font : self.defaultFont;
  [self invalidateIntrinsicContentSize];
  [self setNeedsDisplay:YES];
}

- (void)setTextColor:(NSColor*)textColor
{
  _textColor = textColor ? textColor : self.defaultTextColor;
  [self setNeedsDisplay:YES];
}

- (void)setBackgroundColor:(NSColor*)backgroundColor
{
  _backgroundColor = backgroundColor ? backgroundColor : self.defaultBackgroundColor;
  [self setNeedsDisplay:YES];
}

- (void)setNumberOfLines:(NSInteger)numberOfLines
{
  _numberOfLines = numberOfLines;
  [self invalidateIntrinsicContentSize];
  [self setNeedsDisplay:YES];
}

- (void)setAlignment:(NSTextAlignment)alignment
{
  _alignment = alignment;
  [self invalidateIntrinsicContentSize];
  [self setNeedsDisplay:YES];
}

- (void)setLineBreakMode:(NSLineBreakMode)lineBreakMode
{
  _lineBreakMode = lineBreakMode;
  [self invalidateIntrinsicContentSize];
  [self setNeedsDisplay:YES];
}

@end
