#!/bin/zsh
# Bygger en signerad och av Apple granskad (notariserad) Tala.dmg som öppnas utan varning.
#
# Engångsförberedelser (kräver Apple Developer Program):
#   1. Skapa ett "Developer ID Application"-certifikat på developer.apple.com och installera det i Nyckelringen.
#      Namnet syns med:  security find-identity -v -p codesigning
#   2. Spara inloggningen för granskning i Nyckelringen (du skriver in lösenordet själv, det sparas lokalt):
#      xcrun notarytool store-credentials tala-notary --apple-id <din Apple-ID-mejl> --team-id <Team ID>
#      (lösenordet är ett appspecifikt lösenord från appleid.apple.com)
#
# Sedan, varje gång:
#   TALA_SIGN_IDENTITY="Developer ID Application: GrowingSmart Strandberg Management AB (TEAMID)" \
#   TALA_NOTARY_PROFILE=tala-notary  scripts/release.sh
set -e
cd "$(dirname "$0")/.."
: "${TALA_SIGN_IDENTITY:?Ange TALA_SIGN_IDENTITY (se instruktionen överst i filen)}"
: "${TALA_NOTARY_PROFILE:=tala-notary}"

scripts/build-app.sh --zip
scripts/make-dmg.sh .build/Tala.app

echo "Skickar till Apple för granskning (tar oftast några minuter) …"
xcrun notarytool submit .build/Tala.dmg --keychain-profile "$TALA_NOTARY_PROFILE" --wait
xcrun stapler staple .build/Tala.dmg
spctl --assess --type open --context context:primary-signature -v .build/Tala.dmg

cp .build/Tala.dmg download/Tala.dmg
echo "Klar: download/Tala.dmg är signerad och granskad. Committa och pusha för att publicera."
