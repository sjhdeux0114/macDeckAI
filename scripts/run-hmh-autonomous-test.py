#!/usr/bin/env python3
"""Run HMH autonomously, capture window screenshots with screencapture, test Enter input,
and save visual evidence to evidence/hmh-screen-*.png.
"""
from pathlib import Path
import os
import subprocess
import time
import json
import sys

root = Path(__file__).resolve().parent.parent
app_support = Path.home() / 'Library/Application Support/MacDeck'
runtime = app_support / 'SharedSteamRenderer/Runtime'
wine = runtime / 'bin/wine'
prefix = app_support / 'Bottles/Steam'
game_exe = Path('/Volumes/NVME_1T/SteamLibrary/steamapps/common/Half Minute Hero/HMH.exe')
evidence_dir = root / 'evidence'
evidence_dir.mkdir(exist_ok=True)

if not game_exe.exists():
    sys.exit(f"Game executable not found: {game_exe}")

env = os.environ.copy()
env.update(
    WINEPREFIX=str(prefix),
    WINEDEBUG='-all',
    WINEMSYNC='0',
    WINEESYNC='0',
    SteamAppId='214830',
    SteamGameId='214830',
    WINEDLLOVERRIDES='d3d9=b;mscoree,mshtml=',
    DYLD_FALLBACK_LIBRARY_PATH=str(runtime / 'lib'),
    MTL_HUD_ENABLED='1'
)

print(f"Launching HMH: {game_exe}...")
process = subprocess.Popen([str(wine), str(game_exe)], env=env)
pid = process.pid
print(f"HMH process started with PID {pid}")

def find_hmh_window():
    probe_swift = """
import Foundation
import CoreGraphics
let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for w in windows {
    let owner = (w[kCGWindowOwnerName as String] as? String ?? "").lowercased()
    let name = (w[kCGWindowName as String] as? String ?? "").lowercased()
    let bounds = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let width = bounds["Width"] as? Int ?? 0
    let height = bounds["Height"] as? Int ?? 0
    let windowId = w[kCGWindowNumber as String] as? Int ?? 0
    let layer = w[kCGWindowLayer as String] as? Int ?? 0
    if (name.contains("half") && name.contains("hero")) && width > 200 && height > 200 {
        print("\\(windowId)|\\(width)|\\(height)|\\(layer)|\\(owner)|\\(name)")
    }
}
"""
    res = subprocess.run(['swift', '-'], input=probe_swift, text=True, capture_output=True)
    lines = [line.strip() for line in res.stdout.strip().split('\n') if line.strip()]
    if lines:
        parts = lines[0].split('|')
        return {
            'id': int(parts[0]),
            'width': int(parts[1]),
            'height': int(parts[2]),
            'layer': int(parts[3]),
            'owner': parts[4],
            'name': parts[5] if len(parts) > 5 else ''
        }
    return None

try:
    window = None
    for attempt in range(15):
        time.sleep(1)
        if process.poll() is not None:
            print(f"Process exited early with return code {process.returncode}")
            break
        window = find_hmh_window()
        if window:
            print(f"Found HMH window: ID={window['id']}, Size={window['width']}x{window['height']}, Layer={window['layer']}")
            break
        print(f"Waiting for window... attempt {attempt+1}")

    if window:
        # Wait 2 seconds for initial render
        time.sleep(2)
        shot1 = evidence_dir / 'hmh-screen-1-title.png'
        subprocess.run(['screencapture', '-x', f"-l{window['id']}", str(shot1)])
        print(f"Captured screen 1: {shot1} ({shot1.stat().st_size} bytes)")

        # Send Enter key
        print("Sending Enter key via wine-hmh-window-probe.exe...")
        probe_res = subprocess.run([str(wine), str(root / '.build/wine-hmh-window-probe.exe'), '--enter'], env=env, capture_output=True, text=True)
        print("Probe output:", probe_res.stdout.strip())

        # Wait 3 seconds for gameplay transition
        time.sleep(3)
        shot2 = evidence_dir / 'hmh-screen-2-gameplay.png'
        subprocess.run(['screencapture', '-x', f"-l{window['id']}", str(shot2)])
        print(f"Captured screen 2: {shot2} ({shot2.stat().st_size} bytes)")

        # Send Enter key once more in case of title confirmation / save slot
        time.sleep(1)
        subprocess.run([str(wine), str(root / '.build/wine-hmh-window-probe.exe'), '--enter'], env=env, capture_output=True, text=True)
        time.sleep(2)
        shot3 = evidence_dir / 'hmh-screen-3-active.png'
        subprocess.run(['screencapture', '-x', f"-l{window['id']}", str(shot3)])
        print(f"Captured screen 3: {shot3} ({shot3.stat().st_size} bytes)")

    else:
        print("Could not find on-screen game window within timeout.")

finally:
    print("Terminating HMH test process...")
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
    print("HMH test finished.")
