/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <AppKit/AppKit.h>

@interface NSView (Private)

// remove clipped subviews implementation
- (void)react_remountAllSubviews;
- (void)react_updateClippedSubviewsWithClipRect:(CGRect)clipRect relativeToView:(NSView *)clipView;
- (NSView *)react_findClipView;

@end
