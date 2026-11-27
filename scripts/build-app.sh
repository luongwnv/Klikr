#!/usr/bin/env bash
# Builds build/Klikr.app. Signing with a stable identity keeps macOS permissions across rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  swift build -c "$CONFIG" --arch arm64 --arch x86_64
  BIN="$(swift build -c "$CONFIG" --arch arm64 --arch x86_64 --show-bin-path)/Klikr"
else
  swift build -c "$CONFIG"
  BIN="$(swift build -c "$CONFIG" --show-bin-path)/Klikr"
fi

APP=build/Klikr.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Klikr"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp -R layouts "$APP/Contents/Resources/layouts"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Support/MenuIcon.png Support/MenuIcon@2x.png Support/MenuTemplate.png Support/MenuTemplate@2x.png "$APP/Contents/Resources/"

IDENTITY="${KLIKR_SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application|Apple Development/ {print $2; exit}')}"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$APP"
  echo "Signed with: $IDENTITY"
else
  codesign --force --sign - "$APP"
  echo "Ad-hoc signed (permissions must be re-granted after each rebuild)"
fi
echo "Built $APP"
