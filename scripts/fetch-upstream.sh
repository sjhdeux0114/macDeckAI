#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
pin=64d78aa812305d707700e2ad460f3b94d03ed50c
repo=upstream/DroidDeck
if [ ! -d "$repo/.git" ]; then
  mkdir -p upstream
  git clone --depth 1 --no-checkout https://github.com/Droid-Deck/DroidDeck.git "$repo"
  git -C "$repo" fetch --depth 1 origin "$pin"
  git -C "$repo" checkout --detach "$pin"
fi
actual=$(git -C "$repo" rev-parse HEAD)
if [ "$actual" != "$pin" ]; then
  echo "Upstream differs from audit pin: $actual; expected $pin. Existing checkout preserved." >&2
  exit 1
fi
echo "Upstream pin: $actual"
