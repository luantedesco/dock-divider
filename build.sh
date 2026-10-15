#!/bin/sh
# Compila o Dock Divider.app em build/. Assina com o certificado do create-signing-cert.sh quando
# ele existe no Keychain; sem ele, assina ad-hoc e a permissão de Acessibilidade precisa ser
# concedida de novo a cada recompilação.
set -e
cd "$(dirname "$0")"
APP=build/"Dock Divider.app"
IDENTITY="Dock Divider Local Signing"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O main.swift -o "$APP/Contents/MacOS/DockDivider"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
  codesign --force -s "$IDENTITY" "$APP"
else
  echo "Certificado \"$IDENTITY\" não encontrado: assinando ad-hoc."
  codesign --force -s - "$APP"
fi
echo "OK: $APP"
