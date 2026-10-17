#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="$PWD/dist/MacDeck.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" .cache/clang
swiftc -O -parse-as-library -target arm64-apple-macos13.0 -module-cache-path "$PWD/.cache/clang" \
  -framework AppKit -framework SwiftUI -framework GameController -framework Metal Sources/MacDeck/*.swift -o "$app/Contents/MacOS/MacDeck"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>MacDeck</string>
<key>CFBundleDisplayName</key><string>MacDeck</string>
<key>CFBundleIdentifier</key><string>dev.macdeck.app</string>
<key>CFBundleExecutable</key><string>MacDeck</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.4.1</string>
<key>CFBundleVersion</key><string>5</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
printf 'Built %s\n' "$app"
