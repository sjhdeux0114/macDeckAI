// One explicit key, exact Hogwarts shipping executable, foreground verified.
#include <windows.h>
#include <cwchar>
#include <cstdio>
#include <cstring>
#include <cstdlib>
static HWND target=nullptr;
static DWORD gamePID=0;
static BOOL CALLBACK find(HWND window,LPARAM) {
    if(!IsWindowVisible(window)) return TRUE;
    DWORD pid=0;GetWindowThreadProcessId(window,&pid);
    HANDLE process=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,FALSE,pid);
    if(!process)return TRUE;
    wchar_t path[2048]={};DWORD length=2048;
    bool read=QueryFullProcessImageNameW(process,0,path,&length)!=0;CloseHandle(process);
    const wchar_t *suffix=L"\\Phoenix\\Binaries\\Win64\\HogwartsLegacy.exe";
    if(!read||length<wcslen(suffix)||_wcsicmp(path+length-wcslen(suffix),suffix))return TRUE;
    wchar_t title[256]={};GetWindowTextW(window,title,256);
    if(!wcsstr(title,L"Hogwarts Legacy"))return TRUE;
    target=window;gamePID=pid;return FALSE;
}
int main(int argc,char **argv) {
    if(argc!=2&&argc!=3)return 2;
    WORD key=!strcmp(argv[1],"enter")?VK_RETURN:!strcmp(argv[1],"space")?VK_SPACE:!strcmp(argv[1],"escape")?VK_ESCAPE:!strcmp(argv[1],"up")?VK_UP:!strcmp(argv[1],"down")?VK_DOWN:!strcmp(argv[1],"left")?'A':!strcmp(argv[1],"right")?'D':!strcmp(argv[1],"forward")?'W':!strcmp(argv[1],"back")?'S':0;
    DWORD hold=100;
    if(argc==3){char *end=nullptr;long value=strtol(argv[2],&end,10);if(!end||*end||value<50||value>1000)return 2;hold=(DWORD)value;}
    bool focusOnly=!strcmp(argv[1],"focus");
    bool character=!strcmp(argv[1],"character");
    bool closing=!strcmp(argv[1],"close");
    if(!key&&!focusOnly&&!character&&!closing)return 2;
    EnumWindows(find,0);if(!target){puts("Hogwarts shipping window not found");return 3;}
    if(closing)return PostMessageW(target,WM_CLOSE,0,0)?0:5;
    DWORD thread=GetWindowThreadProcessId(target,nullptr), helper=GetCurrentThreadId();
    bool attached=AttachThreadInput(helper,thread,TRUE)!=0;
    SetForegroundWindow(target);
    if(attached){SetActiveWindow(target);SetFocus(target);AttachThreadInput(helper,thread,FALSE);}
    Sleep(100);DWORD active=0;GetWindowThreadProcessId(GetForegroundWindow(),&active);
    if(active!=gamePID){puts("Refused: game does not own foreground");return 4;}
    if(focusOnly){puts("Hogwarts foreground confirmed; no input sent");return 0;}
    if(character){
        POINT point={200,90};if(!ClientToScreen(target,&point)||!SetCursorPos(point.x,point.y))return 5;
        INPUT click={};click.type=INPUT_MOUSE;click.mi.dwFlags=MOUSEEVENTF_LEFTDOWN;
        if(SendInput(1,&click,sizeof(click))!=1)return 5;
        Sleep(100);click.mi.dwFlags=MOUSEEVENTF_LEFTUP;
        return SendInput(1,&click,sizeof(click))==1?0:6;
    }
    INPUT input={};input.type=INPUT_KEYBOARD;input.ki.wScan=(WORD)MapVirtualKeyW(key,MAPVK_VK_TO_VSC);input.ki.dwFlags=KEYEVENTF_SCANCODE;
    if(SendInput(1,&input,sizeof(input))!=1)return 5;
    Sleep(hold);input.ki.dwFlags|=KEYEVENTF_KEYUP;
    UINT released=SendInput(1,&input,sizeof(input));
    printf("Hogwarts key %s released=%u\n",argv[1],released);return released==1?0:6;
}
