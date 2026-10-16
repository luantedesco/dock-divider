#!/bin/sh
# Empacota build/Dock Divider.app em build/DockDivider.dmg: o app e um atalho para
# /Applications, para instalar arrastando. Rodar ./build.sh antes. O nome não leva a versão para
# o link releases/latest/download/DockDivider.dmg apontar sempre para a última release.
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
