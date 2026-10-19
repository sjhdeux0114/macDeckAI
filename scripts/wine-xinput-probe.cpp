#include <windows.h>
#include <xinput.h>
#include <cstdio>
int main(){auto m=LoadLibraryA("xinput1_4.dll");if(!m){printf("LOAD_FAIL %lu\n",GetLastError());return 1;}auto get=(DWORD(WINAPI*)(DWORD,XINPUT_STATE*))GetProcAddress(m,"XInputGetState");if(!get)return 2;for(int n=0;n<4;n++){for(DWORD i=0;i<4;i++){XINPUT_STATE s={};auto r=get(i,&s);printf("sample=%d slot=%lu result=%lu left=%d,%d right=%d,%d triggers=%u,%u buttons=%u\n",n,i,r,s.Gamepad.sThumbLX,s.Gamepad.sThumbLY,s.Gamepad.sThumbRX,s.Gamepad.sThumbRY,s.Gamepad.bLeftTrigger,s.Gamepad.bRightTrigger,s.Gamepad.wButtons);}Sleep(250);}return 0;}
