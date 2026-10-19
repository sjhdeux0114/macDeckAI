// Experimental x64 graphics router. It reads only a numeric SteamAppId and
// MacDeck's renderer map; it never reads Steam account/configuration files.
#include <windows.h>
#include <cwchar>
#include <cstdio>
#ifndef ROUTER_MODULE
#define ROUTER_MODULE L"dxgi"
#endif
extern "C" FARPROC router_resolve(const char *symbol, unsigned ordinal) {
    wchar_t app[32] = {}, backend[32] = {}, library[96] = {};
    DWORD length = GetEnvironmentVariableW(L"SteamAppId", app, 32);
    bool numeric = length > 0 && length < 32;
    for (DWORD i=0; numeric && i<length; ++i) numeric = app[i]>=L'0' && app[i]<=L'9';
    if (!numeric) wcscpy(app,L"0");
    wchar_t fallback[32] = {};
    GetPrivateProfileStringW(L"renderers",L"default",L"dxmt",fallback,32,L"C:\\ProgramData\\MacDeck\\renderers.ini");
    GetPrivateProfileStringW(L"renderers",app,fallback,backend,32,L"C:\\ProgramData\\MacDeck\\renderers.ini");
    if (!wcscmp(app,L"0")) wcscpy(backend,L"dxmt"); // Big Picture keeps its established DXMT UI path.
    if (wcscmp(backend,L"metal") && wcscmp(backend,L"vkd3d") && wcscmp(backend,L"dxmt")) wcscpy(backend,L"dxmt");
    // DXMT implements D3D11; an unselected D3D12 route uses Wine/VKD3D.
    const wchar_t *component = (!wcscmp(ROUTER_MODULE,L"d3d12") || !wcscmp(ROUTER_MODULE,L"d3d12core")) && !wcscmp(backend,L"dxmt") ? L"vkd3d" : backend;
    swprintf(library,96,L"macdeck_%ls_%ls.dll",component,ROUTER_MODULE);
    bool marshalFix = false;
    if (!wcscmp(app,L"601150") && !wcscmp(backend,L"dxmt") && !wcscmp(ROUTER_MODULE,L"d3d11")) {
        wchar_t patch[32] = {};
        GetPrivateProfileStringW(L"patches",L"601150",L"",patch,32,L"C:\\ProgramData\\MacDeck\\renderers.ini");
        marshalFix = !wcscmp(patch,L"gs-ts-v1");
        if (marshalFix) wcscpy(library,L"macdeck_dxmt_gsts_v1_d3d11.dll");
    }
    wchar_t directory[1024] = {}, target[1200] = {};
    GetPrivateProfileStringW(L"runtime",L"dllDirectory",L"",directory,1024,L"C:\\ProgramData\\MacDeck\\renderers.ini");
    swprintf(target,1200,L"%ls%ls%ls",directory,*directory ? L"\\" : L"",library);
    HMODULE module = LoadLibraryW(target);
    FARPROC address = module ? GetProcAddress(module, symbol ? symbol : MAKEINTRESOURCEA(ordinal)) : nullptr;
    if (!address) {
        std::fprintf(stderr,"MacDeck renderer router: module=%ls load=%lu symbol=%s ordinal=%u error=%lu\n",library,module ? 1UL : 0UL,symbol ? symbol : "(ordinal)",ordinal,GetLastError());
        // Never report a fake success for an absent implementation.
        RaiseException(module ? 0xc0000139 : 0xc0000135,EXCEPTION_NONCONTINUABLE,0,nullptr);
        TerminateProcess(GetCurrentProcess(),127);
    }
    // Bounded, app-ID-only diagnostics; no Steam account or launch arguments.
    CreateDirectoryW(L"C:\\ProgramData\\MacDeck\\RendererSessions",nullptr);
    wchar_t logPath[180] = {};
    swprintf(logPath,180,L"C:\\ProgramData\\MacDeck\\RendererSessions\\%ls-%lu.log",app,GetCurrentProcessId());
    HANDLE log = CreateFileW(logPath,FILE_APPEND_DATA,FILE_SHARE_READ|FILE_SHARE_WRITE,nullptr,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
    if (log != INVALID_HANDLE_VALUE) {
        if (GetFileSize(log,nullptr)<65536) {
            char line[220]; FILETIME time; GetSystemTimeAsFileTime(&time);
            unsigned long long stamp=((unsigned long long)time.dwHighDateTime<<32)|time.dwLowDateTime;
            int length=std::snprintf(line,sizeof(line),"appid=%ls pid=%lu module=%ls renderer=%ls marshal=%u time=%llu\r\n",app,GetCurrentProcessId(),ROUTER_MODULE,backend,marshalFix ? 1U : 0U,stamp);
            DWORD written; if (length>0 && length<(int)sizeof(line)) WriteFile(log,line,length,&written,nullptr);
        }
        CloseHandle(log);
    }
    return address;
}
BOOL WINAPI DllMain(HINSTANCE, DWORD, LPVOID) { return TRUE; }
