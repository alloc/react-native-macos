# @alloc/react-native-macos

Fork of `react-native` for macOS.

## Install

```sh
npm install @alloc/react-native-macos
```

## Roadmap

- [x] Upgrade `<Text>` and `<TextInput>` to RN 0.54 (#227)
- [x] Add `RCTWindow` for improved input handling (#228)
- [x] Add support for React hooks (#225)
- [x] Create a library for native SVG support (#229)
- [x] Support `onMouseEnter` and `onMouseLeave` events (#231)
- [x] Reimplement the native `hitSlop` prop (6e9db010fbcd1a2901e3c91fb76d8f95dd871747)
- [x] Create a library for playing sounds ([repo](https://github.com/alloc/react-native-sound))
- [x] Support `pointerEvents` prop (https://github.com/aleclarson/react-native-macos/commit/b48d8cb2544b08c739cd7263f673cbff06149eee)
- [x] Add `<WindowDrag>` component (https://github.com/aleclarson/react-native-macos/commit/3baecb6ac05)
- [x] Add `<Gradient>` component (https://github.com/aleclarson/react-native-macos/commit/1f828676faf872421b037c598cada0371a62db02)
- [x] Add `cursor` prop to `<View>` (https://github.com/aleclarson/react-native-macos/commit/d679a7cfe47dbae3c69ed5070b679dc3ccd3eb1c)
- [x] Fork `@react-native-community/art` and make it work on macOS (https://github.com/aleclarson/react-native-art)
- [x] Support moving a `RCTWindow` to a screen with a different `backingScaleFactor` (https://github.com/aleclarson/react-native-macos/commit/e289a8d8c3e502527eb43bdfcd6c27651f7f22ae)
- [ ] Add native `Worker` class ([branch](https://github.com/aleclarson/react-native-macos/tree/worker))
- [ ] Add `<Window>` component ([API draft](https://gist.github.com/aleclarson/1eb38f8a1560a910692b624325d38767))
- [ ] Fork `@types/react-native` and maintain it here
- [ ] Recompute the mouse target when its current target's frame changes (relative to window)
- [ ] Add `preferFocus` prop to `<TextInput>` that prevents blur when clicking outside the input view
- [ ] Add `<Menu>` component ([API draft](https://gist.github.com/aleclarson/219105fc77658e1da620a17b2e05b1de))
- [ ] Add `inert` prop for disabling focus and user interaction (see [here](https://html.spec.whatwg.org/multipage/interaction.html#inert))
- [ ] Add `<HotKey>` component ([API draft](https://gist.github.com/aleclarson/6c609884fc08c20492c8722eed17acc1))

### Bugs
- [x] Fix `zIndex` prop being ignored (ab257a13b397f983fb865058a5b6435559c1f683)
- [x] Respect `layer.transform` inside `hitTest` (1f1389653b7bdf3d4494f361a1d591fca7332f94)
- [x] Various RCTView fixes (#234)
- [x] In some cases, shadows won't render unless `backgroundColor` comes after the shadow props
- [x] Fix the "change" event of `AppState` (https://github.com/aleclarson/react-native-macos/commit/77566a3b78431e5f3712722044022234ceedc44c)
- [x] Hit testing in `RCTNativeScrollView` (https://github.com/aleclarson/react-native-macos/commit/80ae3f304328ff00356ab7f0a251325e666b38b5)
- [x] Scrollbars should be visible by default (https://github.com/aleclarson/react-native-macos/commit/12721449c00649de251c24391db9cd839db2bce8)
- [ ] Shadows won't render when `shadowOpacity` is undefined
- [ ] Keep cursor an `I`-bar between mouseDown and mouseUp in a `<TextInput>`
- [ ] The element inspector (`cmd+i`) doesn't work
