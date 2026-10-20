// Per-process D3D9 routing. No account files or launch arguments are read.
#define CINTERFACE
#include <windows.h>
#include <cwchar>
#include <cstdio>
#include "dmc-d3d9-trace.hpp"
#include "dmc-clear-router.hpp"
static volatile LONG dmcYieldLoaded = 0;
static volatile LONG hmhLatencyLoaded = 0;
extern "C" FARPROC router_resolve(const char *symbol, unsigned ordinal) {
    wchar_t app[32] = {}, patch[32] = {}, hmhPatch[32] = {}, hmhDiag[32] = {}, directory[1024] = {}, path[1200] = {};
    GetEnvironmentVariableW(L"SteamAppId", app, 32);
    if (!*app) {
        GetEnvironmentVariableW(L"SteamGameId", app, 32);
    }
    if (!*app) {
        wchar_t exe[MAX_PATH] = {};
        if (GetModuleFileNameW(nullptr, exe, MAX_PATH)) {
            const wchar_t *base = wcsrchr(exe, L'\\');
            base = base ? base + 1 : exe;
            if (!_wcsicmp(base, L"HMH.exe")) {
                wcscpy(app, L"214830");
            } else if (!_wcsicmp(base, L"DMC-DevilMayCry.exe")) {
                wcscpy(app, L"220440");
            }
        }
    }
    GetPrivateProfileStringW(L"patches",L"220440",L"",patch,32,L"C:\\ProgramData\\MacDeck\\renderers.ini");
    GetPrivateProfileStringW(L"patches",L"214830",L"",hmhPatch,32,L"C:\\ProgramData\\MacDeck\\renderers.ini");
    GetPrivateProfileStringW(L"diagnostics",L"214830",L"",hmhDiag,32,L"C:\\ProgramData\\MacDeck\\renderers.ini");
    const bool dmcEnabled = !wcscmp(app,L"220440") && (!wcscmp(patch,L"dxmt-v1") || !wcscmp(patch,L"dxmt-clear-v2") || !wcscmp(patch,L"dxmt-bind-v3") || !wcscmp(patch,L"dxmt-srgb-v4") || !wcscmp(patch,L"dxmt-smooth-v5"));
    const bool hmhEnabled = !wcscmp(app,L"214830") && (!wcscmp(hmhPatch,L"dxmt-v1") || !wcscmp(hmhPatch,L"dxmt-clear-v2"));
    const bool hmhClear = hmhEnabled && !wcscmp(hmhPatch,L"dxmt-clear-v2");
    const bool enabled = dmcEnabled || hmhEnabled;
    const bool smooth = dmcEnabled && !wcscmp(patch,L"dxmt-smooth-v5");
    const wchar_t *name = hmhEnabled ? (hmhClear ? L"macdeck_hmh_dxmt_clear_v2.dll" : L"macdeck_hmh_dxmt_v1.dll") : dmcEnabled ? ((!wcscmp(patch,L"dxmt-srgb-v4") || smooth) ? L"macdeck_dmc_dxmt_srgb_v4.dll" : !wcscmp(patch,L"dxmt-bind-v3") ? L"macdeck_dmc_dxmt_clear_v3.dll" : L"macdeck_dmc_dxmt_v1.dll") : L"macdeck_original_d3d9.dll";
    GetPrivateProfileStringW(L"runtime",L"dllDirectory32",L"",directory,1024,L"C:\\ProgramData\\MacDeck\\renderers.ini");
    if (!*directory) { RaiseException(0xc0000135,EXCEPTION_NONCONTINUABLE,0,nullptr); return nullptr; }
    swprintf(path,1200,L"%ls\\%ls",directory,name);
    HMODULE module = LoadLibraryW(path);
    static volatile LONG d3d9YieldLoaded = 0;
    wchar_t yieldVal[32] = {};
    GetPrivateProfileStringW(L"yield", app, L"", yieldVal, 32, L"C:\\ProgramData\\MacDeck\\renderers.ini");
    const bool yieldEnabled = !wcscmp(yieldVal, L"true");
    if (module && yieldEnabled && InterlockedCompareExchange(&d3d9YieldLoaded, 1, 0) == 0) {
        swprintf(path, 1200, L"%ls\\macdeck_d3d9_yield_helper.dll", directory);
        LoadLibraryW(path);
    }
    if (module && smooth && InterlockedCompareExchange(&dmcYieldLoaded,1,0)==0) {
        swprintf(path,1200,L"%ls\\macdeck_dmc_query_yield_v1.dll",directory);
        if (!LoadLibraryW(path)) { InterlockedExchange(&dmcYieldLoaded,0); RaiseException(0xc0000135,EXCEPTION_NONCONTINUABLE,0,nullptr); TerminateProcess(GetCurrentProcess(),127); }
    }
    bool latencyAttempted = false;
    DWORD latencyErr = 0;
    if (module && hmhEnabled && !wcscmp(hmhDiag,L"api-latency") && InterlockedCompareExchange(&hmhLatencyLoaded,1,0)==0) {
        latencyAttempted = true;
        swprintf(path,1200,L"%ls\\macdeck_hmh_api_latency.dll",directory);
        HMODULE hMod = LoadLibraryW(path);
        if (!hMod) latencyErr = GetLastError();
    }
    FARPROC address = module ? GetProcAddress(module,symbol ? symbol : MAKEINTRESOURCEA(ordinal)) : nullptr;
    if (!address) { RaiseException(module ? 0xc0000139 : 0xc0000135,EXCEPTION_NONCONTINUABLE,0,nullptr); TerminateProcess(GetCurrentProcess(),127); }
    CreateDirectoryW(L"C:\\ProgramData\\MacDeck\\RendererSessions",nullptr);
    wchar_t logPath[180] = {};
    // Names contain only the fixed selected identity, never uncontrolled environment text.
    swprintf(logPath,180,L"C:\\ProgramData\\MacDeck\\RendererSessions\\d3d9-%ls-%lu.log",hmhEnabled ? L"214830" : dmcEnabled ? L"220440" : L"default",GetCurrentProcessId());
    HANDLE log=CreateFileW(logPath,FILE_APPEND_DATA,FILE_SHARE_READ|FILE_SHARE_WRITE,nullptr,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
    if(log!=INVALID_HANDLE_VALUE) {
        if(GetFileSize(log,nullptr)<65536) {
            char line[256] = {};
            if (hmhEnabled) {
                snprintf(line, sizeof(line), "d3d9=dxmt-metal-clear-v2 appid=214830 yield=%d diag=%ls\r\n", yieldEnabled, hmhDiag);
            } else if (dmcEnabled) {
                snprintf(line, sizeof(line), "%s", smooth ? "d3d9=dxmt-metal-smooth-v5 appid=220440\r\n" : !wcscmp(patch,L"dxmt-srgb-v4") ? "d3d9=dxmt-metal-srgb-v4 appid=220440\r\n" : !wcscmp(patch,L"dxmt-bind-v3") ? "d3d9=dxmt-metal-bind-v3 appid=220440\r\n" : "d3d9=dxmt-metal-v1 appid=220440\r\n");
            } else {
                snprintf(line, sizeof(line), "d3d9=original\r\n");
            }
            DWORD written; WriteFile(log,line,(DWORD)strlen(line),&written,nullptr);
        }
        CloseHandle(log);
    }
    if(dmcEnabled && symbol && !strcmp(symbol,"Direct3DCreate9")) {
        if(!wcscmp(patch,L"dxmt-clear-v2")){dmcClearCreate9Original=reinterpret_cast<decltype(dmcClearCreate9Original)>(address);address=reinterpret_cast<FARPROC>(dmcClearCreate9);}
        wchar_t trace[32] = {};
        GetPrivateProfileStringW(L"diagnostics",L"220440",L"",trace,32,L"C:\\ProgramData\\MacDeck\\renderers.ini");
        if(!wcscmp(trace,L"frame-v1")){dmcCreate9Original=reinterpret_cast<decltype(dmcCreate9Original)>(address);return reinterpret_cast<FARPROC>(dmcTraceCreate9);}
    }
    return address;
}
BOOL WINAPI DllMain(HINSTANCE,DWORD,LPVOID){return TRUE;}
