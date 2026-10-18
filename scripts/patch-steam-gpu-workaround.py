#!/usr/bin/env python3
"""Reversible, exact-match removal of Wine's Steam-only software GPU flag."""
from pathlib import Path
import hashlib
import sys

runtime = Path(sys.argv[1])
restore = '--restore' in sys.argv[2:]
old = (' --no-sandbox --in-process-gpu --disable-gpu\0').encode('utf-16le')
new = (' --no-sandbox --in-process-gpu' + ' ' * len(' --disable-gpu') + '\0').encode('utf-16le')
cache = Path(__file__).resolve().parent.parent / '.cache/steam-gpu-backups'
cache.mkdir(parents=True, exist_ok=True)
for arch in ['x86_64-windows', 'i386-windows']:
    target = runtime / 'lib/wine' / arch / 'kernelbase.dll'
    original = target.read_bytes()
    backup = cache / (hashlib.sha256(str(target.resolve()).encode()).hexdigest() + '.dll')
    if restore:
        if not backup.exists():
            raise RuntimeError('No original backup for ' + str(target))
        target.write_bytes(backup.read_bytes())
        print('Restored:', arch)
    elif original.count(new) == 1:
        print('Already patched:', arch)
    elif original.count(old) == 1:
        if backup.exists() and backup.read_bytes() != original:
            raise RuntimeError('Existing backup differs; refusing overwrite')
        if not backup.exists(): backup.write_bytes(original)
        patched = original.replace(old, new)
        assert len(patched) == len(original)
        target.write_bytes(patched)
        print('Patched exact Steam-only workaround:', arch)
    else:
        raise RuntimeError('Unknown kernelbase data; refusing patch: ' + arch)
