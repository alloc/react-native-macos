#import <AppKit/AppKit.h>

#pragma mark - RCTKeyCommand

typedef unsigned short RCTKeyCode;

@interface RCTKeyCommand : NSObject

/// The upper or lower cased characters being pressed.
@property (nonatomic, readonly) NSString *input;

/// The device-independent key code.
@property (nonatomic, readonly) RCTKeyCode keyCode;

/// True for keydown events. False for keyup events.
@property (nonatomic, readonly) BOOL isDown;

/// The modifiers being pressed. (eg: command, control, etc)
@property (nonatomic, readonly) NSEventModifierFlags flags;

/// The window that received the original NSEvent.
@property (nonatomic, readonly) NSWindow *window;

/// The original NSEvent that triggered this command.
@property (nonatomic, readonly) NSEvent *event;

- (BOOL)matchesInput:(NSString *)input;
- (BOOL)matchesInput:(NSString *)input flags:(NSEventModifierFlags)flags;

- (BOOL)matchesKeyCode:(RCTKeyCode)keyCode;
- (BOOL)matchesKeyCode:(RCTKeyCode)keyCode flags:(NSEventModifierFlags)flags;

- (void)preventDefault;
- (BOOL)isDefaultPrevented;

@end

#pragma mark - RCTKeyCommandObserver

@protocol RCTKeyCommandObserver <NSObject>

- (void)observeKeyCommand:(RCTKeyCommand *)command;

@end

#pragma mark - RCTKeyCommands

@interface RCTKeyCommands : NSObject

+ (instancetype)sharedInstance;

- (void)addObserver:(NSObject<RCTKeyCommandObserver> *)observer;

- (void)removeObserver:(NSObject<RCTKeyCommandObserver> *)observer;

@end
