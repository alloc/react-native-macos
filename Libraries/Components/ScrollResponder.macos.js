/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 * @providesModule ScrollResponder
 * @flow
 */
'use strict';

const Dimensions = require('Dimensions');
const FrameRateLogger = require('FrameRateLogger');
const ReactNative = require('ReactNative');
const Subscribable = require('Subscribable');
const TextInputState = require('TextInputState');
const UIManager = require('UIManager');

const invariant = require('fbjs/lib/invariant');
const nullthrows = require('fbjs/lib/nullthrows');
const performanceNow = require('fbjs/lib/performanceNow');
const warning = require('fbjs/lib/warning');

const { ScrollViewManager } = require('NativeModules');

/**
 * Mixin that can be integrated in order to handle scrolling that plays well
 * with `ResponderEventPlugin`. Integrate with your platform specific scroll
 * views, or even your custom built (every-frame animating) scroll views so that
 * all of these systems play well with the `ResponderEventPlugin`.
 *
 * iOS scroll event timing nuances:
 * ===============================
 *
 *
 * Scrolling without bouncing, if you touch down:
 * -------------------------------
 *
 * 1. `onMomentumScrollBegin` (when animation begins after letting up)
 *    ... physical touch starts ...
 * 2. `onTouchStartCapture`   (when you press down to stop the scroll)
 * 3. `onTouchStart`          (same, but bubble phase)
 * 4. `onResponderRelease`    (when lifting up - you could pause forever before * lifting)
 * 5. `onMomentumScrollEnd`
 *
 *
 * Scrolling with bouncing, if you touch down:
 * -------------------------------
 *
 * 1. `onMomentumScrollBegin` (when animation begins after letting up)
 *    ... bounce begins ...
 *    ... some time elapses ...
 *    ... physical touch during bounce ...
 * 2. `onMomentumScrollEnd`   (Makes no sense why this occurs first during bounce)
 * 3. `onTouchStartCapture`   (immediately after `onMomentumScrollEnd`)
 * 4. `onTouchStart`          (same, but bubble phase)
 * 5. `onTouchEnd`            (You could hold the touch start for a long time)
 * 6. `onMomentumScrollBegin` (When releasing the view starts bouncing back)
 *
 * So when we receive an `onTouchStart`, how can we tell if we are touching
 * *during* an animation (which then causes the animation to stop)? The only way
 * to tell is if the `touchStart` occurred immediately after the
 * `onMomentumScrollEnd`.
 *
 * This is abstracted out for you, so you can just call this.scrollResponderIsAnimating() if
 * necessary
 *
 * `ScrollResponder` also includes logic for blurring a currently focused input
 * if one is focused while scrolling. The `ScrollResponder` is a natural place
 * to put this logic since it can support not dismissing the keyboard while
 * scrolling, unless a recognized "tap"-like gesture has occurred.
 *
 * The public lifecycle API includes events for keyboard interaction, responder
 * interaction, and scrolling (among others). The keyboard callbacks
 * `onKeyboardWill/Did/*` are *global* events, but are invoked on scroll
 * responder's props so that you can guarantee that the scroll responder's
 * internal state has been updated accordingly (and deterministically) by
 * the time the props callbacks are invoke. Otherwise, you would always wonder
 * if the scroll responder is currently in a state where it recognizes new
 * keyboard positions etc. If coordinating scrolling with keyboard movement,
 * *always* use these hooks instead of listening to your own global keyboard
 * events.
 *
 * Public keyboard lifecycle API: (props callbacks)
 *
 * Standard Keyboard Appearance Sequence:
 *
 *   this.props.onKeyboardWillShow
 *   this.props.onKeyboardDidShow
 *
 * `onScrollResponderKeyboardDismissed` will be invoked if an appropriate
 * tap inside the scroll responder's scrollable region was responsible
 * for the dismissal of the keyboard. There are other reasons why the
 * keyboard could be dismissed.
 *
 *   this.props.onScrollResponderKeyboardDismissed
 *
 * Standard Keyboard Hide Sequence:
 *
 *   this.props.onKeyboardWillHide
 *   this.props.onKeyboardDidHide
 */

const IS_ANIMATING_TOUCH_START_THRESHOLD_MS = 16;

type State = {
  lastMomentumScrollBeginTime: number,
  lastMomentumScrollEndTime: number,
  observedScrollSinceBecomingResponder: boolean,
  becameResponderWhileAnimating: boolean,
};
type Event = Object;

const ScrollResponderMixin = {
  mixins: [Subscribable.Mixin],

  scrollResponderMixinGetInitialState: function(): State {
    return {
      lastMomentumScrollBeginTime: 0,
      lastMomentumScrollEndTime: 0,

      // Reset to false every time becomes responder. This is used to:
      // - Determine if the scroll view has been scrolled and therefore should
      // refuse to give up its responder lock.
      // - Determine if releasing should dismiss the keyboard when we are in
      // tap-to-dismiss mode (this.props.keyboardShouldPersistTaps !== 'always').
      observedScrollSinceBecomingResponder: false,
      becameResponderWhileAnimating: false,
    };
  },

  /**
   * Invoke this from an `onScroll` event.
   */
  scrollResponderHandleScrollShouldSetResponder: function(): boolean {
    return false;
  },

  /**
   * Merely touch starting is not sufficient for a scroll view to become the
   * responder. Being the "responder" means that the very next touch move/end
   * event will result in an action/movement.
   *
   * Invoke this from an `onStartShouldSetResponder` event.
   *
   * `onStartShouldSetResponder` is used when the next move/end will trigger
   * some UI movement/action, but when you want to yield priority to views
   * nested inside of the view.
   *
   * There may be some cases where scroll views actually should return `true`
   * from `onStartShouldSetResponder`: Any time we are detecting a standard tap
   * that gives priority to nested views.
   *
   * - If a single tap on the scroll view triggers an action such as
   *   recentering a map style view yet wants to give priority to interaction
   *   views inside (such as dropped pins or labels), then we would return true
   *   from this method when there is a single touch.
   *
   * - Similar to the previous case, if a two finger "tap" should trigger a
   *   zoom, we would check the `touches` count, and if `>= 2`, we would return
   *   true.
   *
   */
  scrollResponderHandleStartShouldSetResponder: function(e: Event): boolean {
    return false;
  },

  /**
   * There are times when the scroll view wants to become the responder
   * (meaning respond to the next immediate `touchStart/touchEnd`), in a way
   * that *doesn't* give priority to nested views (hence the capture phase):
   *
   * - Currently animating.
   * - Tapping anywhere that is not a text input, while the keyboard is
   *   up (which should dismiss the keyboard).
   *
   * Invoke this from an `onStartShouldSetResponderCapture` event.
   */
  scrollResponderHandleStartShouldSetResponderCapture: function(
    e: Event
  ): boolean {
    return false;
  },

  /**
   * Invoke this from an `onResponderReject` event.
   */
  scrollResponderHandleResponderReject: function() {},

  /**
   * Invoke this from an `onResponderTerminationRequest` event.
   */
  scrollResponderHandleTerminationRequest: function(): boolean {
    return true;
  },

  /**
   * Invoke this from an `onTouchEnd` event.
   *
   * @param {SyntheticEvent} e Event.
   */
  scrollResponderHandleTouchEnd: function(e: Event) {},

  /**
   * Invoke this from an `onTouchCancel` event.
   *
   * @param {SyntheticEvent} e Event.
   */
  scrollResponderHandleTouchCancel: function(e: Event) {},

  /**
   * Invoke this from an `onResponderRelease` event.
   */
  scrollResponderHandleResponderRelease: function(e: Event) {
    this.props.onResponderRelease && this.props.onResponderRelease(e);

    // By default scroll views will unfocus a textField
    // if another touch occurs outside of it
    const currentlyFocusedTextInput = TextInputState.currentlyFocusedField();
    if (this.props.keyboardShouldPersistTaps !== true &&
      this.props.keyboardShouldPersistTaps !== 'always' &&
      currentlyFocusedTextInput != null &&
      e.target !== currentlyFocusedTextInput &&
      !this.state.observedScrollSinceBecomingResponder &&
      !this.state.becameResponderWhileAnimating
    ) {
      this.props.onScrollResponderKeyboardDismissed &&
        this.props.onScrollResponderKeyboardDismissed(e);
      TextInputState.blurTextInput(currentlyFocusedTextInput);
    }
  },

  scrollResponderHandleScroll: function(e: Event) {
    this.state.observedScrollSinceBecomingResponder = true;
    this.props.onScroll && this.props.onScroll(e);
  },

  /**
   * Invoke this from an `onResponderGrant` event.
   */
  scrollResponderHandleResponderGrant: function(e: Event) {
    this.state.observedScrollSinceBecomingResponder = false;
    this.props.onResponderGrant && this.props.onResponderGrant(e);
    this.state.becameResponderWhileAnimating = this.scrollResponderIsAnimating();
  },

  /**
   * Unfortunately, `onScrollBeginDrag` also fires when *stopping* the scroll
   * animation, and there's not an easy way to distinguish a drag vs. stopping
   * momentum.
   *
   * Invoke this from an `onScrollBeginDrag` event.
   */
  scrollResponderHandleScrollBeginDrag: function(e: Event) {
    FrameRateLogger.beginScroll(); // TODO: track all scrolls after implementing onScrollEndAnimation
    this.props.onScrollBeginDrag && this.props.onScrollBeginDrag(e);
  },

  /**
   * Invoke this from an `onScrollEndDrag` event.
   */
  scrollResponderHandleScrollEndDrag: function(e: Event) {
    const { velocity } = e.nativeEvent;
    // - If we are animating, then this is a "drag" that is stopping the scrollview and momentum end
    //   will fire.
    // - If velocity is non-zero, then the interaction will stop when momentum scroll ends or
    //   another drag starts and ends.
    // - If we don't get velocity, better to stop the interaction twice than not stop it.
    if (
      !this.scrollResponderIsAnimating() &&
      (!velocity || (velocity.x === 0 && velocity.y === 0))
    ) {
      FrameRateLogger.endScroll();
    }
    this.props.onScrollEndDrag && this.props.onScrollEndDrag(e);
  },

  /**
   * Invoke this from an `onMomentumScrollBegin` event.
   */
  scrollResponderHandleMomentumScrollBegin: function(e: Event) {
    this.state.lastMomentumScrollBeginTime = performanceNow();
    this.props.onMomentumScrollBegin && this.props.onMomentumScrollBegin(e);
  },

  /**
   * Invoke this from an `onMomentumScrollEnd` event.
   */
  scrollResponderHandleMomentumScrollEnd: function(e: Event) {
    FrameRateLogger.endScroll();
    this.state.lastMomentumScrollEndTime = performanceNow();
    this.props.onMomentumScrollEnd && this.props.onMomentumScrollEnd(e);
  },

  /**
   * Invoke this from an `onTouchStart` event.
   *
   * Since we know that the `SimpleEventPlugin` occurs later in the plugin
   * order, after `ResponderEventPlugin`, we can detect that we were *not*
   * permitted to be the responder (presumably because a contained view became
   * responder). The `onResponderReject` won't fire in that case - it only
   * fires when a *current* responder rejects our request.
   *
   * @param {SyntheticEvent} e Touch Start event.
   */
  scrollResponderHandleTouchStart: function(e: Event) {},

  /**
   * Invoke this from an `onTouchMove` event.
   *
   * Since we know that the `SimpleEventPlugin` occurs later in the plugin
   * order, after `ResponderEventPlugin`, we can detect that we were *not*
   * permitted to be the responder (presumably because a contained view became
   * responder). The `onResponderReject` won't fire in that case - it only
   * fires when a *current* responder rejects our request.
   *
   * @param {SyntheticEvent} e Touch Start event.
   */
  scrollResponderHandleTouchMove: function(e: Event) {
    this.props.onTouchMove && this.props.onTouchMove(e);
  },

  /**
   * A helper function for this class that lets us quickly determine if the
   * view is currently animating. This is particularly useful to know when
   * a touch has just started or ended.
   */
  scrollResponderIsAnimating: function(): boolean {
    const now = performanceNow();
    const timeSinceLastMomentumScrollEnd = now - this.state.lastMomentumScrollEndTime;
    const isAnimating = timeSinceLastMomentumScrollEnd < IS_ANIMATING_TOUCH_START_THRESHOLD_MS ||
      this.state.lastMomentumScrollEndTime < this.state.lastMomentumScrollBeginTime;
    return isAnimating;
  },

  /**
   * Returns the node that represents native view that can be scrolled.
   * Components can pass what node to use by defining a `getScrollableNode`
   * function otherwise `this` is used.
   */
  scrollResponderGetScrollableNode: function(): any {
    return this.getScrollableNode
      ? this.getScrollableNode()
      : ReactNative.findNodeHandle(this);
  },

  /**
   * A helper function to scroll to a specific point in the ScrollView.
   * This is currently used to help focus child TextViews, but can also
   * be used to quickly scroll to any element we want to focus. Syntax:
   *
   * `scrollResponderScrollTo(options: {x: number = 0; y: number = 0; animated: boolean = true})`
   *
   * Note: The weird argument signature is due to the fact that, for historical reasons,
   * the function also accepts separate arguments as as alternative to the options object.
   * This is deprecated due to ambiguity (y before x), and SHOULD NOT BE USED.
   */
  scrollResponderScrollTo: function(
    { x, y, animated }: { x?: number, y?: number, animated?: boolean } = {},
  ) {
    UIManager.dispatchViewManagerCommand(
      nullthrows(this.scrollResponderGetScrollableNode()),
      UIManager.RCTNativeScrollView.Commands.scrollTo,
      [x || 0, y || 0, animated !== false]
    );
  },

  /**
   * Scrolls to the end of the ScrollView, either immediately or with a smooth
   * animation.
   *
   * Example:
   *
   * `scrollResponderScrollToEnd({animated: true})`
   */
  scrollResponderScrollToEnd: function(options?: { animated?: boolean }) {
    // Default to true
    const animated = (options && options.animated) !== false;
    UIManager.dispatchViewManagerCommand(
      this.scrollResponderGetScrollableNode(),
      UIManager.RCTScrollView.Commands.scrollToEnd,
      [animated]
    );
  },

  /**
   * A helper function to zoom to a specific rect in the scrollview. The argument has the shape
   * {x: number; y: number; width: number; height: number; animated: boolean = true}
   */
  scrollResponderZoomTo: function(
    rect: {| x: number, y: number, width: number, height: number, animated?: boolean |},
    animated?: boolean // deprecated, put this inside the rect argument instead
  ) {},

  /**
   * The calculations performed here assume the scroll view takes up the entire
   * screen - even if has some content inset. We then measure the offsets of the
   * keyboard, and compensate both for the scroll view's "contentInset".
   *
   * @param {number} left Position of input w.r.t. table view.
   * @param {number} top Position of input w.r.t. table view.
   * @param {number} width Width of the text input.
   * @param {number} height Height of the text input.
   */
  scrollResponderInputMeasureAndScrollToKeyboard: function(left: number, top: number, width: number, height: number) {
    let keyboardScreenY = Dimensions.get('window').height;
    if (this.keyboardWillOpenTo) {
      keyboardScreenY = this.keyboardWillOpenTo.endCoordinates.screenY;
    }
    let scrollOffsetY = top - keyboardScreenY + height + this.additionalScrollOffset;

    // By default, this can scroll with negative offset, pulling the content
    // down so that the target component's bottom meets the keyboard's top.
    // If requested otherwise, cap the offset at 0 minimum to avoid content
    // shifting down.
    if (this.preventNegativeScrollOffset) {
      scrollOffsetY = Math.max(0, scrollOffsetY);
    }
    this.scrollResponderScrollTo({ x: 0, y: scrollOffsetY, animated: true });

    this.additionalOffset = 0;
    this.preventNegativeScrollOffset = false;
  },

  scrollResponderTextInputFocusError: function(e: Event) {
    console.error('Error measuring text field: ', e);
  },

  /**
   * `componentWillMount` is the closest thing to a  standard "constructor" for
   * React components.
   *
   * The `keyboardWillShow` is called before input focus.
   */
  componentWillMount: function() {
    const {keyboardShouldPersistTaps} = this.props;
    warning(
      typeof keyboardShouldPersistTaps !== 'boolean',
      `'keyboardShouldPersistTaps={${keyboardShouldPersistTaps}}' is deprecated. `
      + `Use 'keyboardShouldPersistTaps="${keyboardShouldPersistTaps ? 'always' : 'never'}"' instead`
    );

    this.keyboardWillOpenTo = null;
    this.additionalScrollOffset = 0;
  },

  //
  // Unsupported in macOS
  //
  scrollResponderFlashScrollIndicators: function() {},
  scrollResponderScrollNativeHandleToKeyboard: function(
    nodeHandle: any,
    additionalOffset?: number,
    preventNegativeScrollOffset?: boolean
  ) {},
  scrollResponderKeyboardWillShow: function(e: Event) {},
  scrollResponderKeyboardWillHide: function(e: Event) {},
  scrollResponderKeyboardDidShow: function(e: Event) {},
  scrollResponderKeyboardDidHide: function(e: Event) {},
};

const ScrollResponder = {
  Mixin: ScrollResponderMixin,
};

module.exports = ScrollResponder;
