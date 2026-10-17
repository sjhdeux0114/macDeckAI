#!/usr/bin/env python3
"""Inventory source coupling and ELF loader dependencies without executing upstream code."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys


def elf_info(data):
    if len(data) < 20 or data[:4] != b"\x7fELF":
        return None
    bits, encoding = data[4], data[5]
    if bits not in (1, 2) or encoding not in (1, 2):
        raise ValueError("Unsupported ELF encoding")
    order = "<" if encoding == 1 else ">"
    machine = struct.unpack_from(order + "H", data, 18)[0]
    is64 = bits == 2
    header = struct.unpack_from(order + ("HHIQQQIHHHHHH" if is64 else "HHIIIIIHHHHHH"), data, 16)
    phoff, phsize, phcount = header[4], header[8], header[9]
    loads, dynamic, interpreter = [], None, None
    for i in range(phcount):
        offset = phoff + i * phsize
        entry = struct.unpack_from(order + ("IIQQQQQQ" if is64 else "IIIIIIII"), data, offset)
        kind = entry[0]
        pos, address, size = (entry[2], entry[3], entry[5]) if is64 else (entry[1], entry[2], entry[4])
        if pos + size > len(data):
            raise ValueError("ELF segment outside file")
        if kind == 1:
            loads.append((address, pos, size))
        elif kind == 2:
            dynamic = (pos, size)
        elif kind == 3:
            interpreter = data[pos:pos + size].rstrip(b"\0").decode("utf-8", "replace")
    needed, string_address = [], None
    if dynamic:
        stride = 16 if is64 else 8
        for pos in range(dynamic[0], dynamic[0] + dynamic[1], stride):
            tag, value = struct.unpack_from(order + ("qQ" if is64 else "iI"), data, pos)
            if tag == 0:
                break
            if tag == 1:
                needed.append(value)
            elif tag == 5:
                string_address = value
    dependencies = []
    if needed:
        if string_address is None:
            raise ValueError("ELF dependencies without string table")
        table = next((p + string_address - a for a, p, n in loads if a <= string_address < a + n), None)
        if table is None:
            raise ValueError("ELF string table outside load segments")
        for offset in needed:
            end = data.index(b"\0", table + offset)
            dependencies.append(data[table + offset:end].decode("utf-8", "replace"))
    return {"bits": 64 if is64 else 32, "machine": {3: "i386", 62: "x86_64", 183: "aarch64"}.get(machine, str(machine)),
            "interpreter": interpreter, "needed": dependencies}


def main():
    repo = Path(sys.argv[1] if len(sys.argv) > 1 else "upstream/DroidDeck")
    commit = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
    tracked = subprocess.check_output(["git", "-C", str(repo), "ls-files", "-z"]).decode().split("\0")
    binaries, errors, extensions = [], [], Counter()
    android_import_files = []
    for name in filter(None, tracked):
        path = repo / name
        if not path.is_file():
            continue
        extensions[path.suffix or "[no suffix]"] += 1
        data = path.read_bytes()
        if path.suffix in (".kt", ".java") and b"import android." in data:
            android_import_files.append(name)
        try:
            info = elf_info(data)
            if info:
                binaries.append({"path": name, "sha256": hashlib.sha256(data).hexdigest(), **info})
        except (ValueError, struct.error) as error:
            errors.append({"path": name, "error": str(error)})
    print(json.dumps({"repository": "https://github.com/Droid-Deck/DroidDeck", "commit": commit,
        "trackedFileCount": sum(extensions.values()), "extensions": dict(extensions.most_common()),
        "androidImportFileCount": len(android_import_files), "androidImportFiles": android_import_files,
        "elfCount": len(binaries), "elf": binaries, "parseErrors": errors,
        "scope": "Tracked files only. Runtime archives are not recursively unpacked. Import counts do not measure porting effort."}, indent=2))


if __name__ == "__main__":
    main()
