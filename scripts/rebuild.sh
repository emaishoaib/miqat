#!/bin/bash
#
# Builds Miqat in Release for the Mac, the iPhone simulator and the Watch simulator. The Mac app is
# quit and installed into /Applications, replacing the copy there, then reopened from there. The
# iPhone and Watch apps are restarted from the new builds. The simulators are the active iPhone and
# Watch pair. If either build fails, nothing running is touched.

set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT=Miqat.xcodeproj
DERIVED_DATA=build
PRODUCTS=$DERIVED_DATA/Build/Products
MAC_APP=$PRODUCTS/Release/Miqat.app
INSTALLED_APP=/Applications/Miqat.app
PHONE_APP=$PRODUCTS/Release-iphonesimulator/Miqat.app
WATCH_APP=$PRODUCTS/Release-watchsimulator/Miqat.app
MAC_PROCESS=Miqat.app/Contents/MacOS/Miqat
PHONE_BUNDLE_ID=com.mashoaib.miqat
WATCH_BUNDLE_ID=com.mashoaib.miqat.watchkitapp

fail() {
    echo "error: $1" >&2
    exit 1
}

paired_device() {
    xcrun simctl list pairs \
        | sed -n '/(active, connected)/,/Phone:/p' \
        | sed -n "s/.*$1: .*(\([0-9A-F-]*\)) (.*/\1/p"
}

build() {
    local log=$DERIVED_DATA/rebuild-$1.log
    xcodebuild build \
        -project "$PROJECT" \
        -scheme "Miqat-$1" \
        -configuration Release \
        -destination "$2" \
        -derivedDataPath "$DERIVED_DATA" \
        > "$log" 2>&1 \
        || fail "Building Miqat-$1 failed. See $log"
}

PHONE=$(paired_device Phone)
WATCH=$(paired_device Watch)
[ -n "$PHONE" ] && [ -n "$WATCH" ] || fail "No active iPhone and Watch simulator pair. Pair them in Xcode > Window > Devices and Simulators."

mkdir -p "$DERIVED_DATA"

xcodegen generate

echo "Building the Mac app"
build macOS "generic/platform=macOS"

echo "Building the iPhone and Watch apps"
build iOS "id=$PHONE"

echo "Installing the Mac app in /Applications and reopening it"
pkill -f "$MAC_PROCESS" || true
while pgrep -f "$MAC_PROCESS" > /dev/null; do sleep 0.1; done
rm -rf "$INSTALLED_APP"
ditto "$MAC_APP" "$INSTALLED_APP"
open "$INSTALLED_APP"

echo "Restarting the iPhone and Watch apps"
xcrun simctl bootstatus "$PHONE" -b > /dev/null
xcrun simctl bootstatus "$WATCH" -b > /dev/null
xcrun simctl install "$PHONE" "$PHONE_APP"
xcrun simctl install "$WATCH" "$WATCH_APP"
xcrun simctl launch --terminate-running-process "$PHONE" "$PHONE_BUNDLE_ID" > /dev/null
xcrun simctl launch --terminate-running-process "$WATCH" "$WATCH_BUNDLE_ID" > /dev/null
