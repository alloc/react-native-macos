/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTReloadCommand.h"

#import "RCTAssert.h"
#import "RCTKeyCommands.h"

@interface RCTReloadCommand : NSObject <RCTKeyCommandObserver>

@property (nonatomic, strong) NSHashTable<id<RCTReloadListener>> *listeners;

@end

@implementation RCTReloadCommand

- (instancetype)init
{
  if (self = [super init]) {
    _listeners = [NSHashTable weakObjectsHashTable];
    
    [RCTKeyCommands.sharedInstance addObserver:self];
  }
  return self;
}

- (void)observeKeyCommand:(RCTKeyCommand *)command
{
  if (command.isDown && [command matchesInput:@"r" flags:NSEventModifierFlagCommand]) {
    for (id<RCTReloadListener> listener in _listeners.allObjects) {
      [listener didReceiveReloadCommand];
    }
  }
}

@end

void RCTRegisterReloadCommandListener(id<RCTReloadListener> listener)
{
  RCTAssertMainQueue();
  
  static RCTReloadCommand *command;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    command = [RCTReloadCommand new];
  });
  
  [command.listeners addObject:listener];
}
