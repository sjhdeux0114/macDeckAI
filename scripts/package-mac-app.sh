#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/prepare-metal-runtime.py
bash scripts/build-mac-app.sh
dist/MacDeck.app/Contents/MacOS/MacDeck --self-test
codesign --verify --strict dist/MacDeck.app
