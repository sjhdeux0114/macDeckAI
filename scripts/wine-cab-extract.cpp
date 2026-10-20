// Extract a pinned Microsoft cabinet into one caller-owned directory; flatten names safely.
#ifndef UNICODE
#define UNICODE
#endif
#define _UNICODE
#include <windows.h>
#include <setupapi.h>
#include <cstdio>
#include <cwchar>
struct Context { const wchar_t *directory; unsigned extracted; DWORD error; };
static UINT CALLBACK notification(void *raw, UINT message, UINT_PTR first, UINT_PTR) {
    auto &context=*static_cast<Context*>(raw);
    if(message==SPFILENOTIFY_FILEINCABINET) {
        auto *file=reinterpret_cast<FILE_IN_CABINET_INFO_W*>(first);
        const wchar_t *name=file->NameInCabinet;
        if(!*name||wcschr(name,L'/')||wcschr(name,L'\\')||wcschr(name,L':')||!wcscmp(name,L".")||!wcscmp(name,L"..")) return FILEOP_SKIP;
        if(swprintf(file->FullTargetName,MAX_PATH,L"%ls\\%ls",context.directory,name)<0) {context.error=ERROR_BUFFER_OVERFLOW;return FILEOP_ABORT;}
        if(GetFileAttributesW(file->FullTargetName)!=INVALID_FILE_ATTRIBUTES) {context.error=ERROR_FILE_EXISTS;return FILEOP_ABORT;}
        return FILEOP_DOIT;
    }
    if(message==SPFILENOTIFY_FILEEXTRACTED) {
        auto *paths=reinterpret_cast<FILEPATHS_W*>(first);
        if(paths->Win32Error){context.error=paths->Win32Error;return FILEOP_ABORT;}
        ++context.extracted;
    }
    return NO_ERROR;
}
int wmain(int argc,wchar_t **argv) {
    if(argc!=3)return 2;
    Context context={argv[2],0,0};
    if(!SetupIterateCabinetW(argv[1],0,notification,&context)||context.error) {
        printf("FAIL cabinet extraction error=%lu\n",context.error?context.error:GetLastError());return 1;
    }
    printf("PASS extracted %u pinned cabinet files\n",context.extracted);return context.extracted?0:1;
}
