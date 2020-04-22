/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @providesModule AppState
 * @flow
 */
'use strict';

const MissingNativeEventEmitterShim = require('MissingNativeEventEmitterShim');
const NativeEventEmitter = require('NativeEventEmitter');
const NativeModules = require('NativeModules');
const RCTAppState = NativeModules.AppState;

const logError = require('logError');
const invariant = require('fbjs/lib/invariant');

import type {Layout} from 'CoreEventTypes';

type Screen = {|
  +id: number,
  +scale: number,
  +layout: Layout,
|};

type Window = {|
  +rootTag: number,
  +screen: Screen,
|};

const eventTypes = ['change', 'memoryWarning', 'rootViewWillAppear', 'windowDidChangeScreen', 'windowWillClose'];

/**
 * `AppState` can tell you if the app is in the foreground or background,
 * and notify you when the state changes.
 *
 * See http://facebook.github.io/react-native/docs/appstate.html
 */
class AppState extends NativeEventEmitter {

  _eventHandlers: Object;
  currentState: ?string;
  isAvailable: boolean = true;
  windows: { [rootTag: number]: { rootTag: number, screen: Screen } };

  constructor() {
    super(RCTAppState);

    this.isAvailable = true;
    this._eventHandlers = eventTypes.reduce((out, type) => {
      out[type] = new Map();
      return out;
    }, {});

    // TODO: Remove the 'active' fallback after `initialAppState` is exported by
    // the Android implementation.
    this.currentState = RCTAppState.initialAppState || 'active';

    let eventUpdated = false;

    // TODO: this is a terrible solution - in order to ensure `currentState`
    // prop is up to date, we have to register an observer that updates it
    // whenever the state changes, even if nobody cares. We should just
    // deprecate the `currentState` property and get rid of this.
    this.addListener(
      'appStateDidChange',
      (appStateData) => {
        eventUpdated = true;
        this.currentState = appStateData.app_state;
      }
    );

    this.windows = RCTAppState.windows.reduce((acc, state) => {
      acc[state.rootTag] = state;
      return acc;
    }, {});

    const onWindowChange = state => {
      this.windows[state.rootTag] = state;
    }

    this.addListener('rootViewWillAppear', onWindowChange);
    this.addListener('windowDidChangeScreen', onWindowChange);

    this.addListener('windowWillClose', rootTag => {
      delete this.windows[rootTag];
    });

    // TODO: see above - this request just populates the value of `currentState`
    // when the module is first initialized. Would be better to get rid of the
    // prop and expose `getCurrentAppState` method directly.
    RCTAppState.getCurrentAppState(
      (appStateData) => {
        if (!eventUpdated) {
          this.currentState = appStateData.app_state;
        }
      },
      logError
    );
  }

  // TODO: now that AppState is a subclass of NativeEventEmitter, we could
  // deprecate `addEventListener` and `removeEventListener` and just use
  // addListener` and `listener.remove()` directly. That will be a breaking
  // change though, as both the method and event names are different
  // (addListener events are currently required to be globally unique).
   /**
   * Add a handler to AppState changes by listening to the `change` event type
   * and providing the handler.
   *
   * See http://facebook.github.io/react-native/docs/appstate.html#addeventlistener
   */
  addEventListener(
    type: string,
    handler: Function
  ) {
    invariant(
      eventTypes.indexOf(type) !== -1,
      'Trying to subscribe to unknown event: "%s"', type
    );
    if (type === 'change') {
      this._eventHandlers[type].set(handler, this.addListener(
        'appStateDidChange',
        (appStateData) => {
          handler(appStateData.app_state);
        }
      ));
    } else {
      this._eventHandlers[type].set(handler, this.addListener(type, handler));
    }
  }

  /**
   * Remove a handler by passing the `change` event type and the handler.
   *
   * See http://facebook.github.io/react-native/docs/appstate.html#removeeventlistener
   */
  removeEventListener(
    type: string,
    handler: Function
  ) {
    invariant(
      eventTypes.indexOf(type) !== -1,
      'Trying to remove listener for unknown event: "%s"', type
    );
    if (!this._eventHandlers[type].has(handler)) {
      return;
    }
    this._eventHandlers[type].get(handler).remove();
    this._eventHandlers[type].delete(handler);
  }
}

if (__DEV__ && !RCTAppState) {
  class MissingNativeAppStateShim extends MissingNativeEventEmitterShim {
    constructor() {
      super('RCTAppState', 'AppState');
    }

    get currentState(): ?string {
      this.throwMissingNativeModule();
    }

    addEventListener(...args: Array<any>) {
      this.throwMissingNativeModule();
    }

    removeEventListener(...args: Array<any>) {
      this.throwMissingNativeModule();
    }
  }

  // This module depends on the native `RCTAppState` module. If you don't
  // include it, `AppState.isAvailable` will return `false`, and any method
  // calls will throw. We reassign the class variable to keep the autodoc
  // generator happy.
  AppState = new MissingNativeAppStateShim();
} else {
  AppState = new AppState();
}

module.exports = AppState;
