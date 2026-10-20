#!/usr/bin/env python3
"""Launch HMH via running Steam (-applaunch 214830), track window, capture screenshots,
and test Enter key for gameplay transition.
"""
from pathlib import Path
import os
import subprocess
import time
import sys

root = Path(__file__).resolve().parent.parent
app_support = Path.home() / 'Library/Application Support/MacDeck'
runtime = app_support / 'SharedSteamRenderer/Runtime'
wine = runtime / 'bin/wine'
prefix = app_support / 'Bottles/Steam'
steam_exe = prefix / 'drive_c/Program Files (x86)/Steam/steam.exe'
evidence_dir = root / 'evidence'
evidence_dir.mkdir(exist_ok=True)

steam_env = os.environ.copy()
steam_env.update(
    WINEPREFIX=str(prefix),
    WINEDEBUG='-all',
    WINEMSYNC='1',
    WINEESYNC='0',
    WINE_LARGE_ADDRESS_AWARE='1',
    DYLD_FALLBACK_LIBRARY_PATH=str(runtime / 'lib')
)

print("Sending -applaunch 214830 to Steam...")
subprocess.run([str(wine), str(steam_exe), '-applaunch', '214830'], env=steam_env, timeout=10)

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

window = None
for attempt in range(15):
    time.sleep(1)
    # Check if HMH.exe is in ps
    ps_res = subprocess.run(['ps', '-axo', 'comm='], capture_output=True, text=True)
    if 'HMH.exe' in ps_res.stdout:
        print("HMH.exe process is running!")
    window = find_hmh_window()
    if window:
        print(f"Found HMH window: ID={window['id']}, Size={window['width']}x{window['height']}, Layer={window['layer']}")
        break
    print(f"Waiting for HMH window... attempt {attempt+1}")

if window:
    # Give it 3 seconds to render the title screen
    time.sleep(3)
    shot1 = evidence_dir / 'hmh-screen-1-title.png'
    subprocess.run(['screencapture', '-x', f"-l{window['id']}", str(shot1)])
    if shot1.exists():
        print(f"SUCCESS: Captured screen 1 (Title): {shot1} ({shot1.stat().st_size} bytes)")

    # Send Enter key via probe
    print("Sending Enter key...")
    probe_res = subprocess.run([str(wine), str(root / '.build/wine-hmh-window-probe.exe'), '--enter'], env=steam_env, capture_output=True, text=True)
    print("Probe output:", probe_res.stdout.strip())

    # Wait 3 seconds for transition to gameplay/mode selection
    time.sleep(3)
    shot2 = evidence_dir / 'hmh-screen-2-gameplay.png'
    subprocess.run(['screencapture', '-x', f"-l{window['id']}", str(shot2)])
    if shot2.exists():
        print(f"SUCCESS: Captured screen 2 (Gameplay transition): {shot2} ({shot2.stat().st_size} bytes)")

    # Send Enter key once more to select game mode / start
    time.sleep(1)
    print("Sending Enter key 2nd time...")
    subprocess.run([str(wine), str(root / '.build/wine-hmh-window-probe.exe'), '--enter'], env=steam_env, capture_output=True, text=True)
    time.sleep(3)
    shot3 = evidence_dir / 'hmh-screen-3-active.png'
    subprocess.run(['screencapture', '-x', f"-l{window['id']}", str(shot3)])
    if shot3.exists():
        print(f"SUCCESS: Captured screen 3 (Active gameplay): {shot3} ({shot3.stat().st_size} bytes)")
else:
    print("Failed to find HMH window.")
