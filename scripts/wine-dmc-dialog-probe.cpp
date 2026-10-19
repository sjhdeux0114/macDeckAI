#include <windows.h>
#include <tlhelp32.h>
#include <cstdio>
#include <cwchar>
static DWORD game=0;
static void print(const wchar_t* text){char b[4096];if(WideCharToMultiByte(CP_UTF8,0,text,-1,b,sizeof(b),nullptr,nullptr))std::puts(b);}
static BOOL CALLBACK child(HWND w,LPARAM){wchar_t cls[128]={},text[2048]={};GetClassNameW(w,cls,128);if(!wcscmp(cls,L"Static")){GetWindowTextW(w,text,2048);if(*text)print(text);}return TRUE;}
static BOOL CALLBACK window(HWND w,LPARAM){DWORD p;GetWindowThreadProcessId(w,&p);if(p==game&&IsWindowVisible(w)){wchar_t title[512]={};GetWindowTextW(w,title,512);print(title);EnumChildWindows(w,child,0);}return TRUE;}
int main(){HANDLE s=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0);PROCESSENTRY32W p={};p.dwSize=sizeof(p);if(Process32FirstW(s,&p))do{if(!_wcsicmp(p.szExeFile,L"DMC-DevilMayCry.exe")){game=p.th32ProcessID;break;}}while(Process32NextW(s,&p));CloseHandle(s);if(!game)return 2;EnumWindows(window,0);return 0;}
