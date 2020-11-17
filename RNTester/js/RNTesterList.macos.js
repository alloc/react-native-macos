/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 * @flow
 * @providesModule RNTesterList
 */
'use strict';

export type RNTesterExample = {
  key: string,
  module: Object,
  supportsTVOS: boolean
};

const ComponentExamples: Array<RNTesterExample> = [
  {
    key: 'ActivityIndicatorExample',
    module: require('./ActivityIndicatorExample'),
    supportsTVOS: true,
  },
  // {
  //   key: 'ARTExample',
  //   module: require('./ARTExample'),
  //   supportsTVOS: true,
  // },
  {
    key: 'ButtonExample',
    module: require('./ButtonExample'),
    supportsTVOS: true,
  },
  // {
  //   key: 'DatePickerIOSExample',
  //   module: require('./DatePickerIOSExample'),
  //   supportsTVOS: false,
  // },
  {
    key: 'FlatListExample',
    module: require('./FlatListExample'),
    supportsTVOS: true,
  },
  {
    key: 'ImageExample',
    module: require('./ImageExample'),
    supportsTVOS: true,
  },
  // {
  //   key: 'KeyboardAvoidingViewExample',
  //   module: require('./KeyboardAvoidingViewExample'),
  //   supportsTVOS: false,
  // },
  {
    key: 'LayoutEventsExample',
    module: require('./LayoutEventsExample'),
    supportsTVOS: true,
  },
  // {
  //   key: 'ListViewExample',
  //   module: require('./ListViewExample'),
  //   supportsTVOS: true,
  // },
  // {
  //   key: 'ListViewGridLayoutExample',
  //   module: require('./ListViewGridLayoutExample'),
  //   supportsTVOS: true,
  // },
  // {
  //   key: 'ListViewPagingExample',
  //   module: require('./ListViewPagingExample'),
  //   supportsTVOS: true,
  // },
  // {
  {
    key: 'ModalExample',
    module: require('./ModalExample'),
    supportsTVOS: true,
  },
  {
    key: 'MultiColumnExample',
    module: require('./MultiColumnExample'),
    supportsTVOS: true,
  },
  // {
  //   key: 'NavigatorIOSColorsExample',
  //   module: require('./NavigatorIOSColorsExample'),
  //   supportsTVOS: false,
  // },
  // {
  //   key: 'NavigatorIOSBarStyleExample',
  //   module: require('./NavigatorIOSBarStyleExample'),
  //   supportsTVOS: false,
  // },
  // {
  //   key: 'NavigatorIOSExample',
  //   module: require('./NavigatorIOSExample'),
  //   supportsTVOS: true,
  // },
  // {
  //   key: 'PickerExample',
  //   module: require('./PickerExample'),
  //   supportsTVOS: false,
  // },
  // {
  //   key: 'PickerIOSExample',
  //   module: require('./PickerIOSExample'),
  //   supportsTVOS: false,
  // },
  // {
  //   key: 'ProgressViewIOSExample',
  //   module: require('./ProgressViewIOSExample'),
  //   supportsTVOS: true,
  // },
  // {
  //   key: 'RefreshControlExample',
  //   module: require('./RefreshControlExample'),
  //   supportsTVOS: false,
  // },
  // {
  //   key: 'SafeAreaViewExample',
  //   module: require('./SafeAreaViewExample'),
  //   supportsTVOS: true,
  // },
  // {
  //   key: 'ScrollViewExample',
  //   module: require('./ScrollViewExample'),
  //   supportsTVOS: true,
  // },
  {
    key: 'SectionListExample',
    module: require('./SectionListExample'),
    supportsTVOS: true,
  },
  // {
  //   key: 'SegmentedControlIOSExample',
  //   module: require('./SegmentedControlIOSExample'),
  //   supportsTVOS: false,
  // },
  {
    key: 'SliderExample',
    module: require('./SliderExample'),
    supportsTVOS: false,
  },
  // {
  //   key: 'StatusBarExample',
  //   module: require('./StatusBarExample'),
  //   supportsTVOS: false,
  // },
  // {
  //   key: 'SwitchExample',
  //   module: require('./SwitchExample'),
  //   supportsTVOS: false,
  // },
  // {
  //   key: 'TabBarIOSExample',
  //   module: require('./TabBarIOSExample'),
  //   supportsTVOS: true,
  // },
  // {
  //   key: 'TabBarIOSBarStyleExample',
  //   module: require('./TabBarIOSBarStyleExample'),
  //   supportsTVOS: false,
  // },
  {
    key: 'TextExample',
    module: require('./TextExample'),
    supportsTVOS: true,
  },
  {
    key: 'TextInputExample',
    module: require('./TextInputExample'),
    supportsTVOS: true,
  },
  {
    key: 'TouchableExample',
    module: require('./TouchableExample'),
    supportsTVOS: false,
  },
  // {
  //   key: 'TransparentHitTestExample',
  //   module: require('./TransparentHitTestExample'),
  //   supportsTVOS: false,
  // },
  {
    key: 'ViewExample',
    module: require('./ViewExample'),
    supportsTVOS: true,
  },
  {
    key: 'WebViewExample',
    module: require('./WebViewExample'),
    supportsTVOS: false,
  },
];

const APIExamples: Array<RNTesterExample> = [
  // {
  //   key: 'AccessibilityIOSExample',
  //   module: require('./AccessibilityIOSExample'),
  //   supportsTVOS: false,
  // },
  // {
  //   key: 'ActionSheetIOSExample',
  //   module: require('./ActionSheetIOSExample'),
  //   supportsTVOS: true,
  // },
  {
    key: 'AlertExample',
    module: require('./AlertExample').AlertExample,
    supportsTVOS: true,
  },
  // {
  //   key: 'AlertIOSExample',
  //   module: require('./AlertIOSExample'),
  //   supportsTVOS: true,
  // },
  {
    key: 'AnimatedExample',
    module: require('./AnimatedExample'),
    supportsTVOS: true,
  },
  {
    key: 'AnExApp',
    module: require('./AnimatedGratuitousApp/AnExApp'),
    supportsTVOS: true,
  },
  {
    key: 'AppStateExample',
    module: require('./AppStateExample'),
    supportsTVOS: true,
  },
  {
    key: 'AsyncStorageExample',
    module: require('./AsyncStorageExample'),
    supportsTVOS: true,
  },
  {
    key: 'BorderExample',
    module: require('./BorderExample'),
    supportsTVOS: true,
  },
  {
    key: 'BoxShadowExample',
    module: require('./BoxShadowExample'),
    supportsTVOS: true,
  },
  // {
  //   key: 'CameraRollExample',
  //   module: require('./CameraRollExample'),
  //   supportsTVOS: false,
  // },
  {
    key: 'ClipboardExample',
    module: require('./ClipboardExample'),
    supportsTVOS: false,
  },
  {
    key: 'Dimensions',
    module: require('./DimensionsExample'),
    supportsTVOS: true,
  },
  // {
  //   key: 'GeolocationExample',
  //   module: require('./GeolocationExample'),
  //   supportsTVOS: false,
  // },
  // {
  //   key: 'ImageEditingExample',
  //   module: require('./ImageEditingExample'),
  //   supportsTVOS: false,
  // },
  {
    key: 'LayoutAnimationExample',
    module: require('./LayoutAnimationExample'),
    supportsTVOS: true,
  },
  {
    key: 'LayoutExample',
    module: require('./LayoutExample'),
    supportsTVOS: true,
  },
  // {
  //   key: 'LinkingExample',
  //   module: require('./LinkingExample'),
  //   supportsTVOS: true,
  // },
  {
    key: 'NativeAnimationsExample',
    module: require('./NativeAnimationsExample'),
    supportsTVOS: true,
  },
  // {
  //   key: 'NetInfoExample',
  //   module: require('./NetInfoExample'),
  //   supportsTVOS: true,
  // },
  // {
  //   key: 'OrientationChangeExample',
  //   module: require('./OrientationChangeExample'),
  //   supportsTVOS: false,
  // },
  {
    key: 'PanResponderExample',
    module: require('./PanResponderExample'),
    supportsTVOS: false,
  },
  // {
  //   key: 'PointerEventsExample',
  //   module: require('./PointerEventsExample'),
  //   supportsTVOS: false,
  // },
  // {
  //   key: 'PushNotificationIOSExample',
  //   module: require('./PushNotificationIOSExample'),
  //   supportsTVOS: false,
  // },
  {
    key: 'RCTRootViewIOSExample',
    module: require('./RCTRootViewIOSExample'),
    supportsTVOS: true,
  },
  // {
  //   key: 'RTLExample',
  //   module: require('./RTLExample'),
  //   supportsTVOS: true,
  // },
  // {
  //   key: 'ShareExample',
  //   module: require('./ShareExample'),
  //   supportsTVOS: true,
  // },
  // {
  //   key: 'SnapshotExample',
  //   module: require('./SnapshotExample'),
  //   supportsTVOS: true,
  // },
  {
    key: 'TimerExample',
    module: require('./TimerExample'),
    supportsTVOS: true,
  },
  {
    key: 'TransformExample',
    module: require('./TransformExample'),
    supportsTVOS: true,
  },
  // {
  //   key: 'TVEventHandlerExample',
  //   module: require('./TVEventHandlerExample'),
  //   supportsTVOS: true,
  // },
  // {
  //   key: 'VibrationExample',
  //   module: require('./VibrationExample'),
  //   supportsTVOS: false,
  // },
  {
    key: 'WebSocketExample',
    module: require('./WebSocketExample'),
    supportsTVOS: true,
  },
  {
    key: 'XHRExample',
    module: require('./XHRExample'),
    supportsTVOS: true,
  },
];

const Modules = {};

APIExamples.concat(ComponentExamples).forEach(Example => {
  Modules[Example.key] = Example.module;
});

const RNTesterList = {
  APIExamples,
  ComponentExamples,
  Modules,
};

module.exports = RNTesterList;
