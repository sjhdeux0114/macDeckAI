// Per-process D3D9 routing. No account files or launch arguments are read.
#define CINTERFACE
#include <windows.h>
#include <cwchar>
#include <cstdio>
#include "dmc-d3d9-trace.hpp"
#include "dmc-clear-router.hpp"
extern "C" FARPROC router_resolve(const char *symbol, unsigned ordinal) {
    wchar_t app[32] = {}, patch[32] = {}, directory[1024] = {}, path[1200] = {};
    GetEnvironmentVariableW(L"SteamAppId", app, 32);
    GetPrivateProfileStringW(L"patches",L"220440",L"",patch,32,L"C:\\ProgramData\\MacDeck\\renderers.ini");
    const bool enabled = !wcscmp(app,L"220440") && (!wcscmp(patch,L"dxmt-v1") || !wcscmp(patch,L"dxmt-clear-v2"));
    const wchar_t *name = enabled ? L"macdeck_dmc_dxmt_v1.dll" : L"macdeck_original_d3d9.dll";
    GetPrivateProfileStringW(L"runtime",L"dllDirectory32",L"",directory,1024,L"C:\\ProgramData\\MacDeck\\renderers.ini");
    if (!*directory) { RaiseException(0xc0000135,EXCEPTION_NONCONTINUABLE,0,nullptr); return nullptr; }
    swprintf(path,1200,L"%ls\\%ls",directory,name);
    HMODULE module = LoadLibraryW(path);
    FARPROC address = module ? GetProcAddress(module,symbol ? symbol : MAKEINTRESOURCEA(ordinal)) : nullptr;
    if (!address) { RaiseException(module ? 0xc0000139 : 0xc0000135,EXCEPTION_NONCONTINUABLE,0,nullptr); TerminateProcess(GetCurrentProcess(),127); }
    CreateDirectoryW(L"C:\\ProgramData\\MacDeck\\RendererSessions",nullptr);
    wchar_t logPath[180] = {};
    // Names contain only the fixed selected identity, never uncontrolled environment text.
    swprintf(logPath,180,L"C:\\ProgramData\\MacDeck\\RendererSessions\\d3d9-%ls-%lu.log",enabled ? L"220440" : L"default",GetCurrentProcessId());
    HANDLE log=CreateFileW(logPath,FILE_APPEND_DATA,FILE_SHARE_READ|FILE_SHARE_WRITE,nullptr,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
    if(log!=INVALID_HANDLE_VALUE) {
        if(GetFileSize(log,nullptr)<65536) { const char *line=enabled ? "d3d9=dxmt-metal-v1 appid=220440\r\n" : "d3d9=original\r\n"; DWORD written; WriteFile(log,line,(DWORD)strlen(line),&written,nullptr); }
        CloseHandle(log);
    }
    if(enabled && symbol && !strcmp(symbol,"Direct3DCreate9")) {
        if(!wcscmp(patch,L"dxmt-clear-v2")){dmcClearCreate9Original=reinterpret_cast<decltype(dmcClearCreate9Original)>(address);address=reinterpret_cast<FARPROC>(dmcClearCreate9);}
        wchar_t trace[32] = {};
        GetPrivateProfileStringW(L"diagnostics",L"220440",L"",trace,32,L"C:\\ProgramData\\MacDeck\\renderers.ini");
        if(!wcscmp(trace,L"frame-v1")){dmcCreate9Original=reinterpret_cast<decltype(dmcCreate9Original)>(address);return reinterpret_cast<FARPROC>(dmcTraceCreate9);}
    }
    return address;
}
BOOL WINAPI DllMain(HINSTANCE,DWORD,LPVOID){return TRUE;}
