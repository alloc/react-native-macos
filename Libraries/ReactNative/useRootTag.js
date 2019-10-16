/**
 * @providesModule useRootTag
 */

const React = require('react');
const AppContainer = require('AppContainer');

function useRootTag() {
  return React.useContext(AppContainer.Context).rootTag;
}

module.exports = useRootTag;
