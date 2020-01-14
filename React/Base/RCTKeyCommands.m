#import "RCTKeyCommands.h"
#import "RCTDefines.h"
#import "RCTUtils.h"

@implementation RCTKeyCommand
{
  BOOL _preventDefault;
}

- (instancetype)initWithEvent:(NSEvent *)event
{
  if ((self = [super init])) {
    _event = event;
  }
  return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)init)

- (NSString *)input
{
  return _event.characters;
}

- (unsigned short)keyCode
{
  return _event.keyCode;
}

- (BOOL)isDown
{
  return _event.type == NSEventTypeKeyDown;
}

- (NSEventModifierFlags)flags
{
  return _event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
}

- (NSWindow *)window
{
  return _event.window;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<%@:%p input=\"%@\" flags=%zd isDown=%@>",
          [self class], self, self.input, self.flags, self.isDown ? @"YES" : @"NO"];
}

- (BOOL)matchesInput:(NSString *)input
{
  return [self matchesInput:input flags:0];
}

- (BOOL)matchesInput:(NSString *)input flags:(NSEventModifierFlags)flags
{
  return [self.input isEqualToString:input] && self.flags == flags;
}

- (BOOL)matchesKeyCode:(RCTKeyCode)keyCode
{
  return [self matchesKeyCode:keyCode flags:0];
}

- (BOOL)matchesKeyCode:(RCTKeyCode)keyCode flags:(NSEventModifierFlags)flags
{
  return self.keyCode == keyCode && self.flags == flags;
}

- (void)preventDefault
{
  _preventDefault = YES;
}

- (BOOL)isDefaultPrevented
{
  return _preventDefault;
}

@end

@implementation RCTKeyCommands
{
  NSHashTable<id<RCTKeyCommandObserver>> *_observers;
}

+ (instancetype)sharedInstance
{
  static RCTKeyCommands *sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [self new];
  });

  return sharedInstance;
}

- (instancetype)init
{
  if ((self = [super init])) {
    _observers = [NSHashTable weakObjectsHashTable];
  }
  return self;
}

- (void)addObserver:(NSObject<RCTKeyCommandObserver> *)observer
{
  RCTAssertMainQueue();
  [_observers addObject:observer];
}

- (void)removeObserver:(NSObject<RCTKeyCommandObserver> *)observer
{
  RCTAssertMainQueue();
  [_observers removeObject:observer];
}

- (BOOL)observeEvent:(NSEvent *)event
{
  RCTAssertMainQueue();
  RCTKeyCommand *command = [[RCTKeyCommand alloc] initWithEvent:event];
  for (id<RCTKeyCommandObserver> observer in _observers) {
    [observer observeKeyCommand:command];
  }
  return command.isDefaultPrevented;
}

@end

@implementation NSWindow (RCTKeyCommands)

- (void)keyDown:(NSEvent *)event
{
  BOOL isDefaultPrevented = [[RCTKeyCommands sharedInstance] observeEvent:event];
  if (!isDefaultPrevented) {
    [super keyDown:event];
  }
}

- (void)keyUp:(NSEvent *)event
{
  BOOL isDefaultPrevented = [[RCTKeyCommands sharedInstance] observeEvent:event];
  if (!isDefaultPrevented) {
    [super keyUp:event];
  }
}

@end

