#!/bin/zsh
# Takes the App Store screenshots with no hand on the simulator: seeds a
# store through the real SqliteTodoStore (tool/screenshots/seed_test.dart),
# copies it into the app on the iPhone 17 Pro Max and iPad Pro 13-inch
# simulators, and for each shot sets the look and appearance, relaunches
# and captures. Shots land in ios/fastlane/screenshots/en-US, which
# `fastlane metadata` uploads.
set -euo pipefail

cd "$(dirname "$0")/.."

bundle=com.alkait.yesterdo
out=ios/fastlane/screenshots/en-US
seed=build/shots/remind_me.db
# prefix:text size:simulator. The iPad reads best at the largest text.
devices=(
  "iphone:standard:iPhone 17 Pro Max"
  "ipad:largest:iPad Pro 13-inch (M5)"
)

mkdir -p build/shots "$out"
# Only its own shots are replaced; any taken by hand after them stay.
rm -f "$out"/{iphone,ipad}-[1-4].png(N)

SEED_DB="$PWD/$seed" fvm flutter test tool/screenshots/seed_test.dart >/dev/null

fvm flutter build ios --debug --simulator --dart-define=APP_STORE=true >/dev/null

# look | appearance
shots=(
  "ink|light"
  "ocean|light"
  "forest|dark"
  "blossom|dark"
)

for entry in "${devices[@]}"; do
  IFS=':' read -r prefix size name <<<"$entry"
  id=$(xcrun simctl list devices available | grep -F "$name (" | grep -oE '[0-9A-F-]{36}' | head -1)
  xcrun simctl boot "$id" 2>/dev/null || true
  xcrun simctl bootstatus "$id" -b >/dev/null
  xcrun simctl install "$id" build/ios/iphonesimulator/Runner.app
  xcrun simctl status_bar "$id" override --time 9:41 --dataNetwork wifi \
    --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100

  n=0
  for shot in "${shots[@]}"; do
    IFS='|' read -r look appearance <<<"$shot"
    xcrun simctl terminate "$id" "$bundle" 2>/dev/null || true
    docs="$(xcrun simctl get_app_container "$id" "$bundle" data)/Documents"
    rm -f "$docs"/remind_me.db*
    cp "$seed" "$docs/remind_me.db"
    sqlite3 "$docs/remind_me.db" \
      "insert or replace into settings (key, value) values ('theme', '$look'), ('textSize', '$size')"
    xcrun simctl ui "$id" appearance "$appearance"
    xcrun simctl launch "$id" "$bundle" >/dev/null
    sleep 5
    n=$((n + 1))
    xcrun simctl io "$id" screenshot "$out/$prefix-$n.png" >/dev/null
    echo "$out/$prefix-$n.png"
  done
  xcrun simctl ui "$id" appearance light
done
