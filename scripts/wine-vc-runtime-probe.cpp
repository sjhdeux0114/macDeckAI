// Read-only CRT loader/API check; accepts an optional side-by-side activation manifest.
#include <windows.h>
#include <cstdio>
#include <cstring>
int main(int argc,char **argv) {
    if(argc<4)return 2;
    ULONG_PTR cookie=0;HANDLE context=INVALID_HANDLE_VALUE;
    if(std::strcmp(argv[1],"-")) {
        ACTCTXA descriptor={};descriptor.cbSize=sizeof(descriptor);descriptor.lpSource=argv[1];
        context=CreateActCtxA(&descriptor);
        if(context==INVALID_HANDLE_VALUE||!ActivateActCtx(context,&cookie))return 3;
    }
    for(int i=2;i<argc;++i) {
        HMODULE module=LoadLibraryA(argv[i]);
        if(!module){std::printf("FAIL load %s error=%lu\n",argv[i],GetLastError());return 4;}
        if(i==2) {
            using Copy=void*(__cdecl*)(void*,const void*,size_t);
            Copy copy=reinterpret_cast<Copy>(GetProcAddress(module,"memcpy"));
            char buffer[32]={};if(!copy)return 5;copy(buffer,"NATIVE_CRT_API_OK",17);
            if(std::strcmp(buffer,"NATIVE_CRT_API_OK"))return 6;
        }
        std::printf("PASS load %s\n",argv[i]);
    }
    if(context!=INVALID_HANDLE_VALUE){DeactivateActCtx(0,cookie);ReleaseActCtx(context);}
    std::puts("PASS CRT native load and memcpy");return 0;
}
