#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="$PWD/dist/MacDeck.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" .cache/clang
swiftc -O -parse-as-library -target arm64-apple-macos13.0 -module-cache-path "$PWD/.cache/clang" \
  -framework AppKit -framework SwiftUI -framework GameController -framework Metal Sources/MacDeck/*.swift -o "$app/Contents/MacOS/MacDeck"
clang -O2 -Wall -Wextra -Werror -target arm64-apple-macos13.0 scripts/graphics-log-filter.c -o "$app/Contents/MacOS/graphics-log-filter"
mingw="${LLVM_MINGW_ROOT:-$PWD/.cache/llvm-mingw/llvm-mingw-20261006-ucrt-macos-universal}"
mkdir -p "$app/Contents/Resources/DependencyTools"
"$mingw/bin/x86_64-w64-mingw32-clang++" -O2 -static -municode scripts/wine-cab-extract.cpp \
  -o "$app/Contents/Resources/DependencyTools/wine-cab-extract.exe" -lsetupapi
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>MacDeck</string>
<key>CFBundleDisplayName</key><string>MacDeck</string>
<key>CFBundleIdentifier</key><string>dev.macdeck.app</string>
<key>CFBundleExecutable</key><string>MacDeck</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.6.0</string>
<key>CFBundleVersion</key><string>15</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleIconName</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSApplicationCategoryType</key><string>public.app-category.games</string>
<key>LSSupportsGameMode</key><true/>
<key>GCSupportsGameMode</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
if [ -f "resources/AppIcon.icns" ]; then
  cp "resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
fi
codesign --force --sign - "$app"
printf 'Built %s\n' "$app"
