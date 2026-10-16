# Dock Divider

A tiny macOS menu bar app that turns the Dock's native spacers into thin divider lines, matching the one that separates apps from the Trash.

![Dock with dividers between groups of apps](screenshots/dock.png)

The dividers are regular Dock spacer tiles (no icon, no tooltip). Dock Divider reads where each spacer is through the Accessibility API and draws a line over it in a transparent, click-through window.

## Requirements

- macOS 14 or later
- Accessibility permission: needed to read the position of the Dock's items. The app asks for it on first launch; grant it in **System Settings → Privacy & Security → Accessibility**.

## Install

Download `DockDivider-<version>.zip` from the [latest release](https://github.com/luantedesco/dock-divider/releases/latest), unzip it, and move `Dock Divider.app` to `/Applications`.

The app is not notarized by Apple, so macOS blocks it on first launch. To open it:

- **macOS 15 or later:** try to open the app, then go to **System Settings → Privacy & Security** and click **Open Anyway**.
- **macOS 14:** right-click the app, choose **Open**, then confirm.

Or remove the quarantine flag from the terminal:

```sh
xattr -dr com.apple.quarantine "/Applications/Dock Divider.app"
```

## Build

```sh
./build.sh
```

The app is built at `build/Dock Divider.app` as a universal binary (Apple Silicon and Intel). Move it to `/Applications` and open it.

### Keeping the Accessibility permission across rebuilds

Without a signing certificate, `build.sh` signs the app ad-hoc, and macOS treats each rebuild as a new app: the Accessibility permission has to be granted again. To avoid that, create a local self-signed certificate once per machine:

```sh
./create-signing-cert.sh
```

`build.sh` picks it up automatically.

## Usage

<img src="screenshots/menu.png" alt="Menu bar menu with Add Divider and Quit" width="240">

- **Add Divider** (menu bar icon): adds a spacer at the end of the apps section of the Dock. Drag it to where you want it.
- **Remove a divider**: drag the spacer out of the Dock, as with any Dock item.

Adding a divider writes to the Dock's preferences (`defaults write com.apple.dock persistent-apps`) and restarts the Dock (`killall Dock`). The spacers stay in the Dock even if Dock Divider is not running; they just show as empty space.

## App icon

`AppIcon.icns` is generated from `icon.svg`:

```sh
swift make-icon.swift
```

## License

[MIT](LICENSE)
