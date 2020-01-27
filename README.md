# @alloc/react-native-macos

Fork of `react-native` for macOS.

## Install

```sh
npm install @alloc/react-native-macos
```

## Roadmap

- [x] Upgrade `<Text>` and `<TextInput>` to RN 0.54 ([#227](https://github.com/ptmt/react-native-macos/pull/227))
- [x] Add `RCTWindow` for improved input handling ([#228](https://github.com/ptmt/react-native-macos/pull/228))
- [x] Add support for React hooks ([#225](https://github.com/ptmt/react-native-macos/pull/225))
- [x] Create a library for native SVG support ([repo](https://github.com/alloc/react-native-svgkit))
- [x] Support `onMouseEnter` and `onMouseLeave` events ([#231](https://github.com/ptmt/react-native-macos/pull/231))
- [x] Reimplement the native `hitSlop` prop ([830777c4558292091a6b0e5f43161466f9526a16](https://github.com/alloc/react-native-macos/commit/830777c4558292091a6b0e5f43161466f9526a16))
- [x] Create a library for playing sounds ([repo](https://github.com/alloc/react-native-sound))
- [x] Support `pointerEvents` prop ([b48d8cb2544b08c739cd7263f673cbff06149eee](https://github.com/alloc/react-native-macos/commit/b48d8cb2544b08c739cd7263f673cbff06149eee))
- [x] Add `<WindowDrag>` component ([3baecb6ac056fb022198ae20550ace3f4c76f2a0](https://github.com/alloc/react-native-macos/commit/3baecb6ac056fb022198ae20550ace3f4c76f2a0))
- [x] Add `<Gradient>` component ([1f828676faf872421b037c598cada0371a62db02](https://github.com/alloc/react-native-macos/commit/1f828676faf872421b037c598cada0371a62db02))
- [x] Add `cursor` prop to `<View>` ([d679a7cfe47dbae3c69ed5070b679dc3ccd3eb1c](https://github.com/alloc/react-native-macos/commit/d679a7cfe47dbae3c69ed5070b679dc3ccd3eb1c))
- [x] Fork `@react-native-community/art` and make it work on macOS ([repo](https://github.com/aleclarson/react-native-art))
- [x] Support moving a `RCTWindow` to a screen with a different `backingScaleFactor` ([e289a8d8c3e502527eb43bdfcd6c27651f7f22ae](https://github.com/alloc/react-native-macos/commit/e289a8d8c3e502527eb43bdfcd6c27651f7f22ae))
- [x] Fork `@types/react-native` and maintain it here
- [x] Add `preferFocus` prop to `<TextInput>` that prevents blur when clicking outside the input view
- [x] Rework the `RCTKeyCommands` API ([26b036d1030ea9b0e8fe3d5475ed51e9263b6db9](https://github.com/alloc/react-native-macos/commit/26b036d1030ea9b0e8fe3d5475ed51e9263b6db9))
- [x] Avoid redrawing borders if nothing changed ([79918e7a50d65ac7e6bef0c60705f548d3dbac52](https://github.com/alloc/react-native-macos/commit/79918e7a50d65ac7e6bef0c60705f548d3dbac52))
- [x] Add `style.backgroundBlurRadius` to `<View>` ([6092467359f4fb025655d7b5912ba1491f8d06b5](https://github.com/alloc/react-native-macos/commit/6092467359f4fb025655d7b5912ba1491f8d06b5))
- [x] Add `AppState.windows` and new AppState events "rootViewWillAppear" and "windowDidChangeScreen" ([edcc0dc4b43e00fc784abbb85513b4fed285d28e](https://github.com/alloc/react-native-macos/commit/edcc0dc4b43e00fc784abbb85513b4fed285d28e))
- [x] Split out the `<MaskedView>` component ([4a887c16d8b5cc6de7766e681bdd2382bd3f4e15](https://github.com/alloc/react-native-macos/commit/4a887c16d8b5cc6de7766e681bdd2382bd3f4e15))
- [ ] Add native `Worker` class ([branch](https://github.com/aleclarson/react-native-macos/tree/worker))
- [ ] Add `<Window>` component ([API draft](https://gist.github.com/aleclarson/1eb38f8a1560a910692b624325d38767))
- [ ] Recompute the mouse target when its current target's frame changes (relative to window)
- [ ] Add `<Menu>` component ([API draft](https://gist.github.com/aleclarson/219105fc77658e1da620a17b2e05b1de))
- [ ] Add `inert` prop for disabling focus and user interaction (see [here](https://html.spec.whatwg.org/multipage/interaction.html#inert))
- [ ] Add `<HotKey>` component ([API draft](https://gist.github.com/aleclarson/6c609884fc08c20492c8722eed17acc1))

### Bugs

This list is incomplete. See the commit log for more.

- [x] Fix `zIndex` prop being ignored ([fe5bb43f5c31598b349becbedbaa7f4ade65d4e4](https://github.com/alloc/react-native-macos/commit/fe5bb43f5c31598b349becbedbaa7f4ade65d4e4))
- [x] Respect `layer.transform` inside `hitTest` ([0c56034ab578c5d0c493a3183ac6d1bbb156160b](https://github.com/alloc/react-native-macos/commit/0c56034ab578c5d0c493a3183ac6d1bbb156160b))
- [x] Various RCTView fixes ([#234](https://github.com/ptmt/react-native-macos/pull/234))
- [x] In some cases, shadows won't render unless `backgroundColor` comes after the shadow props
- [x] Fix the "change" event of `AppState` ([77566a3b78431e5f3712722044022234ceedc44c](https://github.com/alloc/react-native-macos/commit/77566a3b78431e5f3712722044022234ceedc44c))
- [x] Hit testing in `RCTNativeScrollView` ([80ae3f304328ff00356ab7f0a251325e666b38b5](https://github.com/alloc/react-native-macos/commit/80ae3f304328ff00356ab7f0a251325e666b38b5))
- [x] Scrollbars should be visible by default ([12721449c00649de251c24391db9cd839db2bce8](https://github.com/alloc/react-native-macos/commit/12721449c00649de251c24391db9cd839db2bce8))
- [ ] Shadows won't render when `shadowOpacity` is undefined
- [ ] Keep cursor an `I`-bar between mouseDown and mouseUp in a `<TextInput>`
- [ ] The element inspector (`cmd+i`) doesn't work
