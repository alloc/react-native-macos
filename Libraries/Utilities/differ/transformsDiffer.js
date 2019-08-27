/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 * @providesModule transformsDiffer
 */
'use strict';

const transformsDiffer = function(one, two) {
  return one !== two ||
    !one || !two ||
    (Array.isArray(one) && one.length !== two.length) ||
    JSON.stringify(one) !== JSON.stringify(two);
};

module.exports = transformsDiffer;
