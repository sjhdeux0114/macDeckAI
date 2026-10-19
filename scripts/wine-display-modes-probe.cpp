#include <windows.h>
#include <cstdio>
#include <set>
#include <utility>
int main(){DEVMODEW m={};m.dmSize=sizeof(m);if(EnumDisplaySettingsW(nullptr,ENUM_CURRENT_SETTINGS,&m))printf("CURRENT %lux%lu %luHz\n",m.dmPelsWidth,m.dmPelsHeight,m.dmDisplayFrequency);std::set<std::pair<DWORD,DWORD>> modes;for(DWORD i=0;i<1000;i++){m={};m.dmSize=sizeof(m);if(!EnumDisplaySettingsW(nullptr,i,&m))break;modes.insert({m.dmPelsWidth,m.dmPelsHeight});}for(auto p:modes)printf("MODE %lux%lu\n",p.first,p.second);return 0;}
