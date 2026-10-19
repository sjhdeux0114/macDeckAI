// DmC-only instruction-pointer sampling; no memory reads/dumps or Steam inspection.
#include <windows.h>
#include <tlhelp32.h>
#include <cstdio>
#include <cwchar>
#include <vector>
#include <algorithm>
struct Thread {DWORD id; ULONGLONG previous;};
struct Module {uintptr_t base,end; wchar_t name[256];};
static ULONGLONG cpu(HANDLE h){FILETIME a,b,k,u;if(!GetThreadTimes(h,&a,&b,&k,&u))return 0;ULARGE_INTEGER x,y;x.LowPart=k.dwLowDateTime;x.HighPart=k.dwHighDateTime;y.LowPart=u.dwLowDateTime;y.HighPart=u.dwHighDateTime;return x.QuadPart+y.QuadPart;}
int main(){
 DWORD game=0; HANDLE s=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0);PROCESSENTRY32W p={};p.dwSize=sizeof(p);
 if(Process32FirstW(s,&p))do{if(!_wcsicmp(p.szExeFile,L"DMC-DevilMayCry.exe")){game=p.th32ProcessID;break;}}while(Process32NextW(s,&p));CloseHandle(s);if(!game)return 2;
 std::vector<Module> modules;s=CreateToolhelp32Snapshot(TH32CS_SNAPMODULE,game);MODULEENTRY32W m={};m.dwSize=sizeof(m);
 if(Module32FirstW(s,&m))do{Module item={};item.base=(uintptr_t)m.modBaseAddr;item.end=item.base+m.modBaseSize;wcsncpy(item.name,m.szModule,255);modules.push_back(item);}while(Module32NextW(s,&m));CloseHandle(s);
 std::vector<Thread> threads;s=CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD,0);THREADENTRY32 t={};t.dwSize=sizeof(t);
 if(Thread32First(s,&t))do{if(t.th32OwnerProcessID==game){HANDLE h=OpenThread(THREAD_QUERY_INFORMATION,FALSE,t.th32ThreadID);if(h){threads.push_back({t.th32ThreadID,cpu(h)});CloseHandle(h);}}}while(Thread32Next(s,&t));CloseHandle(s);
 printf("threads=%u modules=%u\n",unsigned(threads.size()),unsigned(modules.size()));
 for(int pass=0;pass<4;pass++){
  Sleep(200);
  for(auto &t:threads){HANDLE h=OpenThread(THREAD_QUERY_INFORMATION|THREAD_GET_CONTEXT|THREAD_SUSPEND_RESUME,FALSE,t.id);if(!h)continue;ULONGLONG now=cpu(h),delta=now-t.previous;t.previous=now;
   if((pass<2 || delta>=100000) && SuspendThread(h)!=DWORD(-1)){
    CONTEXT c={};c.ContextFlags=CONTEXT_CONTROL;BOOL ok=GetThreadContext(h,&c);DWORD err=GetLastError();ResumeThread(h);if(!ok && pass==0)printf("context error=%lu\n",err);
    if(ok){const Module* found=nullptr;for(auto &m:modules)if(c.Eip>=m.base&&c.Eip<m.end){found=&m;break;}char name[768]={};if(found)WideCharToMultiByte(CP_UTF8,0,found->name,-1,name,sizeof(name),nullptr,nullptr);
     printf("sample=%d tid=%lu cpu_ms=%llu module=%s rva=%08lx ip=%08lx\n",pass,t.id,delta/10000,found?name:"unknown",found?DWORD(c.Eip-found->base):0UL,c.Eip);
    }
   }CloseHandle(h);
  }
 }
 return 0;
}
