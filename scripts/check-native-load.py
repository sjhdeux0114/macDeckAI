#!/usr/bin/env python3
import ctypes
from pathlib import Path

binary = Path(__file__).resolve().parent.parent / "upstream/DroidDeck/app/src/main/jniLibs/arm64-v8a/libwayland-server.so"
try:
    ctypes.CDLL(str(binary))
except OSError as error:
    if "not valid mach-o" not in str(error):
        raise
    print("EXPECTED FAILURE: Android ELF cannot be loaded directly by macOS dyld")
    print(error)
else:
    raise SystemExit("Unexpected load success")
