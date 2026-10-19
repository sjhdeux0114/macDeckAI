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

static FILE* report=nullptr;static unsigned draws=0,rtchanges=0,failures=0,samples=0;static bool active=false;
static decltype(IDirect3DDevice9Vtbl::Clear) clearOrig;
static decltype(IDirect3DDevice9Vtbl::DrawIndexedPrimitive) drawOrig;
static decltype(IDirect3DDevice9Vtbl::DrawPrimitiveUP) upOrig;
static decltype(IDirect3DDevice9Vtbl::SetRenderTarget) rtOrig;
static decltype(IDirect3DDevice9Vtbl::StretchRect) stretchOrig;
static void setslot(size_t i,void*p){DWORD o;void**t=slot-17;if(VirtualProtect(t+i,sizeof(void*),PAGE_READWRITE,&o)){InterlockedExchangePointer(t+i,p);DWORD q;VirtualProtect(t+i,sizeof(void*),o,&q);}}
static void sampleRT(IDirect3DDevice9*d){
 if(samples++>=32)return;IDirect3DSurface9*g=nullptr,*c=nullptr;D3DSURFACE_DESC ds={};D3DLOCKED_RECT l={};
 HRESULT h=d->lpVtbl->GetRenderTarget(d,0,&g);if(SUCCEEDED(h))h=g->lpVtbl->GetDesc(g,&ds);
 if(SUCCEEDED(h))h=d->lpVtbl->CreateOffscreenPlainSurface(d,ds.Width,ds.Height,ds.Format,D3DPOOL_SYSTEMMEM,&c,nullptr);
 if(SUCCEEDED(h))h=d->lpVtbl->GetRenderTargetData(d,g,c);
 if(SUCCEEDED(h))h=c->lpVtbl->LockRect(c,&l,nullptr,D3DLOCK_READONLY);
 unsigned n=0;if(SUCCEEDED(h)){unsigned bytes=ds.Format==D3DFMT_A16B16G16R16F?8:4;for(unsigned y=0;y<10;y++)for(unsigned x=0;x<10;x++){auto p=(unsigned char*)l.pBits+(y*ds.Height/10)*l.Pitch+(x*ds.Width/10)*bytes;for(unsigned k=0;k<(bytes==4?3:6);k++)if(p[k]){n++;break;}}c->lpVtbl->UnlockRect(c);}
 if(report)fprintf(report,"RTsample draw=%u w=%u h=%u fmt=%u ms=%u hr=%08lx nonzero=%u/100\n",draws,ds.Width,ds.Height,unsigned(ds.Format),unsigned(ds.MultiSampleType),(unsigned long)h,n);
 if(c)c->lpVtbl->Release(c);if(g)g->lpVtbl->Release(g);
}
static HRESULT WINAPI auditClear(IDirect3DDevice9*d,DWORD n,const D3DRECT*r,DWORD flags,D3DCOLOR color,float z,DWORD stencil){if(active){D3DVIEWPORT9 vp={};d->lpVtbl->GetViewport(d,&vp);IDirect3DSurface9*ds=nullptr;D3DSURFACE_DESC desc={};if(SUCCEEDED(d->lpVtbl->GetDepthStencilSurface(d,&ds))){ds->lpVtbl->GetDesc(ds,&desc);ds->lpVtbl->Release(ds);}fprintf(report,"Clear draw=%u flags=%lu z=%f nrect=%lu viewport=%lu,%lu,%lu,%lu DS=%u,%u,%u\n",draws,flags,z,n,vp.X,vp.Y,vp.Width,vp.Height,desc.Width,desc.Height,unsigned(desc.Format));}return clearOrig(d,n,r,flags,color,z,stencil);}
static HRESULT WINAPI auditDraw(IDirect3DDevice9*d,D3DPRIMITIVETYPE t,INT base,UINT min,UINT v,UINT start,UINT count){if(active && draws<100){IDirect3DVertexShader9*vs=nullptr;IDirect3DPixelShader9*ps=nullptr;d->lpVtbl->GetVertexShader(d,&vs);d->lpVtbl->GetPixelShader(d,&ps);UINT vsbytes=0,psbytes=0;if(vs)vs->lpVtbl->GetFunction(vs,nullptr,&vsbytes);if(ps)ps->lpVtbl->GetFunction(ps,nullptr,&psbytes);D3DVIEWPORT9 vp={};d->lpVtbl->GetViewport(d,&vp);DWORD zf=0;d->lpVtbl->GetRenderState(d,D3DRS_ZFUNC,&zf);DWORD z=0,zw=0,cull=0,mask=0,sc=0;d->lpVtbl->GetRenderState(d,D3DRS_ZENABLE,&z);d->lpVtbl->GetRenderState(d,D3DRS_ZWRITEENABLE,&zw);d->lpVtbl->GetRenderState(d,D3DRS_CULLMODE,&cull);d->lpVtbl->GetRenderState(d,D3DRS_COLORWRITEENABLE,&mask);d->lpVtbl->GetRenderState(d,D3DRS_SCISSORTESTENABLE,&sc);fprintf(report,"draw=%u tris=%u vs=%u ps=%u viewport=%lu,%lu,%lu,%lu zf=%lu z=%lu zw=%lu cull=%lu mask=%lu sc=%lu\n",draws,count,vsbytes,psbytes,vp.X,vp.Y,vp.Width,vp.Height,zf,z,zw,cull,mask,sc);if(vs)vs->lpVtbl->Release(vs);if(ps)ps->lpVtbl->Release(ps);}auto h=drawOrig(d,t,base,min,v,start,count);if(active){draws++;if(FAILED(h)&&failures++<64)fprintf(report,"DrawIndexed hr=%08lx count=%u\n",(unsigned long)h,count);}return h;}
static HRESULT WINAPI auditUP(IDirect3DDevice9*d,D3DPRIMITIVETYPE t,UINT count,const void*p,UINT stride){auto h=upOrig(d,t,count,p,stride);if(active){draws++;if(FAILED(h)&&failures++<64)fprintf(report,"DrawUP hr=%08lx\n",(unsigned long)h);}return h;}
static HRESULT WINAPI auditRT(IDirect3DDevice9*d,DWORD i,IDirect3DSurface9*s){if(active&&i==0){rtchanges++;sampleRT(d);}auto h=rtOrig(d,i,s);if(active&&FAILED(h)&&failures++<64)fprintf(report,"SetRT hr=%08lx i=%lu\n",(unsigned long)h,i);return h;}
static HRESULT WINAPI auditStretch(IDirect3DDevice9*d,IDirect3DSurface9*a,const RECT*b,IDirect3DSurface9*c,const RECT*e,D3DTEXTUREFILTERTYPE f){auto h=stretchOrig(d,a,b,c,e,f);if(active&&FAILED(h)&&failures++<64)fprintf(report,"Stretch hr=%08lx\n",(unsigned long)h);return h;}
static HRESULT WINAPI present(IDirect3DDevice9*d,const RECT*a,const RECT*b,HWND w,const RGNDATA*r){
 if(!active){report=fopen("C:\\ProgramData\\MacDeck\\RendererSessions\\dmc-frame-audit.txt","w");active=report!=nullptr;}
 else{sampleRT(d);fprintf(report,"complete draws=%u rtchanges=%u failures=%u\n",draws,rtchanges,failures);fclose(report);report=nullptr;active=false;
#define RESTORE(m,fn) setslot(offsetof(IDirect3DDevice9Vtbl,m)/sizeof(void*),reinterpret_cast<void*>(fn))
 RESTORE(Clear,clearOrig);RESTORE(DrawIndexedPrimitive,drawOrig);RESTORE(DrawPrimitiveUP,upOrig);RESTORE(SetRenderTarget,rtOrig);RESTORE(StretchRect,stretchOrig);restore();writeStatus("complete frame audit restored\n");
 }
 return original(d,a,b,w,r);
}
static DWORD WINAPI setup(void*){
 HMODULE module=GetModuleHandleW(L"macdeck_dmc_dxmt_v1.dll");if(!module){writeStatus("not DmC private Metal\n");return 1;}
 // Locked release v0.4-d3d9; caller additionally checks the complete SHA256.
 auto dos=reinterpret_cast<IMAGE_DOS_HEADER*>(module);auto nt=reinterpret_cast<IMAGE_NT_HEADERS*>((char*)module+dos->e_lfanew);
 if(dos->e_magic!=IMAGE_DOS_SIGNATURE||nt->OptionalHeader.Magic!=IMAGE_NT_OPTIONAL_HDR32_MAGIC||nt->FileHeader.TimeDateStamp!=0x6a85139a||nt->OptionalHeader.SizeOfImage!=0x26a000){writeStatus("wrong PE architecture\n");return 2;}
 slot=reinterpret_cast<void**>((char*)module+0x2515b0+8)+offsetof(IDirect3DDevice9Vtbl,Present)/sizeof(void*);
 MEMORY_BASIC_INFORMATION m={};if(!VirtualQuery(slot,&m,sizeof(m))||m.State!=MEM_COMMIT){writeStatus("invalid vtable\n");return 3;}
 original=reinterpret_cast<decltype(original)>(*slot);MEMORY_BASIC_INFORMATION fn={};if(!VirtualQuery(reinterpret_cast<void*>(original),&fn,sizeof(fn)) || (fn.AllocationBase!=module && fn.AllocationBase!=GetModuleHandleW(L"d3d9.dll"))){writeStatus("unexpected Present owner\n");return 4;}
 DWORD old;if(!VirtualProtect(slot,sizeof(void*),PAGE_READWRITE,&old)){writeStatus("vtable protection failed\n");return 5;}

#define HOOK(m,fn,orig) orig=reinterpret_cast<decltype(orig)>((slot-17)[offsetof(IDirect3DDevice9Vtbl,m)/sizeof(void*)]);setslot(offsetof(IDirect3DDevice9Vtbl,m)/sizeof(void*),reinterpret_cast<void*>(fn))
 HOOK(Clear,auditClear,clearOrig);HOOK(DrawIndexedPrimitive,auditDraw,drawOrig);HOOK(DrawPrimitiveUP,auditUP,upOrig);HOOK(SetRenderTarget,auditRT,rtOrig);HOOK(StretchRect,auditStretch,stretchOrig);
InterlockedExchangePointer(slot,reinterpret_cast<void*>(present));DWORD ignored;VirtualProtect(slot,sizeof(void*),old,&ignored);writeStatus("armed DmC one-shot backbuffer capture\n");return 0;
}
BOOL WINAPI DllMain(HINSTANCE instance,DWORD reason,LPVOID){if(reason==DLL_PROCESS_ATTACH){DisableThreadLibraryCalls(instance);HANDLE thread=CreateThread(nullptr,0,setup,nullptr,0,nullptr);if(thread)CloseHandle(thread);}return TRUE;}
