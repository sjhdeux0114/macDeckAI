#!/usr/bin/env python3
"""Extract the gzip payload from a Linux EFI zboot header for VZ direct boot."""
from pathlib import Path
import struct
import sys
import zlib


def extract(image: bytes) -> bytes:
    if image[56:60] == b"ARMd":
        return image
    if len(image) < 32 or image[4:8] != b"zimg" or image[24:28] != b"gzip":
        raise ValueError("Expected ARM64 Image or gzip EFI zboot header")
    offset, size = struct.unpack_from("<II", image, 8)
    if offset < 32 or size < 18 or offset + size > len(image):
        raise ValueError("Invalid EFI zboot payload bounds")
    decoder = zlib.decompressobj(31)
    kernel = decoder.decompress(image[offset:offset + size]) + decoder.flush()
    if not decoder.eof or kernel[56:60] != b"ARMd":
        raise ValueError("Payload is not a complete ARM64 Linux Image")
    return kernel


if __name__ == "__main__":
    source, destination = map(Path, sys.argv[1:])
    kernel = extract(source.read_bytes())
    destination.write_bytes(kernel)
    print(f"ARM64 Image: {len(kernel)} bytes")
