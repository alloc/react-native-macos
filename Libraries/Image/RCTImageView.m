/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTImageView.h"

#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTImageSource.h>
#import <React/RCTUtils.h>
#import <React/NSView+React.h>

#import "RCTImageBlurUtils.h"
#import "RCTImageLoader.h"
#import "RCTImageUtils.h"

/**
 * Determines whether an image of `currentSize` should be reloaded for display
 * at `idealSize`.
 */
static BOOL RCTShouldReloadImageForSizeChange(CGSize currentSize, CGSize idealSize)
{
  static const CGFloat upscaleThreshold = 1.2;
  static const CGFloat downscaleThreshold = 0.5;

  CGFloat widthMultiplier = idealSize.width / currentSize.width;
  CGFloat heightMultiplier = idealSize.height / currentSize.height;

  return widthMultiplier > upscaleThreshold || widthMultiplier < downscaleThreshold ||
    heightMultiplier > upscaleThreshold || heightMultiplier < downscaleThreshold;
}

/**
 * See RCTConvert (ImageSource). We want to send down the source as a similar
 * JSON parameter.
 */
static NSDictionary *onLoadParamsForSource(RCTImageSource *source)
{
  NSDictionary *dict = @{
    @"width": @(source.size.width),
    @"height": @(source.size.height),
    @"url": source.request.URL.absoluteString,
  };
  return @{ @"source": dict };
}

@interface RCTImageView ()

@property (nonatomic, copy) RCTDirectEventBlock onLoadStart;
@property (nonatomic, copy) RCTDirectEventBlock onProgress;
@property (nonatomic, copy) RCTDirectEventBlock onError;
@property (nonatomic, copy) RCTDirectEventBlock onPartialLoad;
@property (nonatomic, copy) RCTDirectEventBlock onLoad;
@property (nonatomic, copy) RCTDirectEventBlock onLoadEnd;

@end

@implementation RCTImageView
{
  // Weak reference back to the bridge, for image loading
  __weak RCTBridge *_bridge;

  // The image source that's currently displayed
  RCTImageSource *_imageSource;

  // The image source that's being loaded from the network
  RCTImageSource *_pendingImageSource;

  // Size of the displayed image.
  CGSize _targetSize;
  
  // Size of the image being loaded.
  CGSize _pendingTargetSize;

  // A block that can be invoked to cancel the most recent call to -reloadImage, if any
  RCTImageLoaderCancellationBlock _reloadImageCancellationBlock;

  // Whether the latest change of props requires the image to be reloaded
  BOOL _needsReload;
}


- (instancetype)initWithBridge:(RCTBridge *)bridge
{
  if ((self = [super initWithFrame:NSZeroRect])) {
    _bridge = bridge;
    [self setWantsLayer:YES];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

RCT_NOT_IMPLEMENTED(- (instancetype)init)
RCT_NOT_IMPLEMENTED(- (instancetype)initWithFrame:(NSRect)frameRect)
RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:(NSCoder *)coder)

- (void)updateWithImage:(NSImage *)image
{
  if (!image) {
    super.image = nil;
    return;
  }

  /*
  if (_resizeMode == RCTResizeModeRepeat) {
    image = [image resizableImageWithCapInsets:_capInsets resizingMode:UIImageResizingModeTile];
  } else if (!UIEdgeInsetsEqualToEdgeInsets(NSEdgeInsetsZero, _capInsets)) {
    // Applying capInsets of 0 will switch the "resizingMode" of the image to "tile" which is undesired
    image = [image resizableImageWithCapInsets:_capInsets resizingMode:UIImageResizingModeStretch];
  }
   */

  // Apply trilinear filtering to smooth out mis-sized images
  self.layer.minificationFilter = kCAFilterTrilinear;
  self.layer.magnificationFilter = kCAFilterTrilinear;

  super.image = image;
}

- (void)setImage:(NSImage *)image
{
  image = image ?: _defaultImage;
  if (image != self.image) {
    [self updateWithImage:image];
  }
}

// TODO: Replace it with proper method
static inline BOOL UIEdgeInsetsEqualToEdgeInsets(NSEdgeInsets insets1, NSEdgeInsets insets2) {
  return CGRectEqualToRect(CGRectMake(insets1.left, insets1.top, insets1.right, insets1.bottom),
                           CGRectMake(insets2.left, insets2.top, insets2.right, insets2.bottom));
}

- (void)setBlurRadius:(CGFloat)blurRadius
{
  if (blurRadius != _blurRadius) {
    _blurRadius = blurRadius;
    _needsReload = YES;
  }
}

- (void)setCapInsets:(NSEdgeInsets)capInsets

{
  if (!UIEdgeInsetsEqualToEdgeInsets(_capInsets, capInsets)) {
    if (UIEdgeInsetsEqualToEdgeInsets(_capInsets, NSEdgeInsetsZero) ||
        UIEdgeInsetsEqualToEdgeInsets(capInsets, NSEdgeInsetsZero)) {
      _capInsets = capInsets;
      // Need to reload image when enabling or disabling capInsets
      _needsReload = YES;
    } else {
      _capInsets = capInsets;
      [self updateWithImage:self.image];
    }
  }
}

/*
- (void)setRenderingMode:(UIImageRenderingMode)renderingMode
{
  if (_renderingMode != renderingMode) {
    _renderingMode = renderingMode;
    [self updateWithImage:self.image];
  }
}*/

- (void)setImageSources:(NSArray<RCTImageSource *> *)imageSources
{
  if (![imageSources isEqual:_imageSources]) {
    _imageSources = [imageSources copy];
    
    [self updateImageIfNeeded];
  }
}

- (void)setResizeMode:(RCTResizeMode)resizeMode
{
  if (_resizeMode != resizeMode) {
    _resizeMode = resizeMode;
    if (_resizeMode == RCTResizeModeRepeat) {
      // Repeat resize mode is handled by the UIImage. Use scale to fill
      // so the repeated image fills the UIImageView.
      self.imageScaling = NSImageScaleAxesIndependently;
    } else if (_resizeMode == RCTResizeModeCover) {
      self.imageScaling = NSImageScaleNone;
    } else if (_resizeMode == RCTResizeModeStretch) {
      self.imageScaling = NSImageScaleAxesIndependently;
    } else {
      self.imageScaling = NSImageScaleProportionallyDown;
    }

    if ([self shouldReloadImageSourceAfterResize]) {
      _needsReload = YES;
    }
  }
}


- (void)cancelImageLoad
{
  RCTImageLoaderCancellationBlock previousCancellationBlock = _reloadImageCancellationBlock;
  if (previousCancellationBlock) {
    previousCancellationBlock();
    _reloadImageCancellationBlock = nil;
  }

  _pendingImageSource = nil;
}

- (void)clearImage
{
  [self cancelImageLoad];
  [self.layer removeAnimationForKey:@"contents"];
  self.image = nil;
  _imageSource = nil;
}

- (void)clearImageIfDetached
{
  if (!self.window) {
    [self clearImage];
  }
}

- (BOOL)hasMultipleSources
{
  return _imageSources.count > 1;
}

- (RCTImageSource *)imageSourceForSize:(CGSize)size
{
  if (![self hasMultipleSources]) {
    return _imageSources.firstObject;
  }

  // Need to wait for layout pass before deciding.
  if (CGSizeEqualToSize(size, CGSizeZero)) {
    return nil;
  }

  const CGFloat targetImagePixels = size.width * size.height;

  RCTImageSource *bestSource = nil;
  CGFloat bestFit = CGFLOAT_MAX;
  for (RCTImageSource *source in _imageSources) {
    CGSize imgSize = source.size;
    const CGFloat imagePixels =
      imgSize.width * imgSize.height * source.scale * source.scale;
    const CGFloat fit = ABS(1 - (imagePixels / targetImagePixels));

    if (fit < bestFit) {
      bestFit = fit;
      bestSource = source;
    }
  }
  return bestSource;
}

- (BOOL)shouldReloadImageSourceAfterResize
{
  // If capInsets are set, image doesn't need reloading when resized
  return UIEdgeInsetsEqualToEdgeInsets(_capInsets, NSEdgeInsetsZero);
}

- (void)loadImageSource:(RCTImageSource *)source withSize:(CGSize)targetSize
{
  [self cancelImageLoad];
  _needsReload = NO;
  
  if (source && self.window && targetSize.width > 0 && targetSize.height > 0) {
    _pendingImageSource = source;
    _pendingTargetSize = targetSize;

    if (_onLoadStart) {
      _onLoadStart(nil);
    }

    RCTImageLoaderProgressBlock progressHandler = nil;
    if (_onProgress) {
      progressHandler = ^(int64_t loaded, int64_t total) {
        self->_onProgress(@{
          @"loaded": @((double)loaded),
          @"total": @((double)total),
        });
      };
    }

    __weak RCTImageView *weakSelf = self;
    RCTImageLoaderPartialLoadBlock partialLoadHandler = ^(NSImage *image) {
      [weakSelf imageLoaderLoadedImage:image error:nil forImageSource:source size:targetSize partial:YES];
    };

    CGSize imageSize = self.bounds.size;
    CGFloat imageScale = self.window.backingScaleFactor;
    if (!UIEdgeInsetsEqualToEdgeInsets(_capInsets, NSEdgeInsetsZero)) {
      // Don't resize images that use capInsets
      imageSize = CGSizeZero;
      imageScale = source.scale;
    }

    RCTImageLoaderCompletionBlock completionHandler = ^(NSError *error, NSImage *loadedImage) {
      [weakSelf imageLoaderLoadedImage:loadedImage error:error forImageSource:source size:targetSize partial:NO];
    };

    _reloadImageCancellationBlock =
    [_bridge.imageLoader loadImageWithURLRequest:source.request
                                            size:imageSize
                                           scale:imageScale
                                         clipped:NO
                                      resizeMode:_resizeMode
                                   progressBlock:progressHandler
                                partialLoadBlock:partialLoadHandler
                                 completionBlock:completionHandler];
  } else {
    [self clearImage];
  }
}

- (void)imageLoaderLoadedImage:(NSImage *)loadedImage
                         error:(NSError *)error
                forImageSource:(RCTImageSource *)source
                          size:(CGSize)targetSize
                       partial:(BOOL)isPartialLoad
{
  if (![source isEqual:_pendingImageSource] || !CGSizeEqualToSize(targetSize, _pendingTargetSize)) {
    // Bail out if source has changed since we started loading
    return;
  }

  if (error) {
    if (_onError) {
      _onError(@{ @"error": error.localizedDescription });
    }
    if (_onLoadEnd) {
      _onLoadEnd(nil);
    }
    return;
  }

  void (^setImageBlock)(NSImage *) = ^(NSImage *image) {
    if (!isPartialLoad) {
      self->_imageSource = source;
      self->_targetSize = targetSize;
      self->_pendingImageSource = nil;
      self->_pendingTargetSize = CGSizeZero;
    }

    if (image.reactKeyframeAnimation) {
      [self.layer addAnimation:image.reactKeyframeAnimation forKey:@"contents"];
    } else {
      [self.layer removeAnimationForKey:@"contents"];
      self.image = image;
    }

    if (isPartialLoad) {
      if (self->_onPartialLoad) {
        self->_onPartialLoad(nil);
      }
    } else {
      if (self->_onLoad) {
        RCTImageSource *sourceLoaded = [source imageSourceWithSize:image.size scale:source.scale];
        self->_onLoad(onLoadParamsForSource(sourceLoaded));
      }
      if (self->_onLoadEnd) {
        self->_onLoadEnd(nil);
      }
    }
  };

  if (_blurRadius > __FLT_EPSILON__) {
    NSScreen *screen = self.window.screen;
    // Blur on a background thread to avoid blocking interaction
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      RCTSetScreen(screen);
      NSImage *blurredImage = RCTBlurredImageWithRadius(loadedImage, self->_blurRadius);
      RCTExecuteOnMainQueue(^{
        setImageBlock(blurredImage);
      });
    });
  } else {
    // No blur, so try to set the image on the main thread synchronously to minimize image
    // flashing. (For instance, if this view gets attached to a window, then -didMoveToWindow
    // calls -reloadImage, and we want to set the image synchronously if possible so that the
    // image property is set in the same CATransaction that attaches this view to the window.)
    RCTExecuteOnMainQueue(^{
      setImageBlock(loadedImage);
    });
  }
}

- (void)reactSetFrame:(CGRect)frame
{
  CGSize oldSize = self.frame.size;

  [super reactSetFrame:frame];

  if (!CGSizeEqualToSize(frame.size, oldSize)) {
    [self updateImageIfNeeded];
  }
}

- (void)didSetProps:(NSArray<NSString *> *)changedProps
{
  if (_needsReload) {
    [self loadImageSource:_imageSource withSize:_targetSize];
  }
}

- (void)viewDidMoveToWindow
{
  [super viewDidMoveToWindow];

  if (!self.window) {
    // Cancel loading the image if we've moved offscreen. In addition to helping
    // prioritise image requests that are actually on-screen, this removes
    // requests that have gotten "stuck" from the queue, unblocking other images
    // from loading.
    [self cancelImageLoad];
  }
}

- (void)viewDidChangeBackingProperties
{
  [self updateImageIfNeeded];
}

// Good for size changes and source changes
- (BOOL)updateImageIfNeeded
{
  CGFloat targetScale = self.window.backingScaleFactor;
  CGSize targetSize = RCTSizeInPixels(self.bounds.size, targetScale);
  if (CGSizeEqualToSize(targetSize, CGSizeZero)) {
    [self clearImage];
    return NO;
  }
  
  RCTImageSource *source = [self imageSourceForSize:targetSize];
  if (!source) {
    [self clearImage];
    return NO;
  }
  
  CGSize oldTargetSize = CGSizeZero;
  
  if ([source isEqual:_pendingImageSource]) {
    oldTargetSize = _pendingTargetSize;
  }
  else if ([source isEqual:_imageSource]) {
    oldTargetSize = _targetSize;
    
    // Cancel loading so the current source is used
    [self cancelImageLoad];
    
    if (self.image) {
      NSImageRep *image = self.image.representations[0];
      CGSize imageSize = CGSizeMake(image.pixelsWide, image.pixelsHigh);
      CGSize idealSize = RCTTargetSize(imageSize, 1.0, targetSize, 1.0, _resizeMode, YES);
      
      // Skip update if the current image size is close enough
      if (!RCTShouldReloadImageForSizeChange(imageSize, idealSize)) {
        return NO;
      }
    }
  }
  // Load a new source
  else {
    [self loadImageSource:source withSize:targetSize];
    return YES;
  }
  
  // Skip update if cap insets are used or the size is unchanged
  if (![self shouldReloadImageSourceAfterResize] || CGSizeEqualToSize(targetSize, oldTargetSize)) {
    return NO;
  }
  
  // Load an old source with a new size
  [self loadImageSource:source withSize:targetSize];
  return YES;
}

@end
