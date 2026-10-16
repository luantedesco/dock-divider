#!/bin/sh
# Empacota build/Dock Divider.app em build/DockDivider-<versão>.dmg: o app e um atalho para
# /Applications, para instalar arrastando. Rodar ./build.sh antes.
set -e
cd "$(dirname "$0")"
APP=build/"Dock Divider.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
DMG=build/DockDivider-$VERSION.dmg
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Dock Divider.app"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "Dock Divider" -srcfolder "$STAGING" -fs HFS+ -format UDZO -quiet "$DMG"
echo "OK: $DMG"
