#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.5.5"
APP="dist/MacDeck.app"
DMG_NAME="MacDeck-v${VERSION}.dmg"
DMG_PATH="dist/${DMG_NAME}"
STAGING="dist/dmg-root"

if [ ! -d "$APP" ]; then
    echo "Error: $APP does not exist. Run bash scripts/build-mac-app.sh first."
    exit 1
fi

rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"

echo "Preparing DMG staging directory with Applications symlink..."
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "Creating compressed UDZO DMG image ($DMG_PATH)..."
hdiutil create -volname "MacDeck" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"

rm -rf "$STAGING"

echo "DMG created successfully: $DMG_PATH"
ls -lh "$DMG_PATH"
