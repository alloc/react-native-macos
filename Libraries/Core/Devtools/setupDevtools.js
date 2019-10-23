/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @providesModule setupDevtools
 * @flow
 */
'use strict';

const Platform = require('Platform');

/**
 * Sets up developer tools for React Native.
 * You can use this module directly, or just require InitializeCore.
 */
if (__DEV__) {
  // TODO (T45803484) Enable devtools for bridgeless RN
  if (!global.RN$Bridgeless) {
    if (!global.__RCTProfileIsProfiling) {
      require('../setUpReactDevTools');

      // Set up inspector
      const JSInspector = require('JSInspector');
      JSInspector.registerAgent(require('NetworkAgent'));
    }

    // if (!Platform.isTesting) {
    //   const HMRClient = require('HMRClient');
    //   [
    //     'trace',
    //     'info',
    //     'warn',
    //     'log',
    //     'group',
    //     'groupCollapsed',
    //     'groupEnd',
    //     'debug',
    //   ].forEach(level => {
    //     const originalFunction = console[level];
    //     // $FlowFixMe Overwrite console methods
    //     console[level] = function(...args) {
    //       HMRClient.log(level, args);
    //       originalFunction.apply(console, args);
    //     };
    //   });
    // }
  }
}
