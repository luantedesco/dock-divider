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
for ARCH in arm64 x86_64; do
  swiftc -O -target "$ARCH-apple-macos14" Sources/main.swift -o "build/DockDivider-$ARCH"
done
lipo -create build/DockDivider-arm64 build/DockDivider-x86_64 -output "$APP/Contents/MacOS/DockDivider"
rm build/DockDivider-arm64 build/DockDivider-x86_64
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift Tools/make-icon.swift "$APP/Contents/Resources/AppIcon.icns"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
  codesign --force -s "$IDENTITY" "$APP"
else
  echo "Certificate \"$IDENTITY\" not found: signing ad hoc."
  codesign --force -s - "$APP"
fi
echo "OK: $APP"
