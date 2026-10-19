#include <windows.h>
#include <cstdio>
#include <cstring>
int main(int argc, char**argv) {
 if(argc!=2)return 2;
 ACTCTXA ctx={};ctx.cbSize=sizeof(ctx);ctx.lpSource=argv[1];
 HANDLE handle=CreateActCtxA(&ctx);ULONG_PTR cookie=0;
 if(handle==INVALID_HANDLE_VALUE||!ActivateActCtx(handle,&cookie)){std::printf("FAIL VC90 activation %lu\n",GetLastError());return 3;}
 HMODULE crt=LoadLibraryW(L"msvcr90.dll"),cpp=LoadLibraryW(L"msvcp90.dll");
 if(!crt||!cpp){std::printf("FAIL VC90 load %lu\n",GetLastError());return 4;}
 using Copy=void*(__cdecl*)(void*,const void*,size_t);
 Copy copy=(Copy)GetProcAddress(crt,"memcpy");char buffer[16]={};
 if(!copy)return 5;copy(buffer,"VC90_API_OK",12);
 if(std::strcmp(buffer,"VC90_API_OK"))return 6;
 std::puts("PASS VC90 native CRT/C++ load and memcpy");
 DeactivateActCtx(0,cookie);ReleaseActCtx(handle);return 0;
}
