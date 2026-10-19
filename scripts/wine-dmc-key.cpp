// Sends one explicit game key only when the exact DmC game owns foreground.
#include <windows.h>
#include <tlhelp32.h>
#include <cwchar>
#include <cstdio>
static DWORD game=0;static HWND window=nullptr;
static BOOL CALLBACK find(HWND w,LPARAM){DWORD pid;GetWindowThreadProcessId(w,&pid);wchar_t title[256]={};GetWindowTextW(w,title,256);if(pid==game&&IsWindowVisible(w)&&!wcsncmp(title,L"DMC-DevilMayCry",14)){window=w;return FALSE;}return TRUE;}
int main(int argc,char**argv){if(argc!=2)return 2;WORD key=!strcmp(argv[1],"enter")?VK_RETURN:!strcmp(argv[1],"escape")?VK_ESCAPE:!strcmp(argv[1],"down")?VK_DOWN:!strcmp(argv[1],"up")?VK_UP:!strcmp(argv[1],"backspace")?VK_BACK:!strcmp(argv[1],"space")?VK_SPACE:0;if(!key)return 2;
 HANDLE s=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0);PROCESSENTRY32W p={};p.dwSize=sizeof(p);if(Process32FirstW(s,&p))do{if(!_wcsicmp(p.szExeFile,L"DMC-DevilMayCry.exe")){game=p.th32ProcessID;break;}}while(Process32NextW(s,&p));CloseHandle(s);if(!game)return 3;EnumWindows(find,0);if(!window)return 4;
 SetForegroundWindow(window);Sleep(100);DWORD active=0;GetWindowThreadProcessId(GetForegroundWindow(),&active);if(active!=game){puts("Refused: DmC does not own foreground");return 5;}
 INPUT in={};in.type=INPUT_KEYBOARD;in.ki.wVk=key;in.ki.wScan=(WORD)MapVirtualKeyW(key,MAPVK_VK_TO_VSC);if(SendInput(1,&in,sizeof(in))!=1)return 6;Sleep(100);in.ki.dwFlags=KEYEVENTF_KEYUP;UINT count=SendInput(1,&in,sizeof(in));printf("DmC key %s released=%u\n",argv[1],count);return count==1?0:7;
}
