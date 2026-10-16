#!/bin/sh
# Compila o Dock Divider.app em build/. Assina com o certificado "Dock Divider Local Signing"
# quando ele existe no Keychain, o que mantém a permissão de Acessibilidade entre builds; sem ele,
# assina ad-hoc e a permissão precisa ser concedida de novo a cada recompilação.
set -e
cd "$(dirname "$0")"
APP=build/"Dock Divider.app"
IDENTITY="Dock Divider Local Signing"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Binário universal: roda em Apple Silicon e Intel.
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
  echo "Certificado \"$IDENTITY\" não encontrado: assinando ad-hoc."
  codesign --force -s - "$APP"
fi
echo "OK: $APP"
