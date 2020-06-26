/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @providesModule console
 * @polyfill
 * @nolint
 * @format
 */

/* eslint-disable no-shadow */

const OBJECT_COLUMN_NAME = '(index)';
const LOG_LEVELS = {
  trace: 0,
  info: 1,
  warn: 2,
  error: 3,
};
const INSPECTOR_LEVELS = [];
INSPECTOR_LEVELS[LOG_LEVELS.trace] = 'debug';
INSPECTOR_LEVELS[LOG_LEVELS.info] = 'log';
INSPECTOR_LEVELS[LOG_LEVELS.warn] = 'warning';
INSPECTOR_LEVELS[LOG_LEVELS.error] = 'error';

// Strip the inner function in getNativeLogFunction(), if in dev also
// strip method printing to originalConsole.
const INSPECTOR_FRAMES_TO_SKIP = __DEV__ ? 2 : 1;

if (global.nativeLoggingHook) {
  function getNativeLogFunction(level) {
    return function() {
      let str;
      if (arguments.length === 1 && typeof arguments[0] === 'string') {
        str = arguments[0];
      } else {
        str = global.__formatLog(...arguments);
      }

      let logLevel = level;
      if (str.slice(0, 9) === 'Warning: ' && logLevel >= LOG_LEVELS.error) {
        // React warnings use console.error so that a stack trace is shown,
        // but we don't (currently) want these to show a redbox
        // (Note: Logic duplicated in ExceptionsManager.js.)
        logLevel = LOG_LEVELS.warn;
      }
      if (global.__inspectorLog) {
        global.__inspectorLog(
          INSPECTOR_LEVELS[logLevel],
          str,
          [].slice.call(arguments),
          INSPECTOR_FRAMES_TO_SKIP,
        );
      }
      global.nativeLoggingHook(str, logLevel);
    };
  }

  function repeat(element, n) {
    return Array.apply(null, Array(n)).map(function() {
      return element;
    });
  }

  function consoleTablePolyfill(rows) {
    // convert object -> array
    if (!Array.isArray(rows)) {
      var data = rows;
      rows = [];
      for (var key in data) {
        if (data.hasOwnProperty(key)) {
          var row = data[key];
          row[OBJECT_COLUMN_NAME] = key;
          rows.push(row);
        }
      }
    }
    if (rows.length === 0) {
      global.nativeLoggingHook('', LOG_LEVELS.info);
      return;
    }

    var columns = Object.keys(rows[0]).sort();
    var stringRows = [];
    var columnWidths = [];

    // Convert each cell to a string. Also
    // figure out max cell width for each column
    columns.forEach(function(k, i) {
      columnWidths[i] = k.length;
      for (var j = 0; j < rows.length; j++) {
        var cellStr = (rows[j][k] || '?').toString();
        stringRows[j] = stringRows[j] || [];
        stringRows[j][i] = cellStr;
        columnWidths[i] = Math.max(columnWidths[i], cellStr.length);
      }
    });

    // Join all elements in the row into a single string with | separators
    // (appends extra spaces to each cell to make separators  | alligned)
    function joinRow(row, space) {
      var cells = row.map(function(cell, i) {
        var extraSpaces = repeat(' ', columnWidths[i] - cell.length).join('');
        return cell + extraSpaces;
      });
      space = space || ' ';
      return cells.join(space + '|' + space);
    }

    var separators = columnWidths.map(function(columnWidth) {
      return repeat('-', columnWidth).join('');
    });
    var separatorRow = joinRow(separators, '-');
    var header = joinRow(columns);
    var table = [header, separatorRow];

    for (var i = 0; i < rows.length; i++) {
      table.push(joinRow(stringRows[i]));
    }

    // Notice extra empty line at the beginning.
    // Native logging hook adds "RCTLog >" at the front of every
    // logged string, which would shift the header and screw up
    // the table
    global.nativeLoggingHook('\n' + table.join('\n'), LOG_LEVELS.info);
  }

  const originalConsole = global.console;
  global.console = {
    error: getNativeLogFunction(LOG_LEVELS.error),
    info: getNativeLogFunction(LOG_LEVELS.info),
    log: getNativeLogFunction(LOG_LEVELS.info),
    warn: getNativeLogFunction(LOG_LEVELS.warn),
    trace: getNativeLogFunction(LOG_LEVELS.trace),
    debug: getNativeLogFunction(LOG_LEVELS.trace),
    table: consoleTablePolyfill,
  };

  // If available, also call the original `console` method since that is
  // sometimes useful. Ex: on OS X, this will let you see rich output in
  // the Safari Web Inspector console.
  if (__DEV__ && originalConsole) {
    // Preserve the original `console` as `originalConsole`
    const descriptor = Object.getOwnPropertyDescriptor(global, 'console');
    if (descriptor) {
      Object.defineProperty(global, 'originalConsole', descriptor);
    }

    Object.keys(console).forEach(methodName => {
      const reactNativeMethod = console[methodName];
      if (originalConsole[methodName]) {
        console[methodName] = function() {
          originalConsole[methodName](...arguments);
          reactNativeMethod.apply(console, arguments);
        };
      }
    });
  }
} else if (!global.console) {
  const log = global.print || function consoleLoggingStub() {};
  global.console = {
    error: log,
    info: log,
    log: log,
    warn: log,
    trace: log,
    debug: log,
    table: log,
  };
}
