// Loads one owned diagnostic module into exact DmC process only.
#include <windows.h>
#include <tlhelp32.h>
#include <cwchar>
#include <cstdio>
int wmain(int argc,wchar_t**argv){if(argc!=2)return 2;DWORD game=0;HANDLE s=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0);PROCESSENTRY32W p={};p.dwSize=sizeof(p);if(Process32FirstW(s,&p))do{if(!_wcsicmp(p.szExeFile,L"DMC-DevilMayCry.exe")){game=p.th32ProcessID;break;}}while(Process32NextW(s,&p));CloseHandle(s);if(!game)return 3;
 FARPROC loader=GetProcAddress(GetModuleHandleW(L"kernel32.dll"),"LoadLibraryW");MEMORY_BASIC_INFORMATION info={};VirtualQuery(reinterpret_cast<void*>(loader),&info,sizeof(info));wchar_t localName[MAX_PATH]={};GetModuleFileNameW((HMODULE)info.AllocationBase,localName,MAX_PATH);wchar_t*base=wcsrchr(localName,L'\\');base=base?base+1:localName;
 uintptr_t remoteBase=0;s=CreateToolhelp32Snapshot(TH32CS_SNAPMODULE,game);MODULEENTRY32W m={};m.dwSize=sizeof(m);if(Module32FirstW(s,&m))do{if(!_wcsicmp(m.szModule,base)){remoteBase=(uintptr_t)m.modBaseAddr;break;}}while(Module32NextW(s,&m));CloseHandle(s);if(!remoteBase)return 4;
 HANDLE process=OpenProcess(PROCESS_CREATE_THREAD|PROCESS_QUERY_INFORMATION|PROCESS_VM_OPERATION|PROCESS_VM_WRITE,FALSE,game);if(!process)return 5;
 SIZE_T bytes=(wcslen(argv[1])+1)*sizeof(wchar_t);void*arg=VirtualAllocEx(process,nullptr,bytes,MEM_COMMIT|MEM_RESERVE,PAGE_READWRITE);if(!arg||!WriteProcessMemory(process,arg,argv[1],bytes,nullptr))return 6;
 auto entry=(LPTHREAD_START_ROUTINE)(remoteBase+(uintptr_t)loader-(uintptr_t)info.AllocationBase);HANDLE thread=CreateRemoteThread(process,nullptr,0,entry,arg,0,nullptr);if(!thread)return 7;
 DWORD wait=WaitForSingleObject(thread,5000),result=0;if(wait==WAIT_OBJECT_0){GetExitCodeThread(thread,&result);VirtualFreeEx(process,arg,0,MEM_RELEASE);}CloseHandle(thread);CloseHandle(process);printf("DmC-only diagnostic load wait=%lu module=%08lx\n",wait,result);return result?0:8;
}
