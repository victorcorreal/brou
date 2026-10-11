#!/bin/bash
# Fetches the macOS provisioning profile for cat.correal.search into
# Provisioning/Search.provisionprofile, where build.sh embeds it.
#
# Xcode does the work with the Apple account signed in to it: it registers
# the App ID, the iCloud container and this Mac if they aren't yet, and makes
# or renews the "Mac Team Provisioning Profile: cat.correal.search". The
# helper app it builds is never installed.
#
#   Provisioning/refresh.sh            only when missing or ending within 30 days
#   Provisioning/refresh.sh --forzar   always
set -euo pipefail

cd "$(dirname "$0")"
PROFILE="Search.provisionprofile"

vigente() {
  [ -f "$PROFILE" ] || return 1
  local hasta
  hasta="$(security cms -D -i "$PROFILE" 2>/dev/null | plutil -extract ExpirationDate raw -o - - 2>/dev/null)" || return 1
  local fin ahora
  fin="$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$hasta" +%s 2>/dev/null)" || return 1
  ahora="$(date -u +%s)"
  [ $((fin - ahora)) -gt $((30 * 24 * 3600)) ]
}

if [ "${1:-}" != "--forzar" ] && vigente; then
  echo "perfil vigente: $PROFILE"
  exit 0
fi

DERIVED="$(mktemp -d)"
trap 'rm -rf "${DERIVED:?}"' EXIT
[ -d SearchProvisioning.xcodeproj ] || xcodegen generate --quiet
xcodebuild -project SearchProvisioning.xcodeproj -scheme SearchProvisioning -configuration Debug \
  -derivedDataPath "$DERIVED" -allowProvisioningUpdates build -quiet
cp "$DERIVED/Build/Products/Debug/Search.app/Contents/embedded.provisionprofile" "$PROFILE"
echo "perfil nuevo: $PROFILE (hasta $(security cms -D -i "$PROFILE" | plutil -extract ExpirationDate raw -o - -))"
