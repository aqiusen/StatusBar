![StatusBarSecondRow](assets/logo.svg)

# StatusBarSecondRow

A compact second line for crowded macOS menu bars.

StatusBarSecondRow floats below the macOS menu bar and shows running app icons in a small, draggable row. It is built with AppKit and Swift Package Manager, with no third-party runtime dependencies.

## Features

- Shows normal running apps and accessory apps that have visible windows.
- Click an icon to activate that app.
- Right-click an icon to switch, quit, or force quit the app.
- Collapse the app list into a tiny control strip, then expand it again.
- Drag the row with the handle; it stays inside the visible screen bounds.
- Remembers the last position and collapsed state.
- Toggle launch at login from the settings menu.
- Uses a native translucent macOS panel.

## Install

Download the versioned `.dmg` from [GitHub Releases](https://github.com/aqiusen/StatusBar/releases), open it, and drag `StatusBarSecondRow.app` to `Applications`.

The app in this personal-use DMG is ad-hoc signed and is not notarized. On first launch, Control-click the app and choose **Open**. If macOS still blocks it, use **System Settings > Privacy & Security > Open Anyway**. The app requires macOS 13 or later and Apple silicon.

For local builds:

```sh
swift run
```

## Package

```sh
./scripts/package.sh
```

The packaged app, zip, and drag-to-install DMG are written to `dist/`. Set `VERSION`, `BUILD_NUMBER`, or `DIST_DIR` to customize a local build.

Publishing a GitHub Release builds a versioned DMG on an Apple silicon runner and uploads it to that release. The app inside is ad-hoc signed for personal use and does not require Apple developer credentials.

## Controls

- `x`: quit StatusBarSecondRow.
- `>` / `<`: collapse or expand the app icon list.
- Gear: open settings, including launch at login.
- Handle: drag the row.
- App icon: activate app.
- Right-click app icon: open app actions.
- `Control` + `Option` + `B`: collapse or expand the row.

## macOS Notes

macOS does not provide a public API for reading or moving every third-party menu bar status item. StatusBarSecondRow uses `NSWorkspace` and the window list APIs to show apps macOS exposes as running applications.

## Brand Assets

- `assets/icon.svg`: square app icon source.
- `assets/logo.svg`: horizontal project logo.
- `packaging/AppIcon.icns`: packaged macOS app icon.

## License

MIT
