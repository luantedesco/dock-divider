#!/bin/sh
# Packages build/Dock Divider.app into build/DockDivider.dmg: the app and a shortcut to
# /Applications, for drag-and-drop install. Run ./build.sh first. The name has no version so the
# releases/latest/download/DockDivider.dmg link always points to the latest release.
set -e
cd "$(dirname "$0")/.."
APP=build/"Dock Divider.app"
DMG=build/DockDivider.dmg
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Dock Divider.app"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "Dock Divider" -srcfolder "$STAGING" -fs HFS+ -format UDZO -quiet "$DMG"
echo "OK: $DMG"
