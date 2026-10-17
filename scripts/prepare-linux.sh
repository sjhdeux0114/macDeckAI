#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
cache="$PWD/.cache/alpine"
image=alpine-virt-3.24.2-aarch64.iso
expected=a57ba668b5f6b17a670fcf8e799d5d7fe43766ed086d6ce2927b0625bf43dbf6
mkdir -p "$cache"
if [ ! -f "$cache/$image" ]; then
  curl -fL --retry 2 --connect-timeout 15 --max-time 300 \
    "https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/aarch64/$image" -o "$cache/$image.part"
  mv "$cache/$image.part" "$cache/$image"
fi
printf '%s  %s\n' "$expected" "$cache/$image" | shasum -a 256 -c -
tar -xf "$cache/$image" -C "$cache" boot/vmlinuz-virt boot/initramfs-virt
python3 scripts/extract-kernel.py "$cache/boot/vmlinuz-virt" "$cache/Image"
stage=$(mktemp -d "$cache/init.XXXXXX")
trap 'rm -rf "$stage"' EXIT
cp scripts/macdeck-init "$stage/macdeck-init"
chmod 755 "$stage/macdeck-init"
if [ -e "$cache/probe-initramfs.gz" ]; then chmod u+w "$cache/probe-initramfs.gz"; fi
cp "$cache/boot/initramfs-virt" "$cache/probe-initramfs.gz"
chmod u+w "$cache/probe-initramfs.gz"
(cd "$stage" && printf 'macdeck-init\n' | cpio -o -H newc 2>/dev/null) | gzip -n >> "$cache/probe-initramfs.gz"
printf 'Linux artifacts ready in %s\n' "$cache"
