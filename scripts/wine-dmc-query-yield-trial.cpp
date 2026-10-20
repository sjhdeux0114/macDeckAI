// DmC-only 30-second query-poll yield trial. Restores the exact vtable slot automatically.
#define CINTERFACE
#include <windows.h>
#include <d3d9.h>
#include <cstddef>
#include <cstdio>
#include <atomic>
static decltype(IDirect3DQuery9Vtbl::GetData) original=nullptr;static void**slot=nullptr;static std::atomic<long>done{0};static std::atomic<unsigned long long>calls{0},pending{0},yields{0};
static HRESULT WINAPI hooked(IDirect3DQuery9*q,void*p,DWORD n,DWORD f){auto hr=original(q,p,n,f);calls++;if(hr==S_FALSE){pending++;Sleep(0);yields++;}return hr;}
static bool replace(void*from,void*to){DWORD old;if(!VirtualProtect(slot,sizeof(void*),PAGE_READWRITE,&old))return false;auto got=InterlockedCompareExchangePointer(slot,to,from);DWORD ignored;VirtualProtect(slot,sizeof(void*),old,&ignored);return got==from;}
static void finish(){if(done.exchange(1))return;replace((void*)hooked,(void*)original);FILE*f=fopen("C:\\ProgramData\\MacDeck\\RendererSessions\\dmc-query-yield.txt","w");if(f){fprintf(f,"status=complete seconds=30 calls=%llu pending=%llu yields=%llu restored=1\n",calls.load(),pending.load(),yields.load());fclose(f);}}
static DWORD WINAPI trial(void*){Sleep(30000);finish();return 0;}
static DWORD WINAPI setup(void*){HMODULE m=GetModuleHandleW(L"macdeck_dmc_dxmt_srgb_v4.dll");if(!m)return 1;auto dos=(IMAGE_DOS_HEADER*)m;auto nt=(IMAGE_NT_HEADERS*)((char*)m+dos->e_lfanew);if(dos->e_magic!=IMAGE_DOS_SIGNATURE||nt->OptionalHeader.Magic!=IMAGE_NT_OPTIONAL_HDR32_MAGIC||nt->FileHeader.TimeDateStamp!=0x6a85139a||nt->OptionalHeader.SizeOfImage!=0x26a000)return 2;auto base=(void**)((char*)m+0x251580+8);slot=base+offsetof(IDirect3DQuery9Vtbl,GetData)/sizeof(void*);original=reinterpret_cast<decltype(original)>(*slot);MEMORY_BASIC_INFORMATION i{};if(!VirtualQuery((void*)original,&i,sizeof(i))||i.AllocationBase!=m)return 3;if(!replace((void*)original,(void*)hooked))return 4;HANDLE t=CreateThread(nullptr,0,trial,nullptr,0,nullptr);if(t)CloseHandle(t);else finish();return 0;}
BOOL WINAPI DllMain(HINSTANCE i,DWORD r,LPVOID){if(r==DLL_PROCESS_ATTACH){DisableThreadLibraryCalls(i);HANDLE t=CreateThread(nullptr,0,setup,nullptr,0,nullptr);if(t)CloseHandle(t);}return TRUE;}
