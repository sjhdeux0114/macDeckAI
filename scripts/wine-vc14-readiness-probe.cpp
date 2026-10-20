// Read-only VC14 loader/registry probe. No account or game data is accessed.
#include <windows.h>
#include <cstdio>
int main() {
    const char* names[] = {"msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll"};
    for (const char* name : names) {
        HMODULE module = LoadLibraryA(name);
        if (!module) { std::printf("FAIL load %s error=%lu\n", name, GetLastError()); return 1; }
        char path[MAX_PATH] = {};
        GetModuleFileNameA(module, path, MAX_PATH);
        std::printf("PASS load %s path=%s\n", name, path);
        FreeLibrary(module);
    }
    DWORD installed = 0, size = sizeof(installed);
    HKEY key = nullptr;
    LSTATUS status = RegOpenKeyExA(HKEY_LOCAL_MACHINE,
        "SOFTWARE\\Microsoft\\VisualStudio\\14.0\\VC\\Runtimes\\x64", 0,
        KEY_READ | KEY_WOW64_64KEY, &key);
    if (status == ERROR_SUCCESS) {
        DWORD type = 0;
        status = RegQueryValueExA(key, "Installed", nullptr, &type, reinterpret_cast<BYTE*>(&installed), &size);
        RegCloseKey(key);
        if (type != REG_DWORD) status = ERROR_INVALID_DATATYPE;
    }
    if (status != ERROR_SUCCESS || installed != 1) {
        std::printf("FAIL VC14 x64 registration status=%ld installed=%lu\n", status, installed); return 2;
    }
    std::puts("PASS VC14 x64 registered and all required DLLs load; gameplay unverified");
    return 0;
}
