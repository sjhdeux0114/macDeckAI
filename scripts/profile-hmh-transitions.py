#!/usr/bin/env python3
"""Run HMH, navigate through multiple screen transitions, and collect D3D9 API latency and frame interval report."""
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
report_file = prefix / 'drive_c/ProgramData/MacDeck/RendererSessions/hmh-api-latency.txt'
evidence_dir = root / 'evidence'

# Delete previous report if exists
if report_file.exists():
    report_file.unlink()

print("1. Launching HMH via Steam...")
steam_env = os.environ.copy()
steam_env.update(
    WINEPREFIX=str(prefix),
    WINEDEBUG='-all',
    WINEMSYNC='1',
    WINEESYNC='0',
    WINE_LARGE_ADDRESS_AWARE='1',
    DYLD_FALLBACK_LIBRARY_PATH=str(runtime / 'lib')
)
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
        print("\(windowId)|\(width)|\(height)|\(layer)|\(owner)|\(name)")
    }
}
"""
    res = subprocess.run(['swift', '-'], input=probe_swift, text=True, capture_output=True)
    lines = [line.strip() for line in res.stdout.strip().split('\n') if line.strip()]
    if lines:
        parts = lines[0].split('|')
        return int(parts[0])
    return None

print("2. Waiting for HMH window...")
hmh_win = None
for _ in range(30):
    time.sleep(1)
    hmh_win = find_hmh_window()
    if hmh_win:
        print(f"   Found HMH window ID {hmh_win}")
        break

if not hmh_win:
    print("ERROR: HMH window not found!")
    sys.exit(1)

def send_key(key_code):
    cmd = f"""
osascript -e '
tell application "System Events"
    set wineProcs to every process whose name contains "wine" or name contains "HMH"
    if (count of wineProcs) > 0 then
        set frontmost of item 1 of wineProcs to true
    end if
    key code {key_code}
end tell'
"""
    subprocess.run(cmd, shell=True, capture_output=True)

print("3. Executing screen transitions with key inputs...")
# Wait for initial intro/title
time.sleep(4)
print("   - Transition 1: Title -> Main Menu (sending C key)")
send_key(8) # 'c'
time.sleep(2)
send_key(8)
time.sleep(3)

print("   - Transition 2: Main Menu -> Game Mode selection (sending C key)")
send_key(8)
time.sleep(3)

print("   - Transition 3: Entering Quest 01 (sending C key)")
send_key(8)
time.sleep(4)

print("   - In-game dialogue & movement (sending C key repeatedly to progress dialog)")
for i in range(5):
    send_key(8)
    time.sleep(1.5)

print("4. Waiting for 30s profiler watchdog to finalize...")
for elapsed in range(40):
    if report_file.exists() and report_file.stat().st_size > 0:
        print(f"   Report finalized at {elapsed}s!")
        break
    time.sleep(1)

time.sleep(1)
if report_file.exists():
    print("\n=== PROFILE REPORT READY ===")
    print(report_file.read_text())
else:
    print("ERROR: Report file was not written!")
