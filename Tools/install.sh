#!/bin/sh
# Instala a última release do Dock Divider em /Applications e abre o app.
# Uso: curl -fsSL https://raw.githubusercontent.com/luantedesco/dock-divider/main/Tools/install.sh | sh
# O curl não marca o download com quarentena, então o Gatekeeper não bloqueia o app sem notarização.
set -e
APP="/Applications/Dock Divider.app"
URL=$(curl -fsSL https://api.github.com/repos/luantedesco/dock-divider/releases/latest \
  | grep -o '"browser_download_url": *"[^"]*\.dmg"' | cut -d '"' -f 4)
[ -n "$URL" ] || { echo "No .dmg found in the latest release." >&2; exit 1; }
TMP=$(mktemp -d)
trap 'hdiutil detach "$TMP/mnt" -quiet 2>/dev/null || true; rm -rf "$TMP"' EXIT
echo "Downloading $URL"
curl -fsSL "$URL" -o "$TMP/DockDivider.dmg"
hdiutil attach -nobrowse -readonly -quiet -mountpoint "$TMP/mnt" "$TMP/DockDivider.dmg"
pkill -x DockDivider 2>/dev/null || true
rm -rf "$APP"
ditto "$TMP/mnt/Dock Divider.app" "$APP"
open "$APP"
echo "Installed: $APP"
