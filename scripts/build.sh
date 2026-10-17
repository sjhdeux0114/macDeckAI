#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .cache/clang .build/release
swiftc -O -target arm64-apple-macos13.0 -module-cache-path "$PWD/.cache/clang" \
  -framework Virtualization -framework Metal Sources/MacDeckProbe/main.swift -o .build/release/macdeck-probe
codesign --force --sign - --entitlements scripts/virtualization.entitlements .build/release/macdeck-probe
