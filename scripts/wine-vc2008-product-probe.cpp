#include <windows.h>
#include <msi.h>
#include <cstdio>
#include <cwchar>
int main() {
 wchar_t code[39];
 for (DWORD i=0; MsiEnumProductsW(i,code)==ERROR_SUCCESS; ++i) {
  wchar_t name[512]={};DWORD size=512;
  if(MsiGetProductInfoW(code,L"InstalledProductName",name,&size)!=ERROR_SUCCESS)continue;
  if(!wcsstr(name,L"Microsoft Visual C++ 2008") || !wcsstr(name,L"x86"))continue;
  std::printf("VC2008_X86_PRODUCT=%ls\n",code);
 }
 return 0;
}
