#!/usr/bin/env python3
"""Navigate to SINGLE PLAYER menu and enter, then capture screenshots."""
from pathlib import Path
import os
import subprocess
import time

root = Path(__file__).resolve().parent.parent
app_support = Path.home() / 'Library/Application Support/MacDeck'
runtime = app_support / 'SharedSteamRenderer/Runtime'
wine = runtime / 'bin/wine'
prefix = app_support / 'Bottles/Steam'
evidence_dir = root / 'evidence'

env = os.environ.copy()
env.update(
    WINEPREFIX=str(prefix),
    WINEDEBUG='-all',
    WINEMSYNC='1',
    WINEESYNC='0',
    DYLD_FALLBACK_LIBRARY_PATH=str(runtime / 'lib')
)

# Compile a key-sender with VK support
key_sender_src = r"""
#define UNICODE
#define _UNICODE
#include <windows.h>
#include <cstdio>
#include <cstring>

static HWND target = nullptr;
static BOOL CALLBACK findGame(HWND window, LPARAM) {
    if (!IsWindowVisible(window)) return TRUE;
    wchar_t title[256] = {};
    GetWindowTextW(window, title, 256);
    if (wcsstr(title, L"Half Minute Hero")) {
        target = window; return FALSE;
    }
    return TRUE;
}

int main(int argc, char** argv) {
    EnumWindows(findGame, 0);
    if (!target) { std::puts("Window not found"); return 1; }
    SetForegroundWindow(target);
    for (int i = 1; i < argc; i++) {
        WORD vk = 0;
        if (!strcmp(argv[i], "up")) vk = VK_UP;
        else if (!strcmp(argv[i], "down")) vk = VK_DOWN;
        else if (!strcmp(argv[i], "enter")) vk = VK_RETURN;
        else if (!strcmp(argv[i], "c")) vk = 'C';
        else if (!strcmp(argv[i], "x")) vk = 'X';
        else if (!strcmp(argv[i], "space")) vk = VK_SPACE;
        if (vk) {
            INPUT inputs[2] = {};
            inputs[0].type = INPUT_KEYBOARD;
            inputs[0].ki.wVk = vk;
            inputs[1].type = INPUT_KEYBOARD;
            inputs[1].ki.wVk = vk;
            inputs[1].ki.dwFlags = KEYEVENTF_KEYUP;
            SendInput(1, &inputs[0], sizeof(INPUT));
            Sleep(80);
            SendInput(1, &inputs[1], sizeof(INPUT));
            Sleep(150);
            std::printf("Sent key %s (vk=0x%x)\n", argv[i], vk);
        }
    }
    return 0;
}
"""
key_sender_cpp = root / '.build/key-nav.cpp'
key_sender_exe = root / '.build/key-nav.exe'
key_sender_cpp.write_text(key_sender_src)
compiler = root / '.cache/llvm-mingw/llvm-mingw-20261006-ucrt-macos-universal/bin/i686-w64-mingw32-clang++'
subprocess.run([str(compiler), '-O2', '-static', str(key_sender_cpp), '-o', str(key_sender_exe), '-luser32'], check=True)

# Resolve only the named game window; never reuse a stale numeric window ID.
probe = r"""
import CoreGraphics
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String:Any]] ?? []
for window in windows {
 let name = (window[kCGWindowName as String] as? String ?? "").lowercased()
 if name.contains("half") && name.contains("hero"), let id = window[kCGWindowNumber as String] as? Int { print(id); break }
}
"""
result = subprocess.run(['swift', '-'], input=probe, capture_output=True, text=True, check=True)
window_id = result.stdout.strip()
if not window_id.isdecimal():
    raise SystemExit('Named HMH game window not found; no screenshots captured')

# Right now, sub-menu "SETTINGS" is open under "HELP & OPTIONS".
# Press 'X' to close sub-menu, then UP to SINGLE PLAYER, then 'C' to enter.
print("Closing sub-menu with X...")
subprocess.run([str(wine), str(key_sender_exe), 'x'], env=env)
time.sleep(1)

print("Navigating up to SINGLE PLAYER...")
# Send UP 4 times to reach top
subprocess.run([str(wine), str(key_sender_exe), 'up', 'up', 'up', 'up'], env=env)
time.sleep(1)

shot1 = evidence_dir / 'hmh-menu-singleplayer.png'
subprocess.run(['screencapture', '-x', f"-l{window_id}", str(shot1)])
print(f"Captured: {shot1} ({shot1.stat().st_size} bytes)")

# Press 'C' to enter SINGLE PLAYER
print("Pressing C (Confirm) to enter SINGLE PLAYER...")
subprocess.run([str(wine), str(key_sender_exe), 'c'], env=env)
time.sleep(2)

shot2 = evidence_dir / 'hmh-singleplayer-mode.png'
subprocess.run(['screencapture', '-x', f"-l{window_id}", str(shot2)])
print(f"Captured: {shot2} ({shot2.stat().st_size} bytes)")

# Press 'C' once more to select default mode (Hero 30)
print("Pressing C (Confirm) to start Hero 30...")
subprocess.run([str(wine), str(key_sender_exe), 'c'], env=env)
time.sleep(3)

shot3 = evidence_dir / 'hmh-in-gameplay.png'
subprocess.run(['screencapture', '-x', f"-l{window_id}", str(shot3)])
print(f"Captured: {shot3} ({shot3.stat().st_size} bytes)")
