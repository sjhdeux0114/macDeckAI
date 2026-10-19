// Optional exact-game render counters. No screenshots, input, buffers or auth data.
#define CINTERFACE
#include <d3d9.h>
#include <cstddef>
static SRWLOCK dmcTraceLock=SRWLOCK_INIT;
static volatile LONG dmcFrames=0,dmcDraws=0,dmcQueries=0,dmcPending=0,dmcLastType=0,dmcLastTick=0;
static decltype(IDirect3D9Vtbl::CreateDevice) dmcCreateDeviceOriginal=nullptr;
static decltype(IDirect3DDevice9Vtbl::Present) dmcPresentOriginal=nullptr;
static decltype(IDirect3DDevice9Vtbl::DrawPrimitive) dmcDrawOriginal=nullptr;
static decltype(IDirect3DDevice9Vtbl::DrawIndexedPrimitive) dmcDrawIndexedOriginal=nullptr;
static decltype(IDirect3DDevice9Vtbl::DrawPrimitiveUP) dmcDrawUPOriginal=nullptr;
static decltype(IDirect3DDevice9Vtbl::DrawIndexedPrimitiveUP) dmcDrawIndexedUPOriginal=nullptr;
static decltype(IDirect3DDevice9Vtbl::CreateQuery) dmcCreateQueryOriginal=nullptr;
static decltype(IDirect3DQuery9Vtbl::GetData) dmcGetDataOriginal=nullptr;
static IDirect3D9 *(WINAPI *dmcCreate9Original)(UINT)=nullptr;
static void dmcTraceWrite(const char*extra=nullptr){
 DWORD now=GetTickCount(),old=(DWORD)dmcLastTick;
 if(!extra && now-old<1000)return;
 if(InterlockedCompareExchange(&dmcLastTick,(LONG)now,(LONG)old)!=(LONG)old)return;
 wchar_t path[180];swprintf(path,180,L"C:\\ProgramData\\MacDeck\\RendererSessions\\dmc-render-%lu.log",GetCurrentProcessId());
 HANDLE f=CreateFileW(path,FILE_APPEND_DATA,FILE_SHARE_READ|FILE_SHARE_WRITE,nullptr,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
 if(f==INVALID_HANDLE_VALUE)return;
 if(GetFileSize(f,nullptr)<65536){char line[400];int n=std::snprintf(line,sizeof(line),"tick=%lu frames=%ld draws=%ld queries=%ld pending=%ld lastQueryType=%ld %s\r\n",now,dmcFrames,dmcDraws,dmcQueries,dmcPending,dmcLastType,extra?extra:"");DWORD written;WriteFile(f,line,n,&written,nullptr);}CloseHandle(f);
}
template<typename F>static void dmcPatch(void* object,size_t slot,F hook,F&original){
 auto table=*reinterpret_cast<void***>(object);AcquireSRWLockExclusive(&dmcTraceLock);
 if(table[slot]!=reinterpret_cast<void*>(hook) && (!original || table[slot]==reinterpret_cast<void*>(original))){DWORD protect;
  if(VirtualProtect(table+slot,sizeof(void*),PAGE_READWRITE,&protect)){original=reinterpret_cast<F>(table[slot]);InterlockedExchangePointer(table+slot,reinterpret_cast<void*>(hook));DWORD ignored;VirtualProtect(table+slot,sizeof(void*),protect,&ignored);}
 }ReleaseSRWLockExclusive(&dmcTraceLock);
}
static HRESULT WINAPI dmcPresent(IDirect3DDevice9*d,const RECT*a,const RECT*b,HWND w,const RGNDATA*r){auto result=dmcPresentOriginal(d,a,b,w,r);InterlockedIncrement(&dmcFrames);dmcTraceWrite();return result;}
static HRESULT WINAPI dmcDraw(IDirect3DDevice9*d,D3DPRIMITIVETYPE t,UINT start,UINT count){InterlockedIncrement(&dmcDraws);dmcTraceWrite();return dmcDrawOriginal(d,t,start,count);}
static HRESULT WINAPI dmcDrawIndexed(IDirect3DDevice9*d,D3DPRIMITIVETYPE t,INT base,UINT min,UINT vertices,UINT start,UINT count){InterlockedIncrement(&dmcDraws);dmcTraceWrite();return dmcDrawIndexedOriginal(d,t,base,min,vertices,start,count);}
static HRESULT WINAPI dmcDrawUP(IDirect3DDevice9*d,D3DPRIMITIVETYPE t,UINT count,const void*data,UINT stride){InterlockedIncrement(&dmcDraws);dmcTraceWrite();return dmcDrawUPOriginal(d,t,count,data,stride);}
static HRESULT WINAPI dmcDrawIndexedUP(IDirect3DDevice9*d,D3DPRIMITIVETYPE t,UINT min,UINT vertices,UINT count,const void*indices,D3DFORMAT format,const void*data,UINT stride){InterlockedIncrement(&dmcDraws);dmcTraceWrite();return dmcDrawIndexedUPOriginal(d,t,min,vertices,count,indices,format,data,stride);}
static HRESULT WINAPI dmcGetData(IDirect3DQuery9*q,void*data,DWORD size,DWORD flags){HRESULT result=dmcGetDataOriginal(q,data,size,flags);InterlockedExchange(&dmcLastType,(LONG)q->lpVtbl->GetType(q));LONG n=InterlockedIncrement(&dmcQueries);if(result==S_FALSE)InterlockedIncrement(&dmcPending);if(!(n&4095))dmcTraceWrite();return result;}
static HRESULT WINAPI dmcCreateQuery(IDirect3DDevice9*d,D3DQUERYTYPE type,IDirect3DQuery9**q){HRESULT result=dmcCreateQueryOriginal(d,type,q);if(SUCCEEDED(result)&&q&&*q)dmcPatch(*q,offsetof(IDirect3DQuery9Vtbl,GetData)/sizeof(void*),dmcGetData,dmcGetDataOriginal);return result;}
static HRESULT WINAPI dmcCreateDevice(IDirect3D9*api,UINT adapter,D3DDEVTYPE type,HWND window,DWORD flags,D3DPRESENT_PARAMETERS*p,IDirect3DDevice9**out){
 HRESULT result=dmcCreateDeviceOriginal(api,adapter,type,window,flags,p,out);
 if(SUCCEEDED(result)&&out&&*out){auto d=*out;
#define DMC_PATCH(method,fn,original) dmcPatch(d,offsetof(IDirect3DDevice9Vtbl,method)/sizeof(void*),fn,original)
 DMC_PATCH(Present,dmcPresent,dmcPresentOriginal);DMC_PATCH(DrawPrimitive,dmcDraw,dmcDrawOriginal);DMC_PATCH(DrawIndexedPrimitive,dmcDrawIndexed,dmcDrawIndexedOriginal);DMC_PATCH(DrawPrimitiveUP,dmcDrawUP,dmcDrawUPOriginal);DMC_PATCH(DrawIndexedPrimitiveUP,dmcDrawIndexedUP,dmcDrawIndexedUPOriginal);DMC_PATCH(CreateQuery,dmcCreateQuery,dmcCreateQueryOriginal);
#undef DMC_PATCH
 dmcTraceWrite("device-created");}
 return result;
}
static IDirect3D9* WINAPI dmcTraceCreate9(UINT version){auto api=dmcCreate9Original(version);if(api)dmcPatch(api,offsetof(IDirect3D9Vtbl,CreateDevice)/sizeof(void*),dmcCreateDevice,dmcCreateDeviceOriginal);return api;}
