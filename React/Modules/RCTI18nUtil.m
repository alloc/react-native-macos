/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import "RCTI18nUtil.h"

@implementation RCTI18nUtil
{
  NSUserDefaults *defaults;
}

+ (instancetype)sharedInstance
{
  static RCTI18nUtil *sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [self new];
    [sharedInstance swapLeftAndRightInRTL: true];
  });
  
  return sharedInstance;
}

- (instancetype)init
{
  if (self = [super init]) {
    defaults = [NSUserDefaults standardUserDefaults];

    NSNumber *allowRTL = [defaults objectForKey:@"RCTI18nUtil_allowRTL"];
    _isRTLAllowed = allowRTL == nil || allowRTL.boolValue;
    _isRTLForced = [defaults boolForKey:@"RCTI18nUtil_forceRTL"];
    _doLeftAndRightSwapInRTL = [defaults boolForKey:@"RCTI18nUtil_makeRTLFlipLeftAndRightStyles"];
  }
  return self;
}

/**
 * Check if the app is currently running on an RTL locale.
 * This only happens when the app:
 * - is forcing RTL layout, regardless of the active language (for development purpose)
 * - allows RTL layout when using RTL locale
 */
- (BOOL)isRTL
{
  if ([self isRTLForced]) {
    return YES;
  }
  if ([self isRTLAllowed] && [self isApplicationPreferredLanguageRTL]) {
    return YES;
  }
  return NO;
}

- (void)allowRTL:(BOOL)value
{
  _isRTLAllowed = value;
  [defaults setBool:value forKey:@"RCTI18nUtil_allowRTL"];
}

- (void)forceRTL:(BOOL)value
{
  _isRTLForced = value;
  [defaults setBool:value forKey:@"RCTI18nUtil_forceRTL"];
}

- (void)swapLeftAndRightInRTL:(BOOL)value
{
  _doLeftAndRightSwapInRTL = value;
  [defaults setBool:value forKey:@"RCTI18nUtil_makeRTLFlipLeftAndRightStyles"];
}

// Check if the current device language is RTL
- (BOOL)isDevicePreferredLanguageRTL
{
  NSLocaleLanguageDirection direction = [NSLocale characterDirectionForLanguage:[[NSLocale preferredLanguages] objectAtIndex:0]];
  return direction == NSLocaleLanguageDirectionRightToLeft;
}

// Check if the current application language is RTL
- (BOOL)isApplicationPreferredLanguageRTL
{
  NSString *preferredAppLanguage = [[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0];
  NSLocaleLanguageDirection direction = [NSLocale characterDirectionForLanguage:preferredAppLanguage];
  return direction == NSLocaleLanguageDirectionRightToLeft;
}

@end
