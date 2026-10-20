#!/usr/bin/env python3
"""Start Steam Big Picture in background if not running."""
from pathlib import Path
import os
import subprocess
import time
import sys

app_support = Path.home() / 'Library/Application Support/MacDeck'
runtime = app_support / 'SharedSteamRenderer/Runtime'
wine = runtime / 'bin/wine'
prefix = app_support / 'Bottles/Steam'
steam_exe = prefix / 'drive_c/Program Files (x86)/Steam/steam.exe'

# Check if steam.exe is already running
res = subprocess.run(['ps', '-axo', 'comm='], capture_output=True, text=True)
if any(line.strip().lower().endswith('steam.exe') for line in res.stdout.splitlines()):
    print("Steam is already running.")
    sys.exit(0)

env = os.environ.copy()
env.update(
    WINEPREFIX=str(prefix),
    WINEDEBUG='-all',
    WINEMSYNC='1',
    WINEESYNC='0',
    WINE_LARGE_ADDRESS_AWARE='1',
    DYLD_FALLBACK_LIBRARY_PATH=str(runtime / 'lib')
)

args = [str(wine), str(steam_exe), '-gamepadui', '-no-cef-sandbox', '-cef-disable-gpu', '-cef-disable-gpu-compositing', 'steam://open/bigpicture']
print(f"Starting Steam Big Picture: {' '.join(args)}...")
p = subprocess.Popen(args, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print(f"Steam process launched with PID {p.pid}")

# Wait up to 15 seconds for steam.exe to appear in ps
for _ in range(15):
    time.sleep(1)
    res = subprocess.run(['ps', '-axo', 'comm='], capture_output=True, text=True)
    if any(line.strip().lower().endswith('steam.exe') for line in res.stdout.splitlines()):
        print("Steam is now running.")
        break
else:
    print("Warning: Steam process not confirmed within 15 seconds.")
