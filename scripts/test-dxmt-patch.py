#!/usr/bin/env python3
import hashlib
import importlib.util
from pathlib import Path
import sys

script = Path(__file__).with_name("patch-dxmt-identity.py")
spec = importlib.util.spec_from_file_location("dxmt_patch", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
original = Path(sys.argv[1]).read_bytes()
patched, locations = module.patch(original)
assert len(original) == len(patched)
allowed = {offset + i for offset in locations.values() for i in range(len(module.REPLACEMENT))}
assert all(i in allowed for i, (a, b) in enumerate(zip(original, patched)) if a != b)
for location in locations.values():
    assert patched[location:location + len(module.REPLACEMENT)] == module.REPLACEMENT
try:
    module.patch(patched)
except ValueError:
    pass
else:
    raise AssertionError("Changed DLL must be rejected")
print("PASS: only two pinned x64 SetRotation functions changed; other bytes intact")
print("PASS: modified or unknown input DLL is rejected")
print("Patched SHA256:", hashlib.sha256(patched).hexdigest())
