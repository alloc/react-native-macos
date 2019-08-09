/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 * @providesModule WindowDrag
 * @noflow
 */
'use strict';

const React = require('react');
const ReactNative = require('ReactNative');
const TouchableWithoutFeedback = require('TouchableWithoutFeedback');
const UIManager = require('UIManager');
const View = require('View');

const DRAG_REF = 'drag';

class WindowDrag extends React.Component {
  render() {
    return (
      <TouchableWithoutFeedback
        onPressIn={() => (
          UIManager.dispatchViewManagerCommand(
            ReactNative.findNodeHandle(this.refs[DRAG_REF]),
            UIManager.RCTView.Commands.performWindowDrag,
            null
          )
        )}>
        <View ref={DRAG_REF} {...this.props} />
      </TouchableWithoutFeedback>
    );
  }
}

module.exports = WindowDrag;
