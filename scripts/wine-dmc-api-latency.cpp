// DmC-only bounded D3D9 API latency counters. No inputs, resources, shaders or process memory are recorded.
#define CINTERFACE
#include <windows.h>
#include <d3d9.h>
#include <cstddef>
#include <cstdio>
#include <atomic>

struct Metric { std::atomic<unsigned long> count{0}, over1{0}, over5{0}, over10{0}, over33{0}; std::atomic<unsigned long long> total{0}, maximum{0}; };
static LARGE_INTEGER frequency{}; static std::atomic<long> done{0}; static HANDLE finished=nullptr;
static Metric mPresent,mDraw,mDrawIndexed,mDrawUP,mDrawIndexedUP,mCreateVS,mCreatePS,mCreateQuery,mIssue,mGetData;
static decltype(IDirect3DDevice9Vtbl::Present) oPresent=nullptr;
static decltype(IDirect3DDevice9Vtbl::DrawPrimitive) oDraw=nullptr;
static decltype(IDirect3DDevice9Vtbl::DrawIndexedPrimitive) oDrawIndexed=nullptr;
static decltype(IDirect3DDevice9Vtbl::DrawPrimitiveUP) oDrawUP=nullptr;
static decltype(IDirect3DDevice9Vtbl::DrawIndexedPrimitiveUP) oDrawIndexedUP=nullptr;
static decltype(IDirect3DDevice9Vtbl::CreateVertexShader) oCreateVS=nullptr;
static decltype(IDirect3DDevice9Vtbl::CreatePixelShader) oCreatePS=nullptr;
static decltype(IDirect3DDevice9Vtbl::CreateQuery) oCreateQuery=nullptr;
static decltype(IDirect3DQuery9Vtbl::Issue) oIssue=nullptr;
static decltype(IDirect3DQuery9Vtbl::GetData) oGetData=nullptr;
static void **sPresent,* *sDraw,* *sDrawIndexed,* *sDrawUP,* *sDrawIndexedUP,* *sCreateVS,* *sCreatePS,* *sCreateQuery,* *sIssue,* *sGetData;

static unsigned long long tick(){LARGE_INTEGER v;QueryPerformanceCounter(&v);return v.QuadPart;}
static void record(Metric&m,unsigned long long start){auto us=(tick()-start)*1000000ull/frequency.QuadPart;m.count++;m.total+=us;m.over1+=us>=1000;m.over5+=us>=5000;m.over10+=us>=10000;m.over33+=us>=33333;auto old=m.maximum.load();while(old<us&&!m.maximum.compare_exchange_weak(old,us)){} }
static HRESULT WINAPI hPresent(IDirect3DDevice9*d,const RECT*a,const RECT*b,HWND w,const RGNDATA*r){auto t=tick();auto hr=oPresent(d,a,b,w,r);record(mPresent,t);return hr;}
static HRESULT WINAPI hDraw(IDirect3DDevice9*d,D3DPRIMITIVETYPE a,UINT b,UINT c){auto t=tick();auto hr=oDraw(d,a,b,c);record(mDraw,t);return hr;}
static HRESULT WINAPI hDrawIndexed(IDirect3DDevice9*d,D3DPRIMITIVETYPE a,INT b,UINT c,UINT e,UINT f,UINT g){auto t=tick();auto hr=oDrawIndexed(d,a,b,c,e,f,g);record(mDrawIndexed,t);return hr;}
static HRESULT WINAPI hDrawUP(IDirect3DDevice9*d,D3DPRIMITIVETYPE a,UINT b,const void*c,UINT e){auto t=tick();auto hr=oDrawUP(d,a,b,c,e);record(mDrawUP,t);return hr;}
static HRESULT WINAPI hDrawIndexedUP(IDirect3DDevice9*d,D3DPRIMITIVETYPE a,UINT b,UINT c,UINT e,const void*f,D3DFORMAT g,const void*h,UINT i){auto t=tick();auto hr=oDrawIndexedUP(d,a,b,c,e,f,g,h,i);record(mDrawIndexedUP,t);return hr;}
static HRESULT WINAPI hCreateVS(IDirect3DDevice9*d,const DWORD*a,IDirect3DVertexShader9**b){auto t=tick();auto hr=oCreateVS(d,a,b);record(mCreateVS,t);return hr;}
static HRESULT WINAPI hCreatePS(IDirect3DDevice9*d,const DWORD*a,IDirect3DPixelShader9**b){auto t=tick();auto hr=oCreatePS(d,a,b);record(mCreatePS,t);return hr;}
static HRESULT WINAPI hCreateQuery(IDirect3DDevice9*d,D3DQUERYTYPE a,IDirect3DQuery9**b){auto t=tick();auto hr=oCreateQuery(d,a,b);record(mCreateQuery,t);return hr;}
static HRESULT WINAPI hIssue(IDirect3DQuery9*q,DWORD a){auto t=tick();auto hr=oIssue(q,a);record(mIssue,t);return hr;}
static HRESULT WINAPI hGetData(IDirect3DQuery9*q,void*a,DWORD b,DWORD c){auto t=tick();auto hr=oGetData(q,a,b,c);record(mGetData,t);return hr;}

static bool replace(void**slot,void*from,void*to){DWORD old;if(!VirtualProtect(slot,sizeof(void*),PAGE_READWRITE,&old))return false;auto got=InterlockedCompareExchangePointer(slot,to,from);DWORD ignored;VirtualProtect(slot,sizeof(void*),old,&ignored);return got==from;}
static void restore(void**slot,void*hook,void*original){if(slot&&hook&&original)replace(slot,hook,original);}
static void print(FILE*f,const char*n,Metric&m){auto c=m.count.load();fprintf(f,"%s count=%lu total_ms=%.3f mean_us=%.2f max_ms=%.3f over1=%lu over5=%lu over10=%lu over33=%lu\n",n,c,m.total.load()/1000.0,c?double(m.total.load())/c:0,m.maximum.load()/1000.0,m.over1.load(),m.over5.load(),m.over10.load(),m.over33.load());}
static void finish(){if(done.exchange(1))return;restore(sPresent,(void*)hPresent,(void*)oPresent);restore(sDraw,(void*)hDraw,(void*)oDraw);restore(sDrawIndexed,(void*)hDrawIndexed,(void*)oDrawIndexed);restore(sDrawUP,(void*)hDrawUP,(void*)oDrawUP);restore(sDrawIndexedUP,(void*)hDrawIndexedUP,(void*)oDrawIndexedUP);restore(sCreateVS,(void*)hCreateVS,(void*)oCreateVS);restore(sCreatePS,(void*)hCreatePS,(void*)oCreatePS);restore(sCreateQuery,(void*)hCreateQuery,(void*)oCreateQuery);restore(sIssue,(void*)hIssue,(void*)oIssue);restore(sGetData,(void*)hGetData,(void*)oGetData);FILE*f=fopen("C:\\ProgramData\\MacDeck\\RendererSessions\\dmc-api-latency.txt","w");if(f){fputs("status=complete duration_seconds=30\n",f);print(f,"Present",mPresent);print(f,"DrawPrimitive",mDraw);print(f,"DrawIndexedPrimitive",mDrawIndexed);print(f,"DrawPrimitiveUP",mDrawUP);print(f,"DrawIndexedPrimitiveUP",mDrawIndexedUP);print(f,"CreateVertexShader",mCreateVS);print(f,"CreatePixelShader",mCreatePS);print(f,"CreateQuery",mCreateQuery);print(f,"QueryIssue",mIssue);print(f,"QueryGetData",mGetData);fclose(f);}SetEvent(finished);}
static DWORD WINAPI watchdog(void*){Sleep(30000);finish();return 0;}
#define HOOK(base,type,name,hook,orig,slot) do{slot=(base)+offsetof(type,name)/sizeof(void*);orig=reinterpret_cast<decltype(orig)>(*slot);if(!replace(slot,(void*)orig,(void*)hook)){finish();return 4;}}while(0)
static DWORD WINAPI setup(void*){HMODULE module=GetModuleHandleW(L"macdeck_dmc_dxmt_srgb_v4.dll");if(!module)return 1;auto dos=(IMAGE_DOS_HEADER*)module;auto nt=(IMAGE_NT_HEADERS*)((char*)module+dos->e_lfanew);if(dos->e_magic!=IMAGE_DOS_SIGNATURE||nt->OptionalHeader.Magic!=IMAGE_NT_OPTIONAL_HDR32_MAGIC||nt->FileHeader.TimeDateStamp!=0x6a85139a||nt->OptionalHeader.SizeOfImage!=0x26a000)return 2;QueryPerformanceFrequency(&frequency);finished=CreateEventW(nullptr,TRUE,FALSE,nullptr);if(!finished)return 3;auto device=(void**)((char*)module+0x2515b0+8);auto query=(void**)((char*)module+0x251580+8);HOOK(device,IDirect3DDevice9Vtbl,Present,hPresent,oPresent,sPresent);HOOK(device,IDirect3DDevice9Vtbl,DrawPrimitive,hDraw,oDraw,sDraw);HOOK(device,IDirect3DDevice9Vtbl,DrawIndexedPrimitive,hDrawIndexed,oDrawIndexed,sDrawIndexed);HOOK(device,IDirect3DDevice9Vtbl,DrawPrimitiveUP,hDrawUP,oDrawUP,sDrawUP);HOOK(device,IDirect3DDevice9Vtbl,DrawIndexedPrimitiveUP,hDrawIndexedUP,oDrawIndexedUP,sDrawIndexedUP);HOOK(device,IDirect3DDevice9Vtbl,CreateVertexShader,hCreateVS,oCreateVS,sCreateVS);HOOK(device,IDirect3DDevice9Vtbl,CreatePixelShader,hCreatePS,oCreatePS,sCreatePS);HOOK(device,IDirect3DDevice9Vtbl,CreateQuery,hCreateQuery,oCreateQuery,sCreateQuery);HOOK(query,IDirect3DQuery9Vtbl,Issue,hIssue,oIssue,sIssue);HOOK(query,IDirect3DQuery9Vtbl,GetData,hGetData,oGetData,sGetData);HANDLE t=CreateThread(nullptr,0,watchdog,nullptr,0,nullptr);if(t)CloseHandle(t);else finish();return 0;}
BOOL WINAPI DllMain(HINSTANCE i,DWORD r,LPVOID){if(r==DLL_PROCESS_ATTACH){DisableThreadLibraryCalls(i);HANDLE t=CreateThread(nullptr,0,setup,nullptr,0,nullptr);if(t)CloseHandle(t);}return TRUE;}
