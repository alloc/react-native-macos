/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <AppKit/AppKit.h>

#import <React/RCTResizeMode.h>

@class RCTBridge;
@class RCTImageSource;

@interface RCTImageView : NSImageView

- (instancetype)initWithBridge:(RCTBridge *)bridge NS_DESIGNATED_INITIALIZER;

@property (nonatomic, assign) NSEdgeInsets capInsets;
@property (nonatomic, strong) NSImage *defaultImage;
@property (nonatomic, copy) NSArray<RCTImageSource *> *imageSources;
@property (nonatomic, assign) CGFloat blurRadius;
@property (nonatomic, assign) RCTResizeMode resizeMode;
@property (nonatomic, assign) BOOL shrinkToFit;

@end
