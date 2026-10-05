#!/bin/zsh
# Packar Parlissima.app i en .dmg med ett installationsfönster: dra Parlissima till Appar.
#   scripts/make-dmg.sh [sökväg/till/Parlissima.app]   (standard: .build/Parlissima.app)  →  .build/Parlissima.dmg
set -e
cd "$(dirname "$0")/.."
APP="${1:-.build/Parlissima.app}"
[[ -d "$APP" ]] || { echo "Hittar inte $APP – kör scripts/build-app.sh --zip först."; exit 1; }

work=$(mktemp -d -t parlissimadmg)
trap 'hdiutil detach -quiet "$work/mnt" 2>/dev/null; rm -rf "$work"' EXIT
stage="$work/stage"
mkdir -p "$stage/.background"
ditto "$APP" "$stage/Parlissima.app"
ln -s /Applications "$stage/Appar"
swift scripts/dmg-background.swift "$stage/.background/bakgrund.png"

hdiutil create -quiet -srcfolder "$stage" -volname "Parlissima" -fs HFS+ -format UDRW -size 60m "$work/rw.dmg"
mkdir -p "$work/mnt"
hdiutil attach -quiet -nobrowse -noautoopen -mountpoint "$work/mnt" "$work/rw.dmg"

# Fönstrets utseende: ikonvy, bakgrund, ikonernas placering
osascript <<OSA
tell application "Finder"
  set d to POSIX file "$work/mnt" as alias
  open d
  set w to container window of d
  set current view of w to icon view
  set toolbar visible of w to false
  set statusbar visible of w to false
  set bounds of w to {200, 120, 860, 548}
  set o to icon view options of w
  set arrangement of o to not arranged
  set icon size of o to 112
  set text size of o to 14
  set background picture of o to file ".background:bakgrund.png" of d
  set position of item "Parlissima.app" of d to {170, 205}
  set position of item "Appar" of d to {490, 205}
  close w
  open d
  delay 1
  close container window of d
end tell
OSA
sync
hdiutil detach -quiet "$work/mnt"

rm -f .build/Parlissima.dmg
hdiutil convert -quiet "$work/rw.dmg" -format UDZO -imagekey zlib-level=9 -o .build/Parlissima.dmg
[[ -n "$PARLISSIMA_SIGN_IDENTITY" ]] && codesign --force --timestamp --sign "$PARLISSIMA_SIGN_IDENTITY" .build/Parlissima.dmg
echo "Klar: .build/Parlissima.dmg"
