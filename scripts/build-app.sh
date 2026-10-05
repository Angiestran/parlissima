#!/bin/zsh
# Bygger Parlissima.app och installerar den i /Applications.
#   scripts/build-app.sh            bygg och installera
#   scripts/build-app.sh --zip      bygg och packa som .build/Parlissima.zip för nedladdning (installerar inte)
set -e
MODE="${1:-install}"
cd "$(dirname "$0")/.."
swift build -c release

APP=".build/Parlissima.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Parlissima "$APP/Contents/MacOS/Parlissima"

# Ikon
if [[ ! -f .build/Parlissima.icns ]]; then
  .build/release/Parlissima --icon .build/icon.png
  mkdir -p .build/Parlissima.iconset
  for s in 16 32 128 256 512; do
    sips -z $s $s .build/icon.png --out .build/Parlissima.iconset/icon_${s}x${s}.png >/dev/null
    sips -z $((s*2)) $((s*2)) .build/icon.png --out .build/Parlissima.iconset/icon_${s}x${s}@2x.png >/dev/null
  done
  iconutil -c icns .build/Parlissima.iconset -o .build/Parlissima.icns
fi
cp .build/Parlissima.icns "$APP/Contents/Resources/Parlissima.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Parlissima</string>
  <key>CFBundleDisplayName</key><string>Parlissima</string>
  <key>CFBundleIdentifier</key><string>se.growingsmart.parlissima</string>
  <key>CFBundleExecutable</key><string>Parlissima</string>
  <key>CFBundleIconFile</key><string>Parlissima</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleDevelopmentRegion</key><string>sv</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>Parlissima lyssnar bara när du startar en diktering. Ljudet lämnar aldrig din Mac.</string>
</dict></plist>
PLIST

xattr -cr "$APP"
if [[ -n "$PARLISSIMA_SIGN_IDENTITY" ]]; then
  # Developer ID: hardened runtime + tidsstämpel krävs för Apples granskning (notarisering)
  codesign --force --options runtime --timestamp --entitlements scripts/Parlissima.entitlements \
    --identifier se.growingsmart.parlissima --sign "$PARLISSIMA_SIGN_IDENTITY" "$APP"
else
  codesign --force --deep --sign - --identifier se.growingsmart.parlissima "$APP"   # ad hoc, för egen dator
fi

if [[ "$MODE" == "--zip" ]]; then
  rm -f .build/Parlissima.zip
  ditto -c -k --keepParent "$APP" .build/Parlissima.zip
  echo "Packad: .build/Parlissima.zip"
  exit 0
fi

pkill -x Parlissima 2>/dev/null || true
rm -rf /Applications/Parlissima.app
ditto "$APP" /Applications/Parlissima.app
echo "Installerad: /Applications/Parlissima.app"
