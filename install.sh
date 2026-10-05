#!/bin/zsh
# Installerar Parlissima – svensk diktering med Klang Pianissimo – på din Mac.
# Bygger appen på din egen dator och lägger den i Appar (/Applications).
#
#   curl -fsSL https://raw.githubusercontent.com/angiestran/parlissima/main/install.sh | zsh

set -e
REPO="https://github.com/angiestran/parlissima.git"

say()  { print -P "%F{magenta}▸%f $1"; }
fail() { print -P "%F{red}✗%f $1"; exit 1; }

[[ "$(uname -m)" == "arm64" ]] || fail "Parlissima kräver en Mac med Apple Silicon (M1 eller senare)."
major=$(sw_vers -productVersion | cut -d. -f1)
(( major >= 14 )) || fail "Parlissima kräver macOS 14 Sonoma eller senare."

if ! xcode-select -p >/dev/null 2>&1 || ! command -v swift >/dev/null; then
  say "Apples utvecklarverktyg behövs för att bygga Parlissima. En ruta öppnas – välj Installera."
  xcode-select --install 2>/dev/null || true
  fail "Kör det här kommandot igen när installationen av utvecklarverktygen är klar."
fi

dir=$(mktemp -d -t parlissima)
trap 'rm -rf "$dir"' EXIT
say "Hämtar Parlissima …"
git clone --quiet --depth 1 "$REPO" "$dir/parlissima"
say "Bygger Parlissima – första gången tar det några minuter …"
"$dir/parlissima/scripts/build-app.sh" >/dev/null

say "Klart! Parlissima ligger i Appar. Startar …"
open /Applications/Parlissima.app
print ""
print "Följ startfönstret: hämta Klangs modell, tillåt mikrofon och slå på Parlissima under Hjälpmedel."
print "Klicka sedan på cybergumman eller håll in höger alt och prata."
