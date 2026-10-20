#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP="dist/MacDeck.app"

if [ ! -d "$APP" ]; then
    echo "Error: $APP does not exist. Run bash scripts/build-mac-app.sh first."
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
DMG_PATH="dist/MacDeck-v${VERSION}.dmg"
if [ -e "$DMG_PATH" ]; then
    echo "Refusing to overwrite existing DMG: $DMG_PATH"
    exit 1
fi
codesign --verify --strict "$APP"
STAGING=$(mktemp -d "$PWD/dist/dmg-root.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT

echo "Preparing DMG staging directory with Applications symlink..."
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "Creating compressed UDZO DMG image ($DMG_PATH)..."
hdiutil create -volname "MacDeck $VERSION" -srcfolder "$STAGING" -format UDZO "$DMG_PATH"

hdiutil verify "$DMG_PATH"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "DMG created successfully: $DMG_PATH"
ls -lh "$DMG_PATH"
