#!/bin/zsh
# Bygger en signerad och av Apple granskad (notariserad) Parlissima.dmg som öppnas utan varning.
#
# Engångsförberedelser (kräver Apple Developer Program):
#   1. Skapa ett "Developer ID Application"-certifikat på developer.apple.com och installera det i Nyckelringen.
#      Namnet syns med:  security find-identity -v -p codesigning
#   2. Spara inloggningen för granskning i Nyckelringen (du skriver in lösenordet själv, det sparas lokalt):
#      xcrun notarytool store-credentials parlissima-notary --apple-id <din Apple-ID-mejl> --team-id <Team ID>
#      (lösenordet är ett appspecifikt lösenord från appleid.apple.com)
#
# Sedan, varje gång:
#   PARLISSIMA_SIGN_IDENTITY="Developer ID Application: GrowingSmart Strandberg Management AB (TEAMID)" \
#   PARLISSIMA_NOTARY_PROFILE=parlissima-notary  scripts/release.sh
set -e
cd "$(dirname "$0")/.."
: "${PARLISSIMA_SIGN_IDENTITY:?Ange PARLISSIMA_SIGN_IDENTITY (se instruktionen överst i filen)}"
: "${PARLISSIMA_NOTARY_PROFILE:=parlissima-notary}"

scripts/build-app.sh --zip
scripts/make-dmg.sh .build/Parlissima.app

echo "Skickar till Apple för granskning (tar oftast några minuter) …"
xcrun notarytool submit .build/Parlissima.dmg --keychain-profile "$PARLISSIMA_NOTARY_PROFILE" --wait
xcrun stapler staple .build/Parlissima.dmg
spctl --assess --type open --context context:primary-signature -v .build/Parlissima.dmg

cp .build/Parlissima.dmg download/Parlissima.dmg
echo "Klar: download/Parlissima.dmg är signerad och granskad. Committa och pusha för att publicera."
