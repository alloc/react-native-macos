/**
 * @providesModule useRootTag
 */

const React = require('react');
const RootTagContext = require('./RootTagContext');

function useRootTag() {
  return React.useContext(RootTagContext);
}

module.exports = useRootTag;
