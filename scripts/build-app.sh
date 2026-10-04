#!/bin/zsh
# Bygger Tala.app och installerar den i /Applications.
set -e
cd "$(dirname "$0")/.."
swift build -c release

APP=".build/Tala.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Tala "$APP/Contents/MacOS/Tala"

# Ikon
if [[ ! -f .build/Tala.icns ]]; then
  swift scripts/icon.swift .build/icon.png
  mkdir -p .build/Tala.iconset
  for s in 16 32 128 256 512; do
    sips -z $s $s .build/icon.png --out .build/Tala.iconset/icon_${s}x${s}.png >/dev/null
    sips -z $((s*2)) $((s*2)) .build/icon.png --out .build/Tala.iconset/icon_${s}x${s}@2x.png >/dev/null
  done
  iconutil -c icns .build/Tala.iconset -o .build/Tala.icns
fi
cp .build/Tala.icns "$APP/Contents/Resources/Tala.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Tala</string>
  <key>CFBundleDisplayName</key><string>Tala</string>
  <key>CFBundleIdentifier</key><string>se.growingsmart.tala</string>
  <key>CFBundleExecutable</key><string>Tala</string>
  <key>CFBundleIconFile</key><string>Tala</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleDevelopmentRegion</key><string>sv</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>Tala lyssnar bara medan du håller in höger ⌥. Ljudet lämnar aldrig din Mac.</string>
</dict></plist>
PLIST

xattr -cr "$APP"
codesign --force --deep --sign - --identifier se.growingsmart.tala "$APP"
pkill -x Tala 2>/dev/null || true
rm -rf /Applications/Tala.app
ditto "$APP" /Applications/Tala.app
echo "Installerad: /Applications/Tala.app"
