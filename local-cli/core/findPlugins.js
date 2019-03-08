/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @format
 */

'use strict';

const path = require('path');
const union = require('lodash').union;
const uniq = require('lodash').uniq;
const flatten = require('lodash').flatten;

/**
 * Filter dependencies by name pattern
 * @param  {String} dependency Name of the dependency
 * @return {Boolean}           If dependency is a rnpm plugin
 */
const isRNPMPlugin = dependency => dependency.indexOf('rnpm-plugin-') === 0;
const isReactNativePlugin = dependency =>
  dependency.indexOf('react-native-') === 0;

const readPackage = folder => {
  try {
    return require(path.join(folder, 'package.json'));
  } catch (e) {
    return null;
  }
};

const useReactNativePlugin = (config, pluginDir) => {
  const pjson = readPackage(pluginDir);
  if (pjson && pjson.rnpm) {
    const {plugin: command, platform, haste} = pjson.rnpm;
    if (command) {
      config.commands.push(path.resolve(pluginDir, command));
    }
    if (platform) {
      config.platforms.push(path.resolve(pluginDir, platform));
    }
    if (haste) {
      const {platforms, providesModuleNodeModules: providers} = haste;
      if (platforms) {
        config.haste.platforms.push(...platforms);
      }
      if (providers) {
        config.haste.providesModuleNodeModules.push(...providers);
      }
    }
  }
};

const getEmptyPluginConfig = () => ({
  commands: [],
  platforms: [],
  haste: {
    platforms: [],
    providesModuleNodeModules: [],
  },
});

const findPluginInFolder = folder => {
  const pjson = readPackage(folder);

  if (!pjson) {
    return getEmptyPluginConfig();
  }

  const deps = union(
    Object.keys(pjson.dependencies || {}),
    Object.keys(pjson.devDependencies || {}),
  );

  const config = getEmptyPluginConfig();
  deps.forEach(dep => {
    if (isRNPMPlugin(dep)) {
      config.commands.push(path.join(folder, 'node_modules', dep));
    }
    if (isReactNativePlugin(dep)) {
      useReactNativePlugin(config, path.join(folder, 'node_modules', dep));
    }
  });
  return config;
};

/**
 * Find plugins in package.json of the given folder
 * @param {String} folder Path to the folder to get the package.json from
 * @type  {Object}        Object of commands and platform plugins
 */
module.exports = function findPlugins(folders) {
  const plugins = folders.map(findPluginInFolder);
  return {
    commands: uniq(flatten(plugins.map(p => p.commands))),
    platforms: uniq(flatten(plugins.map(p => p.platforms))),
    haste: {
      platforms: uniq(flatten(plugins.map(p => p.haste.platforms))),
      providesModuleNodeModules: uniq(
        flatten(plugins.map(p => p.haste.providesModuleNodeModules)),
      ),
    },
  };
};
