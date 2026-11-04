#!/bin/bash
#
# Releases Miqat on every platform at the version in project.yml.
#
# The Mac app becomes a signed and notarized DMG, added to the appcast. Both land in
# releases/ and are then uploaded to the updates bucket in Cloudflare R2.
#
# The iPhone app, with the Watch app inside it, is archived and uploaded to App Store
# Connect for TestFlight, using the Apple account signed in to Xcode.

set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT=Miqat.xcodeproj
SCHEME=Miqat-macOS
TARGET=Miqat-macOS
IOS_SCHEME=Miqat-iOS
NOTARY_PROFILE=notary
BUCKET=apps
DERIVED_DATA=build
WORK=build/release
RELEASES=releases
GENERATE_APPCAST=$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast

fail() {
    echo "error: $1" >&2
    exit 1
}

setting() {
    printf '%s\n' "$SETTINGS" | awk -v key="$1" '$1 == key && $2 == "=" { print $3; exit }'
}

upload() {
    npx --yes wrangler r2 object put "$BUCKET/miqat/$2" --file "$1" --remote "${@:3}"
}

[ -f Config/Release.xcconfig ] || fail "Config/Release.xcconfig is missing. Copy the example and fill it in."

IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -n 1)
[ -n "$IDENTITY" ] || fail "No Developer ID Application certificate. Create one under Xcode > Settings > Accounts > Manage Certificates."

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || fail "No working notarytool login. Run: xcrun notarytool store-credentials $NOTARY_PROFILE"

CLOUDFLARE_ACCOUNT=$(npx --yes wrangler whoami 2>&1 || true)
[[ $CLOUDFLARE_ACCOUNT == *"You are logged in"* ]] || fail "Wrangler is not logged in to Cloudflare. Run: npx wrangler login"

xcodegen generate

SETTINGS=$(xcodebuild -project "$PROJECT" -target "$TARGET" -configuration Release -showBuildSettings 2>/dev/null)
VERSION=$(setting MARKETING_VERSION)
BUILD=$(setting CURRENT_PROJECT_VERSION)
TEAM=$(setting DEVELOPMENT_TEAM)
UPDATES_HOST=$(setting MIQAT_UPDATES_HOST)

[ -n "$VERSION" ] && [ -n "$BUILD" ] || fail "Could not read the version and build number from the project."
[ -n "$TEAM" ] || fail "DEVELOPMENT_TEAM is not set in Config/Release.xcconfig."
[ -n "$UPDATES_HOST" ] || fail "MIQAT_UPDATES_HOST is not set in Config/Release.xcconfig."

mkdir -p "$RELEASES"

if [ -f "$RELEASES/appcast.xml" ]; then
    LATEST_BUILD=$(sed -n 's/.*<sparkle:version>\([0-9]*\)<.*/\1/p' "$RELEASES/appcast.xml" | sort -n | tail -n 1)
    if [ -n "$LATEST_BUILD" ] && [ "$BUILD" -le "$LATEST_BUILD" ]; then
        fail "Build $BUILD is not newer than released build $LATEST_BUILD. Raise CURRENT_PROJECT_VERSION in project.yml."
    fi
fi

rm -rf "$WORK"
mkdir -p "$WORK"

ARCHIVE=$WORK/Miqat.xcarchive
IOS_ARCHIVE=$WORK/Miqat-iOS.xcarchive
EXPORT=$WORK/export
STAGE=$WORK/stage
APP=$EXPORT/Miqat.app
DMG=$RELEASES/Miqat-$VERSION.dmg

echo "Archiving Miqat $VERSION ($BUILD)"
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    -archivePath "$ARCHIVE" \
    > "$WORK/archive.log" 2>&1 \
    || fail "Archiving failed. See $WORK/archive.log"

cat > "$WORK/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>$TEAM</string>
</dict>
</plist>
EOF

echo "Exporting with Developer ID"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT" \
    -exportOptionsPlist "$WORK/ExportOptions.plist" \
    > "$WORK/export.log" 2>&1 \
    || fail "Exporting failed. See $WORK/export.log"

codesign --verify --deep --strict "$APP"

echo "Building the DMG"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Miqat.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -ov -volname Miqat -srcfolder "$STAGE" -format UDZO "$DMG"
codesign --sign "$IDENTITY" --timestamp "$DMG"

echo "Notarizing, which usually takes a few minutes"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature "$DMG"

echo "Archiving the iPhone and Watch apps"
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$IOS_SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED_DATA" \
    -archivePath "$IOS_ARCHIVE" \
    -allowProvisioningUpdates \
    > "$WORK/archive-ios.log" 2>&1 \
    || fail "Archiving the iPhone app failed. See $WORK/archive-ios.log"

cat > "$WORK/TestFlightOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>upload</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>$TEAM</string>
</dict>
</plist>
EOF

echo "Uploading the iPhone and Watch apps to App Store Connect"
xcodebuild -exportArchive \
    -archivePath "$IOS_ARCHIVE" \
    -exportPath "$WORK/export-ios" \
    -exportOptionsPlist "$WORK/TestFlightOptions.plist" \
    -allowProvisioningUpdates \
    > "$WORK/upload-ios.log" 2>&1 \
    || fail "Uploading the iPhone app failed. See $WORK/upload-ios.log"

echo "Updating the appcast"
"$GENERATE_APPCAST" --download-url-prefix "https://$UPDATES_HOST/miqat/" "$RELEASES"

echo "Uploading to the $BUCKET bucket"
upload "$DMG" "$(basename "$DMG")"
upload "$DMG" Miqat.dmg --cache-control no-cache
upload "$RELEASES/appcast.xml" appcast.xml

echo "Released Miqat $VERSION ($BUILD) to https://$UPDATES_HOST/miqat/ and to App Store Connect"
