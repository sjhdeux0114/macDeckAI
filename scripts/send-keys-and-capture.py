#!/usr/bin/env python3
"""Send keys (Space, Enter, Esc) to HMH window and capture screenshot."""
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

# Find window ID
probe_swift = """
import Foundation
import CoreGraphics
let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for w in windows {
    let name = (w[kCGWindowName as String] as? String ?? "").lowercased()
    let windowId = w[kCGWindowNumber as String] as? Int ?? 0
    let bounds = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let width = bounds["Width"] as? Int ?? 0
    let height = bounds["Height"] as? Int ?? 0
    if name.contains("half") && name.contains("hero") {
        print("\\(windowId)")
        break
    }
}
"""
res = subprocess.run(['swift', '-'], input=probe_swift, text=True, capture_output=True)
window_id = res.stdout.strip()
print(f"Target window ID: {window_id}")

if not window_id:
    print("Could not find HMH window.")
    exit(1)

# Compile a key-sender that sends VK_SPACE, VK_RETURN, VK_ESCAPE
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
    WORD vk = VK_RETURN;
    if (argc > 1) {
        if (!strcmp(argv[1], "space")) vk = VK_SPACE;
        else if (!strcmp(argv[1], "esc")) vk = VK_ESCAPE;
        else if (!strcmp(argv[1], "enter")) vk = VK_RETURN;
    }
    INPUT inputs[2] = {};
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = vk;
    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.wVk = vk;
    inputs[1].ki.dwFlags = KEYEVENTF_KEYUP;
    SendInput(1, &inputs[0], sizeof(INPUT));
    Sleep(100);
    SendInput(1, &inputs[1], sizeof(INPUT));
    std::printf("Sent key %s (vk=0x%x) to HWND %p\n", argv[1] ? argv[1] : "enter", vk, target);
    return 0;
}
"""
key_sender_cpp = root / '.build/key-sender.cpp'
key_sender_exe = root / '.build/key-sender.exe'
key_sender_cpp.write_text(key_sender_src)
compiler = root / '.cache/llvm-mingw/llvm-mingw-20261006-ucrt-macos-universal/bin/i686-w64-mingw32-clang++'
subprocess.run([str(compiler), '-O2', '-static', str(key_sender_cpp), '-o', str(key_sender_exe), '-luser32'], check=True)

# Step 1: Send Space to skip possible intro movie
print("Sending Space...")
subprocess.run([str(wine), str(key_sender_exe), 'space'], env=env)
time.sleep(1.5)

# Step 2: Send Enter to confirm / start
print("Sending Enter...")
subprocess.run([str(wine), str(key_sender_exe), 'enter'], env=env)
time.sleep(1.5)

# Capture screenshot
shot = evidence_dir / 'hmh-after-keys.png'
subprocess.run(['screencapture', '-x', f"-l{window_id}", str(shot)])
print(f"Captured: {shot} ({shot.stat().st_size} bytes)")
