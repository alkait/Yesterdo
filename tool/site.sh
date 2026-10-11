#!/bin/zsh
# Deploys the static site in site/ to Netlify, in production. The first run
# creates the site as "yesterdo" and links it; later runs reuse the link.
set -euo pipefail

cd "$(dirname "$0")/../site"

if [[ ! -f .netlify/state.json ]]; then
  netlify sites:create --name "${SITE_NAME:-yesterdo}" --account-slug "$(netlify api listAccountsForUser | python3 -c 'import json,sys;print(json.load(sys.stdin)[0]["slug"])')"
fi

netlify deploy --prod --dir . --message "$(git rev-parse --short HEAD)"
