/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @providesModule CoreEventTypes
 * @flow
 * @format
 */

'use strict';

export type Layout = {|
  +x: number,
  +y: number,
  +width: number,
  +height: number,
|};
export type LayoutEvent = {|
  +nativeEvent: {|
    +layout: Layout,
  |},
  +persist: () => void,
|};

export type PressEvent = Object;
