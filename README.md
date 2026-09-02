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

Download `StatusBarSecondRow.app` from a release, then open it.

For local builds:

```sh
swift run
```

## Package

```sh
./scripts/package.sh
```

The packaged app and zip are written to `dist/`.

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
