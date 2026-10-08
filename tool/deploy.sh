#!/bin/zsh
# Builds an ad hoc IPA and hands it to the ios-app-hoster on the Pi, which
# serves it at https://ios-apps.alkait.xyz. Prints the install link. Then
# builds the same version for this Mac through tool/mac.sh, so the Mac is
# on the build the phones are offered.
#
# The token is HOSTER_TOKEN, read from .env, which git ignores.
# Pass --upload-only to send the IPA already in build/ without rebuilding.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  source ./.env
  set +a
fi

if [[ -z "${HOSTER_TOKEN:-}" ]]; then
  echo "HOSTER_TOKEN is not set. Put it in .env." >&2
  exit 1
fi

HOSTER_URL="${HOSTER_URL:-https://ios-apps.alkait.xyz}"

if [[ "${1:-}" != "--upload-only" ]]; then
  fvm flutter build ipa --release \
    --export-options-plist=ios/ExportOptions.plist
fi

ipa=(build/ios/ipa/*.ipa(N))
if (( ${#ipa} != 1 )); then
  echo "Expected one IPA in build/ios/ipa, found ${#ipa}." >&2
  exit 1
fi

sent=$(curl --fail --silent --show-error -X PUT "$HOSTER_URL/api/upload" \
  -H "Authorization: Bearer $HOSTER_TOKEN" \
  --data-binary "@${ipa[1]}")

link=$(/usr/bin/python3 -c \
  'import json,sys; print(json.load(sys.stdin).get("url", ""))' <<<"$sent")
if [[ -z "$link" ]]; then
  echo "No link in the reply: $sent" >&2
  exit 1
fi

echo "Install link: $link"

tool/mac.sh
