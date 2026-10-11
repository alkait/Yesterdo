#!/bin/zsh
# Builds the App Store IPA and uploads it to App Store Connect. The build
# is the same app with APP_STORE set, so it never asks the hoster for
# updates, and it is exported through ios/ExportOptions-AppStore.plist,
# which signs it for the store and points CloudKit at Production.
#
# Raise the version in pubspec.yaml first, as for any deploy. The upload
# signs in with an App Store Connect API key: ASC_KEY_ID and ASC_ISSUER_ID
# in .env, and the key itself at
# ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8.
# Pass --upload-only to send the IPA already in build/ without rebuilding.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  source ./.env
  set +a
fi

if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
  echo "ASC_KEY_ID and ASC_ISSUER_ID are not set. Put them in .env." >&2
  exit 1
fi

if [[ "${1:-}" != "--upload-only" ]]; then
  fvm flutter build ipa --release \
    --dart-define=APP_STORE=true \
    --export-options-plist=ios/ExportOptions-AppStore.plist
fi

ipa=(build/ios/ipa/*.ipa(N))
if (( ${#ipa} != 1 )); then
  echo "Expected one IPA in build/ios/ipa, found ${#ipa}." >&2
  exit 1
fi

xcrun altool --upload-app --type ios --file "${ipa[1]}" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
