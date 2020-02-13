/**
 * Copyright (c) 2013-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @providesModule Touchable
 */

'use strict';

const Platform = require('Platform');
const React = require('React');
const ReactNative = require('ReactNative');
const TVEventHandler = require('TVEventHandler');
const TouchEventUtils = require('fbjs/lib/TouchEventUtils');
const UIManager = require('UIManager');
const View = require('View');

const keyMirror = require('fbjs/lib/keyMirror');
const normalizeColor = require('normalizeColor');

/**
 * `Touchable`: Taps done right.
 *
 * You hook your `ResponderEventPlugin` events into `Touchable`. `Touchable`
 * will measure time/geometry and tells you when to give feedback to the user.
 *
 * ====================== Touchable Tutorial ===============================
 * The `Touchable` mixin helps you handle the "press" interaction. It analyzes
 * the geometry of elements, and observes when another responder (scroll view
 * etc) has stolen the touch lock. It notifies your component when it should
 * give feedback to the user. (bouncing/highlighting/unhighlighting).
 *
 * - When a touch was activated (typically you highlight)
 * - When a touch was deactivated (typically you unhighlight)
 * - When a touch was "pressed" - a touch ended while still within the geometry
 *   of the element, and no other element (like scroller) has "stolen" touch
 *   lock ("responder") (Typically you bounce the element).
 *
 * A good tap interaction isn't as simple as you might think. There should be a
 * slight delay before showing a highlight when starting a touch. If a
 * subsequent touch move exceeds the boundary of the element, it should
 * unhighlight, but if that same touch is brought back within the boundary, it
 * should rehighlight again. A touch can move in and out of that boundary
 * several times, each time toggling highlighting, but a "press" is only
 * triggered if that touch ends while within the element's boundary and no
 * scroller (or anything else) has stolen the lock on touches.
 *
 * To create a new type of component that handles interaction using the
 * `Touchable` mixin, do the following:
 *
 * - Choose the rendered component who's touches should start the interactive
 *   sequence. On that rendered node, forward all `Touchable` responder
 *   handlers. You can choose any rendered node you like. Choose a node whose
 *   hit target you'd like to instigate the interaction sequence:
 *
 *   // In render function:
 *   return (
 *     <View
 *       onStartShouldSetResponder={this.touchableHandleStartShouldSetResponder}
 *       onResponderTerminationRequest={this.touchableHandleResponderTerminationRequest}
 *       onResponderGrant={this.touchableHandleResponderGrant}
 *       onResponderMove={this.touchableHandleResponderMove}
 *       onResponderRelease={this.touchableHandleResponderRelease}
 *       onResponderTerminate={this.touchableHandleResponderTerminate}>
 *       <View>
 *         Even though the hit detection/interactions are triggered by the
 *         wrapping (typically larger) node, we usually end up implementing
 *         custom logic that highlights this inner one.
 *       </View>
 *     </View>
 *   );
 *
 * - You may set up your own handlers for each of these events, so long as you
 *   also invoke the `touchable*` handlers inside of your custom handler.
 *
 * - Implement the handlers on your component class in order to provide
 *   feedback to the user. See documentation for each of these class methods
 *   that you should implement.
 *
 *   touchableHandlePress: function() {
 *      this.performBounceAnimation();  // or whatever you want to do.
 *   },
 *   touchableHandleActivePressIn: function() {
 *     this.beginHighlighting(...);  // Whatever you like to convey activation
 *   },
 *   touchableHandleActivePressOut: function() {
 *     this.endHighlighting(...);  // Whatever you like to convey deactivation
 *   },
 *
 * - There are more advanced methods you can implement (see documentation below):
 *   touchableGetHighlightDelayMS: function() {
 *     return 20;
 *   }
 *   // In practice, *always* use a predeclared constant (conserve memory).
 *   touchableGetPressRectOffset: function() {
 *     return {top: 20, left: 20, right: 20, bottom: 100};
 *   }
 */

/**
 * Touchable states.
 */
var States = keyMirror({
  NOT_RESPONDER: null,                   // Not the responder
  RESPONDER_INACTIVE_PRESS_IN: null,     // Responder, inactive, in the `PressRect`
  RESPONDER_INACTIVE_PRESS_OUT: null,    // Responder, inactive, out of `PressRect`
  RESPONDER_ACTIVE_PRESS_IN: null,       // Responder, active, in the `PressRect`
  RESPONDER_ACTIVE_PRESS_OUT: null,      // Responder, active, out of `PressRect`
  RESPONDER_ACTIVE_LONG_PRESS_IN: null,  // Responder, active, in the `PressRect`, after long press threshold
  RESPONDER_ACTIVE_LONG_PRESS_OUT: null, // Responder, active, out of `PressRect`, after long press threshold
  ERROR: null
});

/**
 * Quick lookup map for states that are considered to be "active"
 */
var IsActive = {
  RESPONDER_ACTIVE_PRESS_OUT: true,
  RESPONDER_ACTIVE_PRESS_IN: true
};

/**
 * Quick lookup for states that are considered to be "pressing" and are
 * therefore eligible to result in a "selection" if the press stops.
 */
var IsPressingIn = {
  RESPONDER_INACTIVE_PRESS_IN: true,
  RESPONDER_ACTIVE_PRESS_IN: true,
  RESPONDER_ACTIVE_LONG_PRESS_IN: true,
};

var IsLongPressingIn = {
  RESPONDER_ACTIVE_LONG_PRESS_IN: true,
};

var IsHighlight = {
  RESPONDER_ACTIVE_PRESS_IN: true,
  RESPONDER_ACTIVE_LONG_PRESS_IN: true,
};

/**
 * Inputs to the state machine.
 */
var Signals = keyMirror({
  DELAY: null,
  RESPONDER_GRANT: null,
  RESPONDER_RELEASE: null,
  RESPONDER_TERMINATED: null,
  ENTER_PRESS_RECT: null,
  LEAVE_PRESS_RECT: null,
  LONG_PRESS_DETECTED: null,
});

/**
 * Mapping from States x Signals => States
 */
var Transitions = {
  NOT_RESPONDER: {
    DELAY: States.ERROR,
    RESPONDER_GRANT: States.RESPONDER_INACTIVE_PRESS_IN,
    RESPONDER_RELEASE: States.ERROR,
    RESPONDER_TERMINATED: States.ERROR,
    ENTER_PRESS_RECT: States.ERROR,
    LEAVE_PRESS_RECT: States.ERROR,
    LONG_PRESS_DETECTED: States.ERROR,
  },
  RESPONDER_INACTIVE_PRESS_IN: {
    DELAY: States.RESPONDER_ACTIVE_PRESS_IN,
    RESPONDER_GRANT: States.ERROR,
    RESPONDER_RELEASE: States.NOT_RESPONDER,
    RESPONDER_TERMINATED: States.NOT_RESPONDER,
    ENTER_PRESS_RECT: States.RESPONDER_INACTIVE_PRESS_IN,
    LEAVE_PRESS_RECT: States.RESPONDER_INACTIVE_PRESS_OUT,
    LONG_PRESS_DETECTED: States.ERROR,
  },
  RESPONDER_INACTIVE_PRESS_OUT: {
    DELAY: States.RESPONDER_ACTIVE_PRESS_OUT,
    RESPONDER_GRANT: States.ERROR,
    RESPONDER_RELEASE: States.NOT_RESPONDER,
    RESPONDER_TERMINATED: States.NOT_RESPONDER,
    ENTER_PRESS_RECT: States.RESPONDER_INACTIVE_PRESS_IN,
    LEAVE_PRESS_RECT: States.RESPONDER_INACTIVE_PRESS_OUT,
    LONG_PRESS_DETECTED: States.ERROR,
  },
  RESPONDER_ACTIVE_PRESS_IN: {
    DELAY: States.ERROR,
    RESPONDER_GRANT: States.ERROR,
    RESPONDER_RELEASE: States.NOT_RESPONDER,
    RESPONDER_TERMINATED: States.NOT_RESPONDER,
    ENTER_PRESS_RECT: States.RESPONDER_ACTIVE_PRESS_IN,
    LEAVE_PRESS_RECT: States.RESPONDER_ACTIVE_PRESS_OUT,
    LONG_PRESS_DETECTED: States.RESPONDER_ACTIVE_LONG_PRESS_IN,
  },
  RESPONDER_ACTIVE_PRESS_OUT: {
    DELAY: States.ERROR,
    RESPONDER_GRANT: States.ERROR,
    RESPONDER_RELEASE: States.NOT_RESPONDER,
    RESPONDER_TERMINATED: States.NOT_RESPONDER,
    ENTER_PRESS_RECT: States.RESPONDER_ACTIVE_PRESS_IN,
    LEAVE_PRESS_RECT: States.RESPONDER_ACTIVE_PRESS_OUT,
    LONG_PRESS_DETECTED: States.ERROR,
  },
  RESPONDER_ACTIVE_LONG_PRESS_IN: {
    DELAY: States.ERROR,
    RESPONDER_GRANT: States.ERROR,
    RESPONDER_RELEASE: States.NOT_RESPONDER,
    RESPONDER_TERMINATED: States.NOT_RESPONDER,
    ENTER_PRESS_RECT: States.RESPONDER_ACTIVE_LONG_PRESS_IN,
    LEAVE_PRESS_RECT: States.RESPONDER_ACTIVE_LONG_PRESS_OUT,
    LONG_PRESS_DETECTED: States.RESPONDER_ACTIVE_LONG_PRESS_IN,
  },
  RESPONDER_ACTIVE_LONG_PRESS_OUT: {
    DELAY: States.ERROR,
    RESPONDER_GRANT: States.ERROR,
    RESPONDER_RELEASE: States.NOT_RESPONDER,
    RESPONDER_TERMINATED: States.NOT_RESPONDER,
    ENTER_PRESS_RECT: States.RESPONDER_ACTIVE_LONG_PRESS_IN,
    LEAVE_PRESS_RECT: States.RESPONDER_ACTIVE_LONG_PRESS_OUT,
    LONG_PRESS_DETECTED: States.ERROR,
  },
  error: {
    DELAY: States.NOT_RESPONDER,
    RESPONDER_GRANT: States.RESPONDER_INACTIVE_PRESS_IN,
    RESPONDER_RELEASE: States.NOT_RESPONDER,
    RESPONDER_TERMINATED: States.NOT_RESPONDER,
    ENTER_PRESS_RECT: States.NOT_RESPONDER,
    LEAVE_PRESS_RECT: States.NOT_RESPONDER,
    LONG_PRESS_DETECTED: States.NOT_RESPONDER,
  }
};

// ==== Typical Constants for integrating into UI components ====
// var HIT_EXPAND_PX = 20;
// var HIT_VERT_OFFSET_PX = 10;
var HIGHLIGHT_DELAY_MS = 130;

var PRESS_EXPAND_PX = 20;

var LONG_PRESS_THRESHOLD = 500;

var LONG_PRESS_DELAY_MS = LONG_PRESS_THRESHOLD - HIGHLIGHT_DELAY_MS;

var LONG_PRESS_ALLOWED_MOVEMENT = 10;

// Default amount "active" region protrudes beyond box

/**
 * By convention, methods prefixed with underscores are meant to be @private,
 * and not @protected. Mixers shouldn't access them - not even to provide them
 * as callback handlers.
 *
 *
 * ========== Geometry =========
 * `Touchable` only assumes that there exists a `HitRect` node. The `PressRect`
 * is an abstract box that is extended beyond the `HitRect`.
 *
 *  +--------------------------+
 *  |                          | - "Start" events in `HitRect` cause `HitRect`
 *  |  +--------------------+  |   to become the responder.
 *  |  |  +--------------+  |  | - `HitRect` is typically expanded around
 *  |  |  |              |  |  |   the `VisualRect`, but shifted downward.
 *  |  |  |  VisualRect  |  |  | - After pressing down, after some delay,
 *  |  |  |              |  |  |   and before letting up, the Visual React
 *  |  |  +--------------+  |  |   will become "active". This makes it eligible
 *  |  |     HitRect        |  |   for being highlighted (so long as the
 *  |  +--------------------+  |   press remains in the `PressRect`).
 *  |        PressRect     o   |
 *  +----------------------|---+
 *           Out Region    |
 *                         +-----+ This gap between the `HitRect` and
 *                                 `PressRect` allows a touch to move far away
 *                                 from the original hit rect, and remain
 *                                 highlighted, and eligible for a "Press".
 *                                 Customize this via
 *                                 `touchableGetPressRectOffset()`.
 *
 *
 *
 * ======= State Machine =======
 *
 * +-------------+ <---+ RESPONDER_RELEASE
 * |NOT_RESPONDER|
 * +-------------+ <---+ RESPONDER_TERMINATED
 *     +
 *     | RESPONDER_GRANT (HitRect)
 *     v
 * +---------------------------+  DELAY   +-------------------------+  T + DELAY     +------------------------------+
 * |RESPONDER_INACTIVE_PRESS_IN|+-------->|RESPONDER_ACTIVE_PRESS_IN| +------------> |RESPONDER_ACTIVE_LONG_PRESS_IN|
 * +---------------------------+          +-------------------------+                +------------------------------+
 *     +            ^                         +           ^                                 +           ^
 *     |LEAVE_      |ENTER_                   |LEAVE_     |ENTER_                           |LEAVE_     |ENTER_
 *     |PRESS_RECT  |PRESS_RECT               |PRESS_RECT |PRESS_RECT                       |PRESS_RECT |PRESS_RECT
 *     |            |                         |           |                                 |           |
 *     v            +                         v           +                                 v           +
 * +----------------------------+  DELAY  +--------------------------+               +-------------------------------+
 * |RESPONDER_INACTIVE_PRESS_OUT|+------->|RESPONDER_ACTIVE_PRESS_OUT|               |RESPONDER_ACTIVE_LONG_PRESS_OUT|
 * +----------------------------+         +--------------------------+               +-------------------------------+
 *
 * T + DELAY => LONG_PRESS_DELAY_MS + DELAY
 *
 * Not drawn are the side effects of each transition. The most important side
 * effect is the `touchableHandlePress` abstract method invocation that occurs
 * when a responder is released while in either of the "Press" states.
 *
 * The other important side effects are the highlight abstract method
 * invocations (internal callbacks) to be implemented by the mixer.
 *
 *
 * @lends Touchable.prototype
 */
var TouchableMixin = {
  componentDidMount: function() {
    if (!Platform.isTVOS) {
      return;
    }

    this._tvEventHandler = new TVEventHandler();
    this._tvEventHandler.enable(this, function(cmp, evt) {
      var myTag = ReactNative.findNodeHandle(cmp);
      evt.dispatchConfig = {};
      if (myTag === evt.tag) {
        if (evt.eventType === 'focus') {
          cmp.touchableHandleActivePressIn && cmp.touchableHandleActivePressIn(evt);
        } else if (evt.eventType === 'blur') {
          cmp.touchableHandleActivePressOut && cmp.touchableHandleActivePressOut(evt);
        } else if (evt.eventType === 'select') {
          cmp.touchableHandlePress && cmp.touchableHandlePress(evt);
        }
      }
    });
  },

  /**
   * Clear all timeouts on unmount
   */
  componentWillUnmount: function() {
    if (this._tvEventHandler) {
      this._tvEventHandler.disable();
      delete this._tvEventHandler;
    }
    this.touchableDelayTimeout && clearTimeout(this.touchableDelayTimeout);
    this.longPressDelayTimeout && clearTimeout(this.longPressDelayTimeout);
    this.pressOutDelayTimeout && clearTimeout(this.pressOutDelayTimeout);
  },

  // ==== Hooks to Gesture Responder system ====
  /**
   * Must return true if embedded in a native platform scroll view.
   */
  touchableHandleResponderTerminationRequest: function() {
    return !this.props.rejectResponderTermination;
  },

  /**
   * Must return true to start the process of `Touchable`.
   */
  touchableHandleStartShouldSetResponder: function(e) {
    return (
      !this.props.disabled &&
      !!TouchEventUtils.extractSingleTouch(e.nativeEvent)
    );
  },

  /**
   * Return true to cancel press on long press.
   */
  touchableLongPressCancelsPress: function () {
    return true;
  },

  /**
   * Place as callback for a DOM element's `onResponderGrant` event.
   * @param {SyntheticEvent} e Synthetic event from event system.
   *
   */
  touchableHandleResponderGrant: function(e) {
    const touch = TouchEventUtils.extractSingleTouch(e.nativeEvent);
    if (!touch) {
      return; // Responder was not granted from a touch event.
    }

    this.pressOutDelayTimeout && clearTimeout(this.pressOutDelayTimeout);
    this.pressOutDelayTimeout = null;

    e.persist();
    this.activePress = {
      state: States.NOT_RESPONDER,
      target: e.currentTarget,
      firstTouch: { pageX: touch.pageX, pageY: touch.pageY },
      lastTouch: touch,
      lastEvent: e,
    };

    this._receiveSignal(Signals.RESPONDER_GRANT, e);
    var delayMS =
      this.touchableGetHighlightDelayMS !== undefined ?
      Math.max(this.touchableGetHighlightDelayMS(), 0) : HIGHLIGHT_DELAY_MS;
    delayMS = isNaN(delayMS) ? HIGHLIGHT_DELAY_MS : delayMS;
    if (delayMS !== 0) {
      this.touchableDelayTimeout = setTimeout(
        this._handleDelay.bind(this, e),
        delayMS
      );
    } else {
      this._handleDelay(e);
    }

    var longDelayMS =
      this.touchableGetLongPressDelayMS !== undefined ?
      Math.max(this.touchableGetLongPressDelayMS(), 10) : LONG_PRESS_DELAY_MS;
    longDelayMS = isNaN(longDelayMS) ? LONG_PRESS_DELAY_MS : longDelayMS;
    this.longPressDelayTimeout = setTimeout(
      this._handleLongDelay.bind(this, e),
      longDelayMS + delayMS
    );
  },

  /**
   * Place as callback for a DOM element's `onResponderRelease` event.
   */
  touchableHandleResponderRelease: function(e) {
    if (this.activePress) {
      this._receiveSignal(Signals.RESPONDER_RELEASE, e);
    }
  },

  /**
   * Place as callback for a DOM element's `onResponderTerminate` event.
   */
  touchableHandleResponderTerminate: function(e) {
    if (this.activePress) {
      this._receiveSignal(Signals.RESPONDER_TERMINATED, e);
    }
  },

  /**
   * Place as callback for a DOM element's `onResponderMove` event.
   */
  touchableHandleResponderMove: function(e) {
    const touch = TouchEventUtils.extractSingleTouch(e.nativeEvent);
    if (touch) {
      const {activePress} = this;

      const distance = this._getDistanceBetweenPoints(
        touch.pageX,
        touch.pageY,
        activePress.firstTouch.pageX,
        activePress.firstTouch.pageY
      );
      if (distance > LONG_PRESS_ALLOWED_MOVEMENT) {
        this._cancelLongPressDelayTimeout();
      }

      const signal = this._hitTest(activePress, touch)
        ? Signals.ENTER_PRESS_RECT
        : Signals.LEAVE_PRESS_RECT;

      this._receiveSignal(signal, e);
    }
  },

  // ==== Abstract Application Callbacks ====

  /**
   * Invoked when the item should be highlighted. Mixers should implement this
   * to visually distinguish the `VisualRect` so that the user knows that
   * releasing a touch will result in a "selection" (analog to click).
   *
   * @abstract
   * touchableHandleActivePressIn: function,
   */

  /**
   * Invoked when the item is "active" (in that it is still eligible to become
   * a "select") but the touch has left the `PressRect`. Usually the mixer will
   * want to unhighlight the `VisualRect`. If the user (while pressing) moves
   * back into the `PressRect` `touchableHandleActivePressIn` will be invoked
   * again and the mixer should probably highlight the `VisualRect` again. This
   * event will not fire on an `touchEnd/mouseUp` event, only move events while
   * the user is depressing the mouse/touch.
   *
   * @abstract
   * touchableHandleActivePressOut: function
   */

  /**
   * Invoked when the item is "selected" - meaning the interaction ended by
   * letting up while the item was either in the state
   * `RESPONDER_ACTIVE_PRESS_IN` or `RESPONDER_INACTIVE_PRESS_IN`.
   *
   * @abstract
   * touchableHandlePress: function
   */

  /**
   * Invoked when the item is long pressed - meaning the interaction ended by
   * letting up while the item was in `RESPONDER_ACTIVE_LONG_PRESS_IN`. If
   * `touchableHandleLongPress` is *not* provided, `touchableHandlePress` will
   * be called as it normally is. If `touchableHandleLongPress` is provided, by
   * default any `touchableHandlePress` callback will not be invoked. To
   * override this default behavior, override `touchableLongPressCancelsPress`
   * to return false. As a result, `touchableHandlePress` will be called when
   * lifting up, even if `touchableHandleLongPress` has also been called.
   *
   * @abstract
   * touchableHandleLongPress: function
   */

  /**
   * Returns the number of millis to wait before triggering a highlight.
   *
   * @abstract
   * touchableGetHighlightDelayMS: function
   */

  /**
   * Returns the amount to extend the `HitRect` into the `PressRect`. Positive
   * numbers mean the size expands outwards.
   *
   * @abstract
   * touchableGetPressRectOffset: function
   */



  // ==== Internal Logic ====

  /**
   * Measures the `HitRect` node on activation. The Bounding rectangle is with
   * respect to viewport - not page, so adding the `pageXOffset/pageYOffset`
   * should result in points that are in the same coordinate system as an
   * event's `globalX/globalY` data values.
   *
   * - Consider caching this for the lifetime of the component, or possibly
   *   being able to share this cache between any `ScrollMap` view.
   *
   * @sideeffects
   * @private
   */
  _remeasureMetricsOnActivation: function() {
    const {activePress} = this;
    if (activePress && !activePress.isMeasuring) {
      activePress.isMeasuring = true;
      UIManager.measure(activePress.target, (left, top, width, height) => {
        const isTouching = activePress === this.activePress;

        // Ignore the interaction if measurement fails.
        if (!top && !left && !width && !height) {
          if (isTouching) {
            this.activePress = null;
          }
          return;
        }

        activePress.isMeasuring = false;
        if (!activePress.isTerminated) {
          activePress.targetTop = top;
          activePress.targetLeft = left;
          activePress.targetWidth = width;
          activePress.targetHeight = height;

          const signal = activePress.isLongPress
            ? Signals.LONG_PRESS_DETECTED
            : this._hitTest(activePress, activePress.lastTouch)
            ? isTouching
              ? Signals.ENTER_PRESS_RECT
              : Signals.RESPONDER_RELEASE
            : isTouching
            ? Signals.LEAVE_PRESS_RECT
            : null;

          if (signal) {
            if (isTouching) {
              this._receiveSignal(signal, activePress.lastEvent);
            } else {
              activePress.state = States.RESPONDER_ACTIVE_PRESS_IN;
              this._performSideEffectsForTransition(
                activePress,
                States.NOT_RESPONDER,
                signal,
                activePress.lastEvent
              );
            }
          }
        }
      });
    }
  },

  _hitTest: function(activePress, touch) {
    if (activePress.isMeasuring) {
      return true;
    }

    var pressRectOffset = this.touchableGetPressRectOffset
      ? this.touchableGetPressRectOffset()
      : {
        left: PRESS_EXPAND_PX,
        right: PRESS_EXPAND_PX,
        top: PRESS_EXPAND_PX,
        bottom: PRESS_EXPAND_PX
      };

    var pressExpandLeft = pressRectOffset.left;
    var pressExpandTop = pressRectOffset.top;
    var pressExpandRight = pressRectOffset.right;
    var pressExpandBottom = pressRectOffset.bottom;

    var hitSlop = this.touchableGetHitSlop
      ? this.touchableGetHitSlop()
      : null;

    if (hitSlop) {
      pressExpandLeft += hitSlop.left || 0;
      pressExpandTop += hitSlop.top || 0;
      pressExpandRight += hitSlop.right || 0;
      pressExpandBottom += hitSlop.bottom || 0;
    }

    const {
      targetTop,
      targetLeft,
      targetWidth,
      targetHeight
    } = activePress;

    return (
      touch.pageX > targetLeft - pressExpandLeft &&
      touch.pageY > targetTop - pressExpandTop &&
      touch.pageX < targetLeft + targetWidth + pressExpandRight &&
      touch.pageY < targetTop + targetHeight + pressExpandBottom
    );
  },

  _handleDelay: function(e) {
    this.touchableDelayTimeout = null;
    this._receiveSignal(Signals.DELAY, e);
  },

  _handleLongDelay: function(e) {
    this.longPressDelayTimeout = null;
    var curState = this.activePress.state;
    if (curState !== States.RESPONDER_ACTIVE_PRESS_IN &&
        curState !== States.RESPONDER_ACTIVE_LONG_PRESS_IN) {
      console.error('Attempted to transition from state `' + curState + '` to `' +
        States.RESPONDER_ACTIVE_LONG_PRESS_IN + '`, which is not supported. This is ' +
        'most likely due to `Touchable.longPressDelayTimeout` not being cancelled.');
    } else {
      this._receiveSignal(Signals.LONG_PRESS_DETECTED, e);
    }
  },

  /**
   * Receives a state machine signal, performs side effects of the transition
   * and stores the new state. Validates the transition as well.
   *
   * @param {Signals} signal State machine signal.
   * @throws Error if invalid state transition or unrecognized signal.
   * @sideeffects
   */
  _receiveSignal: function(signal, e) {
    const {activePress} = this;
    const curState = activePress.state;
    const nextState = Transitions[curState] && Transitions[curState][signal];
    if (!nextState) {
      throw new Error(
        'Unrecognized signal `' + signal + '` or state `' + curState +
        '` for Touchable responder `' + activePress.target + '`'
      );
    }
    if (nextState === States.ERROR) {
      throw new Error(
        'Touchable cannot transition from `' + curState + '` to `' + signal +
        '` for responder `' + activePress.target + '`'
      );
    }
    if (curState !== nextState) {
      this._performSideEffectsForTransition(activePress, nextState, signal, e);
      activePress.state = nextState;
      if (activePress.isMeasuring) {
        activePress.lastEvent = e;
        e.persist();
      }
    }
  },

  _cancelLongPressDelayTimeout: function () {
    this.longPressDelayTimeout && clearTimeout(this.longPressDelayTimeout);
    this.longPressDelayTimeout = null;
  },

  _getDistanceBetweenPoints: function (aX, aY, bX, bY) {
    var deltaX = aX - bX;
    var deltaY = aY - bY;
    return Math.sqrt(deltaX * deltaX + deltaY * deltaY);
  },

  /**
   * Will perform a transition between touchable states, and identify any
   * highlighting or unhighlighting that must be performed for this particular
   * transition.
   *
   * @param {States} curState Current Touchable state.
   * @param {States} nextState Next Touchable state.
   * @param {Signal} signal Signal that triggered the transition.
   * @param {Event} e Native event.
   * @sideeffects
   */
  _performSideEffectsForTransition: function(activePress, nextState, signal, e) {
    const curState = activePress.state;
    const isTerminated = signal === Signals.RESPONDER_TERMINATED;
    const isReleased = signal === Signals.RESPONDER_RELEASE;

    if (isTerminated || isReleased) {
      activePress.isTerminated = isTerminated;
      if (activePress === this.activePress) {
        this.activePress = null;
      }
      this._cancelLongPressDelayTimeout();
      if (this.touchableDelayTimeout) {
        clearTimeout(this.touchableDelayTimeout);
        this.touchableDelayTimeout = null;
      }
    } else {
      const isInitialTransition =
        curState === States.NOT_RESPONDER &&
        nextState === States.RESPONDER_INACTIVE_PRESS_IN;

      const isActiveTransition = !IsActive[curState] && IsActive[nextState];
      if (isInitialTransition || isActiveTransition) {
        this._remeasureMetricsOnActivation();
      }

      if (IsPressingIn[curState] && signal === Signals.LONG_PRESS_DETECTED) {
        if (activePress && activePress.isMeasuring) {
          activePress.isLongPress = true;
        } else {
          this.touchableHandleLongPress && this.touchableHandleLongPress(e);
        }
      }
    }

    if (IsHighlight[nextState] !== IsHighlight[curState]) {
      if (IsHighlight[nextState]) {
        this._startHighlight(e);
      } else {
        this._endHighlight(e);
      }
    }

    if (isReleased && IsPressingIn[curState]) {
      if (activePress && activePress.isMeasuring) {
        return;
      }
      var hasLongPressHandler = !!this.props.onLongPress;
      var pressIsLongButStillCallOnPress =
        IsLongPressingIn[curState] && (    // We *are* long pressing..
          (// But either has no long handler
          !hasLongPressHandler || !this.touchableLongPressCancelsPress()) // or we're told to ignore it.
        );

      var shouldInvokePress =  !IsLongPressingIn[curState] || pressIsLongButStillCallOnPress;
      if (shouldInvokePress && this.touchableHandlePress) {
        if (!IsHighlight[curState]) {
          // we never highlighted because of delay, but we should highlight now
          this._startHighlight(e);
          this._endHighlight(e);
        }
        this.touchableHandlePress(e);
      }
    }
  },

  _startHighlight: function(e) {
    this.touchableHandleActivePressIn && this.touchableHandleActivePressIn(e);
  },

  _endHighlight: function(e) {
    if (this.touchableHandleActivePressOut) {
      if (this.touchableGetPressOutDelayMS && this.touchableGetPressOutDelayMS()) {
        this.pressOutDelayTimeout = setTimeout(() => {
          this.touchableHandleActivePressOut(e);
        }, this.touchableGetPressOutDelayMS());
      } else {
        this.touchableHandleActivePressOut(e);
      }
    }
  },

};

var Touchable = {
  Mixin: TouchableMixin,
  TOUCH_TARGET_DEBUG: false, // Highlights all touchable targets. Toggle with Inspector.
  /**
   * Renders a debugging overlay to visualize touch target with hitSlop (might not work on Android).
   */
  renderDebugView: ({color, hitSlop}) => {
    if (!Touchable.TOUCH_TARGET_DEBUG) {
      return null;
    }
    if (!__DEV__) {
      throw Error('Touchable.TOUCH_TARGET_DEBUG should not be enabled in prod!');
    }
    const debugHitSlopStyle = {};
    hitSlop = hitSlop || {top: 0, bottom: 0, left: 0, right: 0};
    for (const key in hitSlop) {
      debugHitSlopStyle[key] = -hitSlop[key];
    }
    const hexColor = '#' + ('00000000' + normalizeColor(color).toString(16)).substr(-8);
    return (
      <View
        pointerEvents="none"
        style={{
          position: 'absolute',
          borderColor: hexColor.slice(0, -2) + '55', // More opaque
          borderWidth: 1,
          borderStyle: 'dashed',
          backgroundColor: hexColor.slice(0, -2) + '0F', // Less opaque
          ...debugHitSlopStyle
        }}
      />
    );
  }
};

module.exports = Touchable;
