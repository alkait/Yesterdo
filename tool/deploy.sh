#!/bin/zsh
# Builds an ad hoc IPA and hands it to Diawi. Prints the install link.
#
# The token is DIAWI_TOKEN, read from .env, which git ignores.
# Pass --upload-only to send the IPA already in build/ without rebuilding.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  source ./.env
  set +a
fi

if [[ -z "${DIAWI_TOKEN:-}" ]]; then
  echo "DIAWI_TOKEN is not set. Put it in .env." >&2
  exit 1
fi

if [[ "${1:-}" != "--upload-only" ]]; then
  fvm flutter build ipa --release \
    --export-options-plist=ios/ExportOptions.plist
fi

ipa=(build/ios/ipa/*.ipa(N))
if (( ${#ipa} != 1 )); then
  echo "Expected one IPA in build/ios/ipa, found ${#ipa}." >&2
  exit 1
fi

field() {
  /usr/bin/python3 -c \
    'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "$1"
}

sent=$(curl --fail --silent --show-error https://upload.diawi.com/ \
  -F "token=$DIAWI_TOKEN" \
  -F "file=@${ipa[1]}")
job=$(field job <<<"$sent")
if [[ -z "$job" ]]; then
  echo "Diawi did not take the upload: $sent" >&2
  exit 1
fi

# 2001 is still processing, 2000 is ready, anything else is a refusal.
for _ in {1..60}; do
  sleep 2
  answer=$(curl --fail --silent --show-error --get \
    https://upload.diawi.com/status \
    --data-urlencode "token=$DIAWI_TOKEN" \
    --data-urlencode "job=$job")
  case $(field status <<<"$answer") in
    2000) field link <<<"$answer"; exit 0 ;;
    2001) ;;
    *) echo "Diawi refused the build: $answer" >&2; exit 1 ;;
  esac
done

echo "Diawi was still processing after two minutes." >&2
exit 1
