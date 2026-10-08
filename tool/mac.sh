#!/bin/zsh
# Builds the iOS app for this Mac, as a "Designed for iPad" app on Apple
# silicon, installs it in ~/Applications and opens it. The same IPA code,
# the same Swift and the same CloudKit container as the phone: a third
# device, not a second app. Run by tool/deploy.sh after every deploy, so
# the Mac is on the same build as the phones.
#
# Flutter has no Mac destination of its own, so the Xcode build is driven
# directly. Signing is automatic; the first run registers the Mac with the
# team. macOS only opens an iPad app from inside the wrapper it puts around
# one, an outer bundle holding the iOS bundle under Wrapper with a
# WrappedBundle link, and a bare iOS bundle is refused as an incorrect
# executable format, so the wrapper is made here. It is put in
# ~/Applications, where Spotlight, Launchpad and the Dock find it and a
# `flutter clean` cannot reach it, and opened from there.
set -euo pipefail

cd "$(dirname "$0")/.."

configuration="${1:-Release}"
derived="build/mac"

# Flutter writes the xcconfig and the plugin registry the Xcode build reads.
fvm flutter build ios --config-only --"${configuration:l}" >/dev/null

xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration "$configuration" \
  -destination 'platform=macOS,arch=arm64,variant=Designed for iPad' \
  -derivedDataPath "$derived" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  build | grep -E "error:|warning: .*Runner/|\*\* BUILD" || true

app=("$derived"/Build/Products/*/Runner.app(N))
if (( ${#app} != 1 )); then
  echo "Expected one Runner.app under $derived/Build/Products, found ${#app}." >&2
  exit 1
fi

installed="$HOME/Applications/Yesterdo.app"
mkdir -p "$HOME/Applications"
# Quit the running copy, if any, so the new one can take its place.
pkill -f "Wrapper/Runner.app/Runner" 2>/dev/null || true
rm -rf "$installed"
mkdir -p "$installed/Wrapper"
cp -R "${app[1]}" "$installed/Wrapper/"
ln -s Wrapper/Runner.app "$installed/WrappedBundle"

echo "Installed $installed"
open "$installed"
