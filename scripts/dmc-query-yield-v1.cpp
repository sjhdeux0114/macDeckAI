// Exact DmC AppID220440 helper: yield only while an issued D3D9 query is pending.
#define CINTERFACE
#include <windows.h>
#include <d3d9.h>
#include <cstddef>
static decltype(IDirect3DQuery9Vtbl::GetData) original=nullptr;static void**slot=nullptr;
static HRESULT WINAPI hooked(IDirect3DQuery9*q,void*p,DWORD n,DWORD f){auto hr=original(q,p,n,f);if(hr==S_FALSE)Sleep(0);return hr;}
static bool replace(void*from,void*to){DWORD old;if(!VirtualProtect(slot,sizeof(void*),PAGE_READWRITE,&old))return false;auto got=InterlockedCompareExchangePointer(slot,to,from);DWORD ignored;VirtualProtect(slot,sizeof(void*),old,&ignored);return got==from;}
static bool install(){HMODULE m=GetModuleHandleW(L"macdeck_dmc_dxmt_srgb_v4.dll");if(!m)return false;auto dos=(IMAGE_DOS_HEADER*)m;auto nt=(IMAGE_NT_HEADERS*)((char*)m+dos->e_lfanew);if(dos->e_magic!=IMAGE_DOS_SIGNATURE||nt->OptionalHeader.Magic!=IMAGE_NT_OPTIONAL_HDR32_MAGIC||nt->FileHeader.TimeDateStamp!=0x6a85139a||nt->OptionalHeader.SizeOfImage!=0x26a000)return false;auto base=(void**)((char*)m+0x251580+8);slot=base+offsetof(IDirect3DQuery9Vtbl,GetData)/sizeof(void*);original=reinterpret_cast<decltype(original)>(*slot);MEMORY_BASIC_INFORMATION i{};if(!VirtualQuery((void*)original,&i,sizeof(i))||i.AllocationBase!=m)return false;return replace((void*)original,(void*)hooked);}
BOOL WINAPI DllMain(HINSTANCE,DWORD reason,LPVOID){if(reason==DLL_PROCESS_ATTACH)return install();if(reason==DLL_PROCESS_DETACH&&slot&&original)replace((void*)hooked,(void*)original);return TRUE;}
