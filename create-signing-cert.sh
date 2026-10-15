#!/bin/sh
# Cria no Keychain de login o certificado autoassinado que o build.sh usa para assinar o app.
# Com a identidade fixa, a permissão de Acessibilidade continua valendo depois de recompilar.
# Roda uma vez por máquina.
set -e
NAME="Dock Divider Local Signing"
if security find-certificate -c "$NAME" >/dev/null 2>&1; then
  echo "Já existe: $NAME"
  exit 0
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# LibreSSL do sistema: gera um .p12 que o security import aceita.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=$NAME" \
  -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning" \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/id.p12" -passout pass:dock
security import "$TMP/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P dock -T /usr/bin/codesign
echo "OK: $NAME"
