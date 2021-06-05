/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTDeviceInfo.h"
#import <AppKit/AppKit.h>

//#import "RCTAccessibilityManager.h"
#import "RCTAssert.h"
#import "RCTEventDispatcher.h"
#import "RCTUtils.h"

@implementation RCTDeviceInfo {
  id subscription;
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

- (void)setBridge:(RCTBridge *)bridge
{
  _bridge = bridge;
  
  NSWindow *currentWindow = RCTKeyWindow();
  
  subscription = [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowDidResizeNotification
                                                                   object:currentWindow queue:nil usingBlock:^(__unused NSNotification * n){
    [self didReceiveNewContentSizeMultiplier];
  }];
}

static NSDictionary *RCTExportedDimensions(__unused RCTBridge *bridge)
{
  RCTAssertMainQueue();

  NSScreen *screen = [NSScreen mainScreen];
  if (!screen) {
    return nil;
  }
  
  NSDictionary *description = [screen deviceDescription];
  NSSize screenPixelSize = [[description objectForKey:NSDeviceSize] sizeValue];
  CGSize screenPhysicalSize = CGDisplayScreenSize(
    [[description objectForKey:@"NSScreenNumber"] unsignedIntValue]
  );

  CGFloat dpi = screenPixelSize.width / (screenPhysicalSize.width / 25.4);
  if (isnan(dpi)) {
    dpi = 0;
  }

  // Don't use RCTScreenSize since it the interface orientation doesn't apply to it
  CGSize screenSize = screen.frame.size;
  NSDictionary *dims = @{
                         @"dpi": @(dpi),
                         @"width": @(screenSize.width),
                         @"height": @(screenSize.height),
                         @"scale": @(screen.backingScaleFactor),
                         @"fontScale": @(1) // TODO: fix accessibility bridge.accessibilityManager.multiplier)
                         };

  CGSize windowSize = RCTKeyWindow().frame.size;
  NSDictionary *windowDims = @{
                         @"width": @(windowSize.width),
                         @"height": @(windowSize.height),
                         @"scale": @(screen.backingScaleFactor),
                         @"fontScale": @(1) // TODO: fix accessibility bridge.accessibilityManager.multiplier)
                         };
  return @{
           @"window": windowDims,
           @"screen": dims
           };
}

- (void)dealloc
{
  [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)invalidate
{
  RCTExecuteOnMainQueue(^{
    self->_bridge = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
  });
}

- (NSDictionary<NSString *, id> *)constantsToExport
{
  return @{
    @"Dimensions": RCTExportedDimensions(_bridge),
  };
}

- (void)didReceiveNewContentSizeMultiplier
{
  RCTBridge *bridge = _bridge;
  RCTExecuteOnMainQueue(^{
    // Report the event across the bridge.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSDictionary *dimensions = RCTExportedDimensions(bridge);
    if (dimensions) {
      [bridge.eventDispatcher sendDeviceEventWithName:@"didUpdateDimensions"
                                               body:dimensions];
    }
#pragma clang diagnostic pop
  });
}

@end
