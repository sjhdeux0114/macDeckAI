// One-shot DmC-only GPU surface capture, not a process-memory dump.
#define CINTERFACE
#include <windows.h>
#include <d3d9.h>
#include <cstddef>
#include <cstdio>
static decltype(IDirect3DDevice9Vtbl::Present) original=nullptr;
static void** slot=nullptr;
static volatile LONG captured=0;
static void writeStatus(const char* text){HANDLE f=CreateFileW(L"C:\\ProgramData\\MacDeck\\RendererSessions\\dmc-live-readback.txt",GENERIC_WRITE,FILE_SHARE_READ,nullptr,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);if(f!=INVALID_HANDLE_VALUE){DWORD n;WriteFile(f,text,(DWORD)strlen(text),&n,nullptr);CloseHandle(f);}}
static void restore(){DWORD old;if(VirtualProtect(slot,sizeof(void*),PAGE_READWRITE,&old)){InterlockedExchangePointer(slot,reinterpret_cast<void*>(original));DWORD ignored;VirtualProtect(slot,sizeof(void*),old,&ignored);}}
static HRESULT WINAPI present(IDirect3DDevice9*d,const RECT*a,const RECT*b,HWND window,const RGNDATA*data){
 if(InterlockedCompareExchange(&captured,1,0)==0){
  IDirect3DSurface9*gpu=nullptr,*cpu=nullptr;D3DSURFACE_DESC desc={};D3DLOCKED_RECT locked={};HRESULT hr=d->lpVtbl->GetBackBuffer(d,0,0,D3DBACKBUFFER_TYPE_MONO,&gpu);const char*stage="backbuffer";
  if(SUCCEEDED(hr)){stage="description";hr=gpu->lpVtbl->GetDesc(gpu,&desc);}
  if(SUCCEEDED(hr)&&(!desc.Width||!desc.Height||desc.Width>4096||desc.Height>4096))hr=E_INVALIDARG;
  if(SUCCEEDED(hr)){stage="staging";hr=d->lpVtbl->CreateOffscreenPlainSurface(d,desc.Width,desc.Height,desc.Format,D3DPOOL_SYSTEMMEM,&cpu,nullptr);}
  if(SUCCEEDED(hr)){stage="readback";hr=d->lpVtbl->GetRenderTargetData(d,gpu,cpu);}
  if(SUCCEEDED(hr)){stage="lock";hr=cpu->lpVtbl->LockRect(cpu,&locked,nullptr,D3DLOCK_READONLY);}
  unsigned nonblack=0;
  if(SUCCEEDED(hr)){
   if(desc.Format==D3DFMT_A8R8G8B8||desc.Format==D3DFMT_X8R8G8B8){
    BITMAPFILEHEADER f={};BITMAPINFOHEADER info={};info.biSize=sizeof(info);info.biWidth=desc.Width;info.biHeight=-LONG(desc.Height);info.biPlanes=1;info.biBitCount=32;info.biCompression=BI_RGB;info.biSizeImage=desc.Width*desc.Height*4;f.bfType=0x4d42;f.bfOffBits=sizeof(f)+sizeof(info);f.bfSize=f.bfOffBits+info.biSizeImage;
    HANDLE file=CreateFileW(L"C:\\ProgramData\\MacDeck\\RendererSessions\\dmc-live-backbuffer.bmp",GENERIC_WRITE,FILE_SHARE_READ,nullptr,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
    if(file!=INVALID_HANDLE_VALUE){DWORD n;WriteFile(file,&f,sizeof(f),&n,nullptr);WriteFile(file,&info,sizeof(info),&n,nullptr);for(UINT y=0;y<desc.Height;y++)WriteFile(file,(char*)locked.pBits+y*locked.Pitch,desc.Width*4,&n,nullptr);CloseHandle(file);}
    for(UINT y=0;y<25;y++)for(UINT x=0;x<25;x++){DWORD pixel=*(DWORD*)((char*)locked.pBits+(y*desc.Height/25)*locked.Pitch+(x*desc.Width/25)*4);if(pixel&0xffffff)nonblack++;}
   }
   cpu->lpVtbl->UnlockRect(cpu);stage="complete";
  }
  char status[250];std::snprintf(status,sizeof(status),"stage=%s hr=%08lx width=%u height=%u format=%u nonblack_grid=%u/625\n",stage,(unsigned long)hr,desc.Width,desc.Height,unsigned(desc.Format),nonblack);writeStatus(status);
  if(cpu)cpu->lpVtbl->Release(cpu);if(gpu)gpu->lpVtbl->Release(gpu);restore();
 }
 return original(d,a,b,window,data);
}
static DWORD WINAPI setup(void*){
 HMODULE module=GetModuleHandleW(L"macdeck_dmc_dxmt_clear_v3.dll");if(!module)module=GetModuleHandleW(L"macdeck_dmc_dxmt_v1.dll");if(!module){writeStatus("not DmC private Metal\n");return 1;}
 // Locked release v0.4-d3d9; caller additionally checks the complete SHA256.
 auto dos=reinterpret_cast<IMAGE_DOS_HEADER*>(module);auto nt=reinterpret_cast<IMAGE_NT_HEADERS*>((char*)module+dos->e_lfanew);
 if(dos->e_magic!=IMAGE_DOS_SIGNATURE||nt->OptionalHeader.Magic!=IMAGE_NT_OPTIONAL_HDR32_MAGIC||nt->FileHeader.TimeDateStamp!=0x6a85139a||nt->OptionalHeader.SizeOfImage!=0x26a000){writeStatus("wrong PE architecture\n");return 2;}
 slot=reinterpret_cast<void**>((char*)module+0x2515b0+8)+offsetof(IDirect3DDevice9Vtbl,Present)/sizeof(void*);
 MEMORY_BASIC_INFORMATION m={};if(!VirtualQuery(slot,&m,sizeof(m))||m.State!=MEM_COMMIT){writeStatus("invalid vtable\n");return 3;}
 original=reinterpret_cast<decltype(original)>(*slot);MEMORY_BASIC_INFORMATION fn={};if(!VirtualQuery(reinterpret_cast<void*>(original),&fn,sizeof(fn)) || (fn.AllocationBase!=module && fn.AllocationBase!=GetModuleHandleW(L"d3d9.dll"))){writeStatus("unexpected Present owner\n");return 4;}
 DWORD old;if(!VirtualProtect(slot,sizeof(void*),PAGE_READWRITE,&old)){writeStatus("vtable protection failed\n");return 5;}
 InterlockedExchangePointer(slot,reinterpret_cast<void*>(present));DWORD ignored;VirtualProtect(slot,sizeof(void*),old,&ignored);writeStatus("armed DmC one-shot backbuffer capture\n");return 0;
}
BOOL WINAPI DllMain(HINSTANCE instance,DWORD reason,LPVOID){if(reason==DLL_PROCESS_ATTACH){DisableThreadLibraryCalls(instance);HANDLE thread=CreateThread(nullptr,0,setup,nullptr,0,nullptr);if(thread)CloseHandle(thread);}return TRUE;}
