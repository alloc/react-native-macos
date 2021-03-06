/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @providesModule MessageQueue
 * @flow
 * @format
 */

'use strict';

const ErrorUtils = require('ErrorUtils');
const Systrace = require('Systrace');

const deepFreezeAndThrowOnMutationInDev = require('deepFreezeAndThrowOnMutationInDev');
const invariant = require('fbjs/lib/invariant');
const stringifySafe = require('stringifySafe');

export type SpyData = {
  type: number,
  module: ?string,
  method: string | number,
  args: any[],
};

const TO_JS = 0;
const TO_NATIVE = 1;

const MODULE_IDS = 0;
const METHOD_IDS = 1;
const PARAMS = 2;
const MIN_TIME_BETWEEN_FLUSHES_MS = 5;

// eslint-disable-next-line no-bitwise
const TRACE_TAG_REACT_APPS = 1 << 17;

const DEBUG_INFO_LIMIT = 32;

// Work around an initialization order issue
let JSTimers = null;

class MessageQueue {
  _lazyCallableModules: {[key: string]: (void) => Object};
  _queue: [number[], number[], any[], number];
  _successCallbacks: (?Function)[];
  _failureCallbacks: (?Function)[];
  _callID: number;
  _lastFlush: number;
  _eventLoopStartTime: number;

  _debugInfo: {[number]: [number, number]};
  _remoteModuleTable: {[number]: string};
  _remoteMethodTable: {[number]: string[]};

  __spy: ?(data: SpyData) => void;

  constructor() {
    this._lazyCallableModules = {};
    this._queue = [[], [], [], 0];
    this._successCallbacks = [];
    this._failureCallbacks = [];
    this._callID = 0;
    this._lastFlush = 0;
    this._eventLoopStartTime = Date.now();

    if (__DEV__) {
      this._debugInfo = {};
      this._remoteModuleTable = {};
      this._remoteMethodTable = {};
    }

    (this: any).callFunctionReturnFlushedQueue = this.callFunctionReturnFlushedQueue.bind(
      this,
    );
    (this: any).callFunctionReturnResultAndFlushedQueue = this.callFunctionReturnResultAndFlushedQueue.bind(
      this,
    );
    (this: any).flushedQueue = this.flushedQueue.bind(this);
    (this: any).invokeCallbackAndReturnFlushedQueue = this.invokeCallbackAndReturnFlushedQueue.bind(
      this,
    );
  }

  /**
   * Public APIs
   */

  static spy(spyOrToggle: boolean | ((data: SpyData) => void)) {
    if (spyOrToggle === true) {
      MessageQueue.prototype.__spy = info => {
        console.log(
          `${info.type === TO_JS ? 'N->JS' : 'JS->N'} : ` +
            `${info.module ? info.module + '.' : ''}${info.method}` +
            `(${JSON.stringify(info.args)})`,
        );
      };
    } else if (spyOrToggle === false) {
      MessageQueue.prototype.__spy = null;
    } else {
      MessageQueue.prototype.__spy = spyOrToggle;
    }
  }

  callFunctionReturnFlushedQueue(module: string, method: string, args: any[]) {
    this.__guard(() => {
      this.__callFunction(module, method, args);
    });

    return this.flushedQueue();
  }

  callFunctionReturnResultAndFlushedQueue(
    module: string,
    method: string,
    args: any[],
  ) {
    let result;
    this.__guard(() => {
      result = this.__callFunction(module, method, args);
    });

    return [result, this.flushedQueue()];
  }

  invokeCallbackAndReturnFlushedQueue(cbID: number, args: any[]) {
    this.__guard(() => {
      this.__invokeCallback(cbID, args);
    });

    return this.flushedQueue();
  }

  flushedQueue() {
    this.__guard(() => {
      this.__callImmediates();
    });

    const queue = this._queue;
    this._queue = [[], [], [], this._callID];
    return queue[0].length ? queue : null;
  }

  getEventLoopRunningTime() {
    return Date.now() - this._eventLoopStartTime;
  }

  registerCallableModule(name: string, module: Object) {
    this._lazyCallableModules[name] = () => module;
  }

  registerLazyCallableModule(name: string, factory: void => Object) {
    let module: Object;
    let getValue: ?(void) => Object = factory;
    this._lazyCallableModules[name] = () => {
      if (getValue) {
        module = getValue();
        getValue = null;
      }
      return module;
    };
  }

  getCallableModule(name: string) {
    const getValue = this._lazyCallableModules[name];
    return getValue ? getValue() : null;
  }

  enqueueNativeCall(
    moduleID: number,
    methodID: number,
    params: any[],
    onFail: ?Function,
    onSucc: ?Function,
  ) {
    if (onFail || onSucc) {
      if (__DEV__) {
        this._debugInfo[this._callID] = [moduleID, methodID];
        if (this._callID > DEBUG_INFO_LIMIT) {
          delete this._debugInfo[this._callID - DEBUG_INFO_LIMIT];
        }
      }
      // Encode callIDs into pairs of callback identifiers by shifting left and using the rightmost bit
      // to indicate fail (0) or success (1)
      // eslint-disable-next-line no-bitwise
      onFail && params.push(this._callID << 1);
      // eslint-disable-next-line no-bitwise
      onSucc && params.push((this._callID << 1) | 1);
      this._successCallbacks[this._callID] = onSucc;
      this._failureCallbacks[this._callID] = onFail;
    }

    if (__DEV__) {
      // Validate that parameters passed over the bridge are
      // folly-convertible.  As a special case, if a prop value is a
      // function it is permitted here, and special-cased in the
      // conversion.
      const seen = [];
      const path = [];
      const validate = (val, key) => {
        if (val == null) {
          return true;
        }
        if (key != null) {
          path.push(key);
        }
        let valid = true;
        let error = '';
        switch (typeof val) {
          case 'boolean':
          case 'string':
            break; // No error.
          case 'number':
            if (!isFinite(val)) {
              error = 'Cannot serialize an infinite number';
            }
            break;
          case 'bigint':
          case 'function':
          case 'symbol':
            error = 'Cannot serialize a ' + typeof val;
            break;
          case 'object':
            const seenIndex = seen.indexOf(val);
            if (seenIndex >= 0) {
              error = 'Cannot serialize the same object twice';
              break;
            }
            seen.push(val);
            valid = Array.isArray(val)
              ? val.every(validate)
              : Object.keys(val).every(k => validate(val[k], k));
            break;
        }
        if (error) {
          console.warn(
            error + '\nFound at this path: ',
            path.slice(),
            '\nin this object: ',
            params,
          );
        }
        if (key != null) {
          path.pop();
        }
        return valid && !error;
      };

      if (!validate(params)) {
        return console.warn(
          'Native method call has arguments which cannot be serialized: %O',
          params,
        );
      }

      // The params object should not be mutated after being queued
      deepFreezeAndThrowOnMutationInDev((params: any));
    }

    if (__DEV__) {
      global.nativeTraceBeginAsyncFlow &&
        global.nativeTraceBeginAsyncFlow(
          TRACE_TAG_REACT_APPS,
          'native',
          this._callID,
        );
    }

    this._callID++;
    this._queue[MODULE_IDS].push(moduleID);
    this._queue[METHOD_IDS].push(methodID);
    this._queue[PARAMS].push(params);

    const now = Date.now();
    if (
      global.nativeFlushQueueImmediate &&
      now - this._lastFlush >= MIN_TIME_BETWEEN_FLUSHES_MS
    ) {
      var queue = this._queue;
      this._queue = [[], [], [], this._callID];
      this._lastFlush = now;
      global.nativeFlushQueueImmediate(queue);
    }
    Systrace.counterEvent('pending_js_to_native_queue', this._queue[0].length);
    if (__DEV__ && this.__spy && isFinite(moduleID)) {
      this.__spy({
        type: TO_NATIVE,
        module: this._remoteModuleTable[moduleID],
        method: this._remoteMethodTable[moduleID][methodID],
        args: params,
      });
    } else if (this.__spy) {
      this.__spy({
        type: TO_NATIVE,
        module: moduleID + '',
        method: methodID,
        args: params,
      });
    }
  }

  createDebugLookup(moduleID: number, name: string, methods: string[]) {
    if (__DEV__) {
      this._remoteModuleTable[moduleID] = name;
      this._remoteMethodTable[moduleID] = methods;
    }
  }

  /**
   * Private methods
   */

  __guard(fn: () => void) {
    if (this.__shouldPauseOnThrow()) {
      fn();
    } else {
      try {
        fn();
      } catch (error) {
        ErrorUtils.reportFatalError(error);
      }
    }
  }

  // MessageQueue installs a global handler to catch all exceptions where JS users can register their own behavior
  // This handler makes all exceptions to be propagated from inside MessageQueue rather than by the VM at their origin
  // This makes stacktraces to be placed at MessageQueue rather than at where they were launched
  // The parameter DebuggerInternal.shouldPauseOnThrow is used to check before catching all exceptions and
  // can be configured by the VM or any Inspector
  __shouldPauseOnThrow() {
    return (
      // $FlowFixMe
      typeof DebuggerInternal !== 'undefined' &&
      DebuggerInternal.shouldPauseOnThrow === true // eslint-disable-line no-undef
    );
  }

  __callImmediates() {
    Systrace.beginEvent('JSTimers.callImmediates()');
    if (!JSTimers) {
      JSTimers = require('JSTimers');
    }
    JSTimers.callImmediates();
    Systrace.endEvent();
  }

  __callFunction(module: string, method: string, args: any[]): any {
    this._lastFlush = Date.now();
    this._eventLoopStartTime = this._lastFlush;
    Systrace.beginEvent(`${module}.${method}()`);
    if (this.__spy) {
      this.__spy({type: TO_JS, module, method, args});
    }
    const moduleMethods = this.getCallableModule(module);
    invariant(
      !!moduleMethods,
      'Module %s is not a registered callable module (calling %s)',
      module,
      method,
    );
    invariant(
      !!moduleMethods[method],
      'Method %s does not exist on module %s',
      method,
      module,
    );
    const result = moduleMethods[method].apply(moduleMethods, args);
    Systrace.endEvent();
    return result;
  }

  __invokeCallback(cbID: number, args: any[]) {
    this._lastFlush = Date.now();
    this._eventLoopStartTime = this._lastFlush;

    // The rightmost bit of cbID indicates fail (0) or success (1), the other bits are the callID shifted left.
    // eslint-disable-next-line no-bitwise
    const callID = cbID >>> 1;
    // eslint-disable-next-line no-bitwise
    const isSuccess = cbID & 1;
    const callback = isSuccess
      ? this._successCallbacks[callID]
      : this._failureCallbacks[callID];

    if (__DEV__) {
      const debug = this._debugInfo[callID];
      const module = debug && this._remoteModuleTable[debug[0]];
      const method = debug && this._remoteMethodTable[debug[0]][debug[1]];
      if (!callback) {
        let errorMessage = `Callback with id ${cbID}: ${module}.${method}() not found`;
        if (method) {
          errorMessage =
            `The callback ${method}() exists in module ${module}, ` +
            'but only one callback may be registered to a function in a native module.';
        }
        invariant(callback, errorMessage);
      }
      const profileName = debug
        ? '<callback for ' + module + '.' + method + '>'
        : cbID;
      if (callback && this.__spy) {
        this.__spy({type: TO_JS, module: null, method: profileName, args});
      }
      Systrace.beginEvent(
        `MessageQueue.invokeCallback(${profileName}, ${stringifySafe(args)})`,
      );
    }

    if (!callback) {
      return;
    }

    this._successCallbacks[callID] = this._failureCallbacks[callID] = null;
    callback(...args);

    if (__DEV__) {
      Systrace.endEvent();
    }
  }
}

module.exports = MessageQueue;
