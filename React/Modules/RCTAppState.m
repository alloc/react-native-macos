/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
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
    @"windows": [self serializeWindows:NSApp.windows],
  };
}

#pragma mark - Lifecycle

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"appStateDidChange",
           @"memoryWarning",
           @"rootViewWillAppear",
           @"windowDidChangeScreen"];
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

  [notifs addObserver:self
             selector:@selector(contentWillAppear:)
                 name:RCTContentWillAppearNotification
               object:nil];

  [notifs addObserver:self
             selector:@selector(windowDidChangeScreen:)
                 name:NSWindowDidChangeScreenNotification
               object:nil];
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

- (void)contentWillAppear:(NSNotification *)notification
{
  // Note: Brownfield apps are not supported yet.
  RCTRootView *rootView = notification.object;
  if ([rootView.window isKindOfClass:[RCTWindow class]]) {
    [self sendEventWithName:@"rootViewWillAppear"
                       body:[self serializeWindow:rootView.window]];
  }
}

- (void)windowDidChangeScreen:(NSNotification *)notification
{
  NSWindow *window = notification.object;
  if ([window isKindOfClass:[RCTWindow class]]) {
    [self sendEventWithName:@"windowDidChangeScreen"
                       body:[self serializeWindow:window]];
  }
}

#pragma mark - Serialization

- (NSArray *)serializeWindows:(NSArray<NSWindow *> *)windows
{
  NSMutableArray *json = [NSMutableArray new];
  for (NSWindow *window in windows) {
    if ([window isKindOfClass:[RCTWindow class]]) {
      [json addObject:[self serializeWindow:window]];
    }
  }
  return json;
}

- (NSDictionary *)serializeWindow:(NSWindow *)window
{
  return @{@"rootTag": window.contentView.reactTag,
           @"screen": [self serializeScreen:window.screen]};
}

- (NSDictionary *)serializeScreen:(NSScreen *)screen
{
  NSRect frame = screen.frame;
  return @{@"id": screen.deviceDescription[@"NSScreenNumber"],
           @"scale": @(screen.backingScaleFactor),
           @"layout": @{@"x":@(frame.origin.x),
                        @"y":@(frame.origin.y),
                        @"width":@(frame.size.width),
                        @"height":@(frame.size.height)}};
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
