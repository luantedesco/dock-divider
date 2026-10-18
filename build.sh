#!/bin/sh
# Builds Dock Divider.app in build/. Signs it with the "Dock Divider Local Signing" certificate
# when it is in the Keychain, which keeps the Accessibility permission across builds; without it,
# signs ad hoc and the permission has to be granted again after every rebuild.
set -e
cd "$(dirname "$0")"
APP=build/"Dock Divider.app"
IDENTITY="Dock Divider Local Signing"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Universal binary: runs on Apple Silicon and Intel.
swift build -c release --arch arm64 --arch x86_64
cp "$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/DockDivider" "$APP/Contents/MacOS/DockDivider"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
swift Tools/make-icon.swift "$APP/Contents/Resources/AppIcon.icns"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
  codesign --force -s "$IDENTITY" "$APP"
else
  echo "Certificate \"$IDENTITY\" not found: signing ad hoc."
  codesign --force -s - "$APP"
fi
echo "OK: $APP"
