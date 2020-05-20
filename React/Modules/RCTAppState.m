/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTAppState.h"

#import "RCTAssert.h"
#import "RCTBridge.h"
#import "RCTEventDispatcher.h"
#import "RCTWindow.h"
#import "RCTUtils.h"
#import "NSView+React.h"

static NSString *RCTCurrentAppBackgroundState()
{
  if (RCTRunningInAppExtension()) {
    return @"extension";
  }

  NSApplication *app = RCTSharedApplication();
  return app.active ? @"active" : @"inactive";
}

@implementation RCTAppState
{
  NSString *_lastKnownState;
}

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

- (NSDictionary *)constantsToExport
{
  return @{
    @"initialAppState": RCTCurrentAppBackgroundState(),
  };
}

#pragma mark - Lifecycle

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"appStateDidChange",
           @"memoryWarning",
           @"frameDidFire"];
}

- (void)startObserving
{
  _lastKnownState = RCTCurrentAppBackgroundState();

  NSNotificationCenter *notifs = [NSNotificationCenter defaultCenter];

  for (NSString *name in @[NSApplicationDidBecomeActiveNotification,
                           NSApplicationDidResignActiveNotification,
                           NSApplicationDidFinishLaunchingNotification]) {

    [notifs addObserver:self
               selector:@selector(handleAppStateDidChange)
                   name:name
                 object:nil];
  }
}

- (void)stopObserving
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - App Notification Methods

- (void)handleAppStateDidChange
{
  NSString *newState = RCTCurrentAppBackgroundState();
  if (![newState isEqualToString:_lastKnownState]) {
    _lastKnownState = newState;
    [self sendEventWithName:@"appStateDidChange"
                       body:@{@"app_state": _lastKnownState}];
  }
}

#pragma mark - Public API

/**
 * Get the current background/foreground state of the app
 */
RCT_EXPORT_METHOD(getCurrentAppState:(RCTResponseSenderBlock)callback
                  error:(__unused RCTResponseSenderBlock)error)
{
  callback(@[@{@"app_state": RCTCurrentAppBackgroundState()}]);
}

RCT_EXPORT_METHOD(exit)
{
  [RCTSharedApplication() terminate:self];
}

@end
