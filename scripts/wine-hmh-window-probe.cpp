// Diagnostics and Enter input confined to the HMH.exe window in this Wine prefix.
#define UNICODE
#define _UNICODE
#include <windows.h>
#include <cstdio>
#include <cwchar>
#include <cstring>
static HWND target = nullptr;
static DWORD targetPID = 0;
static BOOL CALLBACK findGame(HWND window, LPARAM) {
  if (!IsWindowVisible(window)) return TRUE;
  DWORD pid = 0; GetWindowThreadProcessId(window, &pid);
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!process) return TRUE;
  wchar_t path[2048]; DWORD count = 2048;
  bool matches = QueryFullProcessImageNameW(process, 0, path, &count) != FALSE;
  CloseHandle(process);
  if (!matches) return TRUE;
  const wchar_t* base = std::wcsrchr(path, L'\\');
  base = base ? base+1 : path;
  if (_wcsicmp(base, L"HMH.exe")) return TRUE;
  RECT client; GetClientRect(window, &client);
  if (client.right < 100 || client.bottom < 100) return TRUE;
  target = window; targetPID = pid; return FALSE;
}
int main(int argc, char** argv) {
  SetProcessDPIAware();
  EnumWindows(findGame, 0);
  HDESK desktop = nullptr;
  if (!target) {
    desktop = OpenDesktopW(L"HMH", 0, FALSE, DESKTOP_ENUMERATE | DESKTOP_READOBJECTS | DESKTOP_WRITEOBJECTS | DESKTOP_SWITCHDESKTOP);
    if (desktop) {
      SetThreadDesktop(desktop);
      EnumDesktopWindows(desktop, findGame, 0);
    }
  }
  if (!target) { std::puts("HMH window not found"); return 2; }
  RECT client{}, bounds{}; GetClientRect(target, &client); GetWindowRect(target, &bounds);
  auto getDpi = reinterpret_cast<UINT(WINAPI*)(HWND)>(GetProcAddress(GetModuleHandleW(L"user32.dll"), "GetDpiForWindow"));
  std::printf("HMH pid=%lu hwnd=%p client=%ldx%ld bounds=%ld,%ld %ldx%ld dpi=%u screen=%dx%d\n", targetPID, target, client.right, client.bottom, bounds.left, bounds.top, bounds.right-bounds.left, bounds.bottom-bounds.top, getDpi ? getDpi(target) : 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN));
  if (argc > 1 && !std::strcmp(argv[1], "--fit")) {
    BOOL moved = SetWindowPos(target, nullptr, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    DWORD error = moved ? 0 : GetLastError();
    GetWindowRect(target, &bounds);
    std::printf("HMH move to desktop origin: success=%d error=%lu bounds=%ld,%ld %ldx%ld\n", moved, error, bounds.left, bounds.top, bounds.right-bounds.left, bounds.bottom-bounds.top);
    return moved ? 0 : 5;
  }
  if (argc > 1 && !std::strcmp(argv[1], "--enter")) {
    if (!SetForegroundWindow(target)) { std::puts("Could not focus HMH; no input sent"); return 3; }
    INPUT input{}; input.type = INPUT_KEYBOARD; input.ki.wVk = VK_RETURN;
    UINT down = SendInput(1, &input, sizeof(input));
    Sleep(150);
    input.ki.dwFlags = KEYEVENTF_KEYUP;
    UINT up = SendInput(1, &input, sizeof(input));
    std::printf("HMH Enter input accepted: down=%u up=%u error=%lu\n", down, up, GetLastError());
    if (down != 1 || up != 1) return 4;
  }
  // The process exits immediately; leave the bound desktop handle to OS cleanup.
  return 0;
}
