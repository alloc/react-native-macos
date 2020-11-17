/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 * @flow
 * @providesModule RNTesterExampleList
 */
'use strict';

const Platform = require('Platform');
const React = require('react');
const SectionList = require('SectionList');
const StyleSheet = require('StyleSheet');
const Text = require('Text');
const TextInput = require('TextInput');
const TouchableOpacity = require('TouchableOpacity');
const RNTesterActions = require('./RNTesterActions');
const RNTesterStatePersister = require('./RNTesterStatePersister');
const View = require('View');
const RCTDeviceEventEmitter = require('RCTDeviceEventEmitter');

import type {
  RNTesterExample,
} from './RNTesterList.macos';
import type {
  PassProps,
} from './RNTesterStatePersister';
import type {
  StyleObj,
} from 'StyleSheetTypes';

type Props = {
  onNavigate: Function,
  list: {
    ComponentExamples: Array<RNTesterExample>,
    APIExamples: Array<RNTesterExample>,
  },
  persister: PassProps<*>,
  searchTextInputStyle: StyleObj,
  style?: ?StyleObj,
  exampleKey?: string,
};

class RowComponent extends React.PureComponent<{
  item: Object,
  onNavigate: Function,
  onPress?: Function,
  onShowUnderlay?: Function,
  onHideUnderlay?: Function,
}> {
  _onPress = () => {
    if (this.props.onPress) {
      this.props.onPress();
      return;
    }
    this.props.onNavigate(RNTesterActions.ExampleAction(this.props.item.key));
  };
  render() {
    const {item} = this.props;

    return (
      <TouchableOpacity {...this.props} onPress={this._onPress}>
        <View style={[styles.row, this.props.selected ? styles.selectedRow : {}]}>
          <Text style={styles.rowTitleText}>
            {item.module.title}
          </Text>
          <Text style={styles.rowDetailText}>
            {item.module.description}
          </Text>
        </View>
      </TouchableOpacity>
    );
  }
}

const renderSectionHeader = ({section}) => (
  <View style={{ backgroundColor: "transparent" }} >
    <Text style={styles.sectionHeader}>
      {section.title}
    </Text>
  </View>
);

class RNTesterExampleList extends React.Component<Props, $FlowFixMeState> {

  componentDidMount() {
    RCTDeviceEventEmitter.addListener(
      'onSearchExample',
      ({ query }) => this.props.persister.setState(() => ({filter: query}))
    );
  }
  render() {
    const filterText = this.props.persister.state.filter;
    const filterRegex = new RegExp(String(filterText), 'i');
    const filter = (example) =>
      this.props.disableSearch ||
        filterRegex.test(example.module.title) &&
        (!Platform.isTVOS || example.supportsTVOS);


    const sections = [
      {
        data: this.props.list.ComponentExamples.filter(filter),
        title: 'Components',
        key: 'c',
      },
      {
        data: this.props.list.APIExamples.filter(filter),
        title: 'APIs',
        key: 'a',
      },
    ];

    return (
      <View style={[styles.listContainer, this.props.style]}>
        {this._renderTitleRow()}
        {/* {this._renderTextInput()} */}
        <SectionList
          style={styles.list}
          sections={sections}
          renderItem={this._renderItem}
          enableEmptySections={true}
          extraData={Math.random()}
          keyboardShouldPersistTaps="handled"
          automaticallyAdjustContentInsets={false}
          keyboardDismissMode="on-drag"
          legacyImplementation={false}
          scrollsToTop={false}
          renderSectionHeader={renderSectionHeader}
        />
      </View>
    );
  }

  _renderItem = ({item, separators}) => (
    <RowComponent
      item={item}
      selected={item.key === this.props.openExample}
      onNavigate={this.props.onNavigate}
      onShowUnderlay={separators.highlight}
      onHideUnderlay={separators.unhighlight}
    />
  );

  _renderTitleRow(): ?React.Element<any> {
    if (!this.props.displayTitleRow) {
      return null;
    }
    return (
      <RowComponent
        item={{module: {
          title: 'RNTester',
          description: 'React Native Examples',
        }}}
        onNavigate={this.props.onNavigate}
        onPress={() => {
          this.props.onNavigate(RNTesterActions.ExampleList());
        }}
      />
    );
  }

  _renderTextInput(): ?React.Element<any> {
    if (this.props.disableSearch) {
      return null;
    }
    return (
      <View style={styles.searchRow}>
        <TextInput
          autoCapitalize="none"
          autoCorrect={false}
          clearButtonMode="always"
          onChangeText={text => {
            this.props.persister.setState(() => ({filter: text}));
          }}
          placeholder="Search..."
          underlineColorAndroid="transparent"
          style={[styles.searchTextInput, this.props.searchTextInputStyle]}
          testID="explorer_search"
          value={this.props.persister.state.filter}
        />
      </View>
    );
  }

  _handleRowPress(exampleKey: string): void {
    this.setState({ exampleKey });
    this.props.onNavigate(RNTesterActions.ExampleAction(exampleKey));
  }
}

const ItemSeparator = ({highlighted}) => (
  <View style={highlighted ? styles.separatorHighlighted : styles.separator} />
);

RNTesterExampleList = RNTesterStatePersister.createContainer(RNTesterExampleList, {
  cacheKeySuffix: () => 'mainList',
  getInitialState: () => ({filter: ''}),
});

const styles = StyleSheet.create({
  listContainer: {
    flex: 1,
  },
  list: {
  },
  sectionHeader: {
    marginLeft: 4,
    padding: 5,
    fontWeight: '500',
    fontSize: 11,
  },
  row: {
    justifyContent: 'center',
    paddingHorizontal: 15,
    paddingVertical: 8,
  },
  separator: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: '#bbbbbb',
    marginLeft: 15,
  },
  separatorHighlighted: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: 'rgb(217, 217, 217)',
  },
  rowTitleText: {
    fontSize: 13,
    fontWeight: '500',
  },
  rowDetailText: {
    fontSize: 11,
    color:  '#AAA', // : '#888888',
    lineHeight: 15,
  },
  searchRow: {
    backgroundColor: '#eeeeee',
    padding: 10,
  },
  searchTextInput: {
    backgroundColor: 'white',
    borderColor: '#cccccc',
    borderRadius: 3,
    borderWidth: 1,
    paddingLeft: 8,
    paddingVertical: 0,
    height: 35,
  },
  selectedRow: {
    backgroundColor: "rgba(0, 0, 0, 0.2)",
  },
});

module.exports = RNTesterExampleList;
