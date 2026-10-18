#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="${1:-resources/AppIcon-1024.png}"
if [ ! -f "$SRC" ]; then
    echo "Error: Source image $SRC not found"
    exit 1
fi

ICONSET_DIR="resources/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

echo "Generating iconset resolutions from $SRC..."
sips -z 16 16     "$SRC" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64     "$SRC" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$SRC" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$SRC" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

echo "Converting iconset to AppIcon.icns..."
iconutil -c icns "$ICONSET_DIR" -o "resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"

echo "Successfully generated resources/AppIcon.icns"
ls -lh "resources/AppIcon.icns"
