/**
 * Copyright (c) 2015-present, Alec Larson
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 * @providesModule Gradient
 * @noflow
 */
'use strict';

const React = require('react');
const requireNativeComponent = require('requireNativeComponent');

const RCTGradient = requireNativeComponent('RCTGradient');

const Gradient = React.forwardRef((props, ref) => (
  <RCTGradient ref={ref} {...props} />
));

Gradient.displayName = 'Gradient';

module.exports = Gradient;
