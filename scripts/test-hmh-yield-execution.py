#!/usr/bin/env python3
"""Run HMH with universal d3d9YieldFix, measure CPU utilization during transitions,
capture evidence screenshots, and verify responsiveness.
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
    if (owner.contains("wine") || owner.contains("hmh") || name.contains("half") || name.contains("hero")) && width > 200 && height > 200 {
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

def get_hmh_cpu():
    res = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
    for line in res.stdout.splitlines():
        if 'HMH.exe' in line and 'grep' not in line:
            parts = line.split()
            if len(parts) >= 3:
                return float(parts[2]), parts[7]  # %CPU, STAT
    return None, None

def send_key(key_code):
    swift_cmd = f"""
import Foundation
import CoreGraphics
let src = CGEventSource(stateID: .hidSystemState)
let down = CGEvent(keyboardEventSource: src, virtualKey: {key_code}, keyDown: true)
let up = CGEvent(keyboardEventSource: src, virtualKey: {key_code}, keyDown: false)
down?.post(tap: .cghidEventTap)
Thread.sleep(forTimeInterval: 0.08)
up?.post(tap: .cghidEventTap)
"""
    subprocess.run(['swift', '-'], input=swift_cmd, text=True, capture_output=True)

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

print("2. Waiting for HMH window to appear...")
win = None
start_time = time.time()
while time.time() - start_time < 20:
    win = find_hmh_window()
    if win:
        print(f"HMH window found: ID={win['id']}, size={win['width']}x{win['height']}")
        break
    time.sleep(0.5)

if not win:
    print("ERROR: HMH window did not appear within 20s!")
    sys.exit(1)

# Wait for title animation to settle
time.sleep(3.0)

# Capture initial title screenshot
shot1 = evidence_dir / 'hmh_yield_01_title.png'
subprocess.run(['screencapture', '-x', '-l', str(win['id']), str(shot1)])
cpu1, stat1 = get_hmh_cpu()
print(f"Initial title screen captured: {shot1} (CPU: {cpu1}%, STAT: {stat1})")

# Sample CPU over 3 seconds during idle title
cpu_samples = []
for _ in range(6):
    c, s = get_hmh_cpu()
    if c is not None:
        cpu_samples.append(c)
    time.sleep(0.5)
avg_idle_cpu = sum(cpu_samples) / len(cpu_samples) if cpu_samples else 0
print(f"Average Idle Title CPU: {avg_idle_cpu:.1f}%")

print("3. Navigating menu with Enter key (Title -> Mode Select)...")
send_key(36) # Enter
time.sleep(1.5)

shot2 = evidence_dir / 'hmh_yield_02_mode_select.png'
subprocess.run(['screencapture', '-x', '-l', str(win['id']), str(shot2)])
cpu2, stat2 = get_hmh_cpu()
print(f"Mode select screen captured: {shot2} (CPU: {cpu2}%, STAT: {stat2})")

print("4. Selecting Single Player -> Hero 30...")
send_key(36) # Enter
time.sleep(1.5)

shot3 = evidence_dir / 'hmh_yield_03_hero30.png'
subprocess.run(['screencapture', '-x', '-l', str(win['id']), str(shot3)])
cpu3, stat3 = get_hmh_cpu()
print(f"Hero 30 screen captured: {shot3} (CPU: {cpu3}%, STAT: {stat3})")

print("5. Starting Quest 01 (Transition to active gameplay)...")
send_key(36) # Enter

# Measure CPU specifically during active screen transition and load
transition_samples = []
t_start = time.time()
while time.time() - t_start < 4.0:
    c, s = get_hmh_cpu()
    if c is not None:
        transition_samples.append((round(time.time() - t_start, 2), c, s))
    time.sleep(0.2)

shot4 = evidence_dir / 'hmh_yield_04_gameplay.png'
subprocess.run(['screencapture', '-x', '-l', str(win['id']), str(shot4)])
cpu4, stat4 = get_hmh_cpu()
print(f"Gameplay screen captured: {shot4} (CPU: {cpu4}%, STAT: {stat4})")

print("\n--- Transition CPU Samples ---")
for t_sec, c_val, s_val in transition_samples:
    print(f"  +{t_sec}s: CPU={c_val}%, STAT={s_val}")

avg_transition_cpu = sum(s[1] for s in transition_samples) / len(transition_samples) if transition_samples else 0
print(f"Average Transition CPU: {avg_transition_cpu:.1f}%")

print("\n--- Verification Summary ---")
print(f"Title CPU: {avg_idle_cpu:.1f}%")
print(f"Transition CPU: {avg_transition_cpu:.1f}%")
print(f"Screenshots saved to: {evidence_dir}")
