// Experimental x64 graphics router. The default build uses numeric Steam IDs;
// ROUTER_EPIC_ONLY uses exact executable file identities from MacDeck's map.
// No account files, process arguments, or credentials are read.
#include <windows.h>
#include <cwchar>
#include <cstdio>
#ifndef ROUTER_MODULE
#define ROUTER_MODULE L"dxgi"
#endif
#ifdef ROUTER_EPIC_ONLY
static bool sameExecutable(const wchar_t *a,const wchar_t *b) {
    if (!_wcsicmp(a,b)) return true;
    HANDLE first=CreateFileW(a,FILE_READ_ATTRIBUTES,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,nullptr,OPEN_EXISTING,0,nullptr);
    HANDLE second=CreateFileW(b,FILE_READ_ATTRIBUTES,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,nullptr,OPEN_EXISTING,0,nullptr);
    BY_HANDLE_FILE_INFORMATION one={},two={};
    bool same=first!=INVALID_HANDLE_VALUE && second!=INVALID_HANDLE_VALUE
        && GetFileInformationByHandle(first,&one) && GetFileInformationByHandle(second,&two)
        && (one.nFileIndexHigh||one.nFileIndexLow)
        && one.dwVolumeSerialNumber==two.dwVolumeSerialNumber
        && one.nFileIndexHigh==two.nFileIndexHigh && one.nFileIndexLow==two.nFileIndexLow;
    if(first!=INVALID_HANDLE_VALUE)CloseHandle(first);
    if(second!=INVALID_HANDLE_VALUE)CloseHandle(second);
    return same;
}
#endif
extern "C" FARPROC router_resolve(const char *symbol, unsigned ordinal) {
    wchar_t app[128] = {}, backend[32] = {}, library[96] = {};
#ifdef ROUTER_EPIC_ONLY
    wcscpy(app,L"0");
    wchar_t executable[2048] = {}, entries[32768] = {};
    DWORD executableLength = GetModuleFileNameW(nullptr,executable,2048);
    if (executableLength && executableLength < 2048) {
        const wchar_t *sections[] = {L"epic-paths",L"epic-secondary-paths"};
        for (const auto section : sections) {
            DWORD count=GetPrivateProfileSectionW(section,entries,32768,L"C:\\ProgramData\\MacDeck\\renderers.ini");
            if (count >= 32766) continue; // Fail closed on a truncated path map.
            for (wchar_t *entry=entries; *entry; entry+=wcslen(entry)+1) {
                wchar_t *separator=wcschr(entry,L'=');
                if (!separator || separator-entry<1 || separator-entry>=120) continue;
                bool valid=true;
                for(wchar_t *p=entry;p<separator;++p) if(!((*p>=L'0'&&*p<=L'9')||(*p>=L'a'&&*p<=L'z')||(*p>=L'A'&&*p<=L'Z')||*p==L'-'||*p==L'_')) valid=false;
                if(valid && sameExecutable(separator+1,executable)) {
                    wcsncpy(app,entry,separator-entry);app[separator-entry]=0;break;
                }
            }
        }
    }
#else
    DWORD length = GetEnvironmentVariableW(L"SteamAppId", app, 32);
    bool numeric = length > 0 && length < 32;
    for (DWORD i=0; numeric && i<length; ++i) numeric = app[i]>=L'0' && app[i]<=L'9';
    if (!numeric) wcscpy(app,L"0");
#endif
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
    wchar_t logPath[260] = {};
    swprintf(logPath,260,L"C:\\ProgramData\\MacDeck\\RendererSessions\\%ls-%lu.log",app,GetCurrentProcessId());
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
