// DmC-only bounded Present timing. No GPU readback, inputs, shaders or auth data.
#define CINTERFACE
#include <windows.h>
#include <d3d9.h>
#include <cstddef>
#include <cstdio>
#include <algorithm>
static decltype(IDirect3DDevice9Vtbl::Present) original=nullptr;
static void**slot=nullptr;static SRWLOCK lock=SRWLOCK_INIT;static volatile LONG done=0;
static double intervals[1200]={};static unsigned count=0,failed=0;static LARGE_INTEGER frequency={},previous={};static HANDLE finished=nullptr;
static HRESULT WINAPI present(IDirect3DDevice9*,const RECT*,const RECT*,HWND,const RGNDATA*);
static void finish(){
 if(InterlockedCompareExchange(&done,1,0))return;
 DWORD old;if(VirtualProtect(slot,sizeof(void*),PAGE_READWRITE,&old)){InterlockedCompareExchangePointer(slot,reinterpret_cast<void*>(original),reinterpret_cast<void*>(present));DWORD ignored;VirtualProtect(slot,sizeof(void*),old,&ignored);}
 AcquireSRWLockExclusive(&lock);double sorted[1200];std::copy(intervals,intervals+count,sorted);std::sort(sorted,sorted+count);double sum=0;unsigned over33=0,over50=0,over100=0;for(unsigned i=0;i<count;i++){sum+=sorted[i];over33+=sorted[i]>33.333;over50+=sorted[i]>50;over100+=sorted[i]>100;}
 FILE*f=fopen("C:\\ProgramData\\MacDeck\\RendererSessions\\dmc-frame-timing.txt","w");if(f){fprintf(f,"status=complete samples=%u failed_present=%u mean_ms=%.3f p50_ms=%.3f p95_ms=%.3f p99_ms=%.3f max_ms=%.3f over33=%u over50=%u over100=%u submitted_present_fps=%.2f\n",count,failed,count?sum/count:0,count?sorted[(count-1)*50/100]:0,count?sorted[(count-1)*95/100]:0,count?sorted[(count-1)*99/100]:0,count?sorted[count-1]:0,over33,over50,over100,sum?count*1000/sum:0);fclose(f);}ReleaseSRWLockExclusive(&lock);SetEvent(finished);
}
static HRESULT WINAPI present(IDirect3DDevice9*d,const RECT*a,const RECT*b,HWND w,const RGNDATA*r){auto hr=original(d,a,b,w,r);if(done)return hr;LARGE_INTEGER now;QueryPerformanceCounter(&now);AcquireSRWLockExclusive(&lock);bool full=false;if(!done){if(FAILED(hr)){failed++;previous.QuadPart=0;}else{if(previous.QuadPart&&count<1200)intervals[count++]=double(now.QuadPart-previous.QuadPart)*1000/frequency.QuadPart;previous=now;}full=count==1200;}ReleaseSRWLockExclusive(&lock);if(full)finish();return hr;}
static DWORD WINAPI watchdog(void*){if(WaitForSingleObject(finished,30000)==WAIT_TIMEOUT)finish();return 0;}
static DWORD WINAPI setup(void*){
 HMODULE module=GetModuleHandleW(L"macdeck_dmc_dxmt_srgb_v4.dll");if(!module)return 1;auto dos=(IMAGE_DOS_HEADER*)module;auto nt=(IMAGE_NT_HEADERS*)((char*)module+dos->e_lfanew);if(dos->e_magic!=IMAGE_DOS_SIGNATURE||nt->OptionalHeader.Magic!=IMAGE_NT_OPTIONAL_HDR32_MAGIC||nt->FileHeader.TimeDateStamp!=0x6a85139a||nt->OptionalHeader.SizeOfImage!=0x26a000)return 2;
 slot=reinterpret_cast<void**>((char*)module+0x2515b0+8)+offsetof(IDirect3DDevice9Vtbl,Present)/sizeof(void*);original=reinterpret_cast<decltype(original)>(*slot);MEMORY_BASIC_INFORMATION fn={};if(!VirtualQuery(reinterpret_cast<void*>(original),&fn,sizeof(fn))||(fn.AllocationBase!=module&&fn.AllocationBase!=GetModuleHandleW(L"d3d9.dll")))return 3;
 QueryPerformanceFrequency(&frequency);finished=CreateEventW(nullptr,TRUE,FALSE,nullptr);if(!finished)return 4;DWORD old;if(!VirtualProtect(slot,sizeof(void*),PAGE_READWRITE,&old))return 5;InterlockedExchangePointer(slot,reinterpret_cast<void*>(present));DWORD ignored;VirtualProtect(slot,sizeof(void*),old,&ignored);HANDLE thread=CreateThread(nullptr,0,watchdog,nullptr,0,nullptr);if(thread)CloseHandle(thread);else finish();return 0;
}
BOOL WINAPI DllMain(HINSTANCE instance,DWORD reason,LPVOID){if(reason==DLL_PROCESS_ATTACH){DisableThreadLibraryCalls(instance);HANDLE thread=CreateThread(nullptr,0,setup,nullptr,0,nullptr);if(thread)CloseHandle(thread);}return TRUE;}
