#!/usr/bin/env python3
"""Apply the identity-rotation source fix to the pinned MIT DXMT 0.80 x64 build.

The replacement implements only SetRotation(IDENTITY). Other rotations still
return E_NOTIMPL. This is a local compatibility build, not an upstream release.
"""
import hashlib
import json
from pathlib import Path
import struct
import sys

ORIGINAL = "7ca382af0eb32d8a432f6efb14d594fefb45673663be1f7e6682254bff885c47"
PREFIX = "_ZN4dxmt17MTLD3D11SwapChainILb"
SUFFIX = "EE11SetRotationE18DXGI_MODE_ROTATION"
REPLACEMENT = bytes.fromhex("83fa01750331c0c3b801400080c3")


def patch(source: bytes):
    if hashlib.sha256(source).hexdigest() != ORIGINAL:
        raise ValueError("Refusing a DLL other than the pinned original DXMT v0.80 x64 build")
    data = bytearray(source)
    pe = struct.unpack_from("<I", data, 0x3c)[0]
    if data[pe:pe + 4] != b"PE\0\0":
        raise ValueError("Invalid PE header")
    machine, count, _, symtable, symbols, optional, _ = struct.unpack_from("<HHIIIHH", data, pe + 4)
    if machine != 0x8664:
        raise ValueError("Only x64 is supported by this patch")
    section_start = pe + 24 + optional
    sections = [struct.unpack_from("<8sIIIIIIHHI", data, section_start + i * 40) for i in range(count)]
    strings = symtable + symbols * 18
    locations = {}
    i = 0
    while i < symbols:
        offset = symtable + i * 18
        rawname = data[offset:offset + 8]
        if rawname[:4] == b"\0\0\0\0":
            namepos = strings + struct.unpack_from("<I", rawname, 4)[0]
            name = data[namepos:data.index(0, namepos)].decode()
        else:
            name = rawname.rstrip(b"\0").decode(errors="replace")
        value, section, _, _, aux = struct.unpack_from("<IhHBB", data, offset + 8)
        if name in [PREFIX + bit + SUFFIX for bit in ("0", "1")]:
            file_offset = sections[section - 1][4] + value
            if data[file_offset:file_offset + 5] != bytes.fromhex("534883ec40"):
                raise ValueError("Unexpected function prologue")
            data[file_offset:file_offset + len(REPLACEMENT)] = REPLACEMENT
            locations[name] = file_offset
        i += 1 + aux
    if len(locations) != 2:
        raise ValueError("Expected both swapchain template implementations")
    return bytes(data), locations


if __name__ == "__main__":
    source, destination = map(Path, sys.argv[1:])
    data, locations = patch(source.read_bytes())
    destination.write_bytes(data)
    print(json.dumps({"originalSHA256": ORIGINAL, "patchedSHA256": hashlib.sha256(data).hexdigest(),
                      "functions": locations, "scope": "IDENTITY returns S_OK; all other rotations E_NOTIMPL"}, indent=2))
