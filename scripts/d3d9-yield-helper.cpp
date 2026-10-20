// Universal D3D9 CPU spin yield and frame pacing helper.
// Relieves CPU starvation during screen transitions and busy-waits for D3D9 games on Metal.
// Strictly no authentication tokens, credentials, or sensitive inputs are inspected.
#define CINTERFACE
#include <windows.h>
#include <d3d9.h>
#include <cstddef>

static decltype(IDirect3DDevice9Vtbl::Present) oDevicePresent = nullptr;
static decltype(IDirect3DSwapChain9Vtbl::Present) oSwapChainPresent = nullptr;
static decltype(IDirect3DQuery9Vtbl::GetData) oGetData = nullptr;

static void **sDevicePresent = nullptr;
static void **sSwapChainPresent = nullptr;
static void **sGetData = nullptr;

static HRESULT WINAPI hDevicePresent(IDirect3DDevice9 *d, const RECT *a, const RECT *b, HWND w, const RGNDATA *r) {
    auto hr = oDevicePresent(d, a, b, w, r);
    Sleep(1);
    return hr;
}

static HRESULT WINAPI hSwapChainPresent(IDirect3DSwapChain9 *s, const RECT *a, const RECT *b, HWND w, const RGNDATA *r, DWORD f) {
    auto hr = oSwapChainPresent(s, a, b, w, r, f);
    Sleep(1);
    return hr;
}

static HRESULT WINAPI hGetData(IDirect3DQuery9 *q, void *p, DWORD n, DWORD f) {
    auto hr = oGetData(q, p, n, f);
    if (hr == S_FALSE) {
        Sleep(0);
    }
    return hr;
}

static bool replace(void **slot, void *from, void *to) {
    if (!slot || !from || !to) return false;
    DWORD old;
    if (!VirtualProtect(slot, sizeof(void*), PAGE_READWRITE, &old)) return false;
    auto got = InterlockedCompareExchangePointer(slot, to, from);
    DWORD ignored;
    VirtualProtect(slot, sizeof(void*), old, &ignored);
    return got == from;
}

static void restore(void **slot, void *hook, void *original) {
    if (slot && hook && original) replace(slot, hook, original);
}

static const wchar_t *candidate_modules[] = {
    L"macdeck_hmh_dxmt_clear_v2.dll",
    L"macdeck_dmc_dxmt_srgb_v4.dll",
    L"macdeck_dmc_dxmt_clear_v3.dll",
    L"macdeck_hmh_dxmt_v1.dll",
    L"macdeck_dmc_dxmt_v1.dll",
    L"d3d9.dll"
};

static bool install() {
    HMODULE m = nullptr;
    for (auto name : candidate_modules) {
        m = GetModuleHandleW(name);
        if (m) {
            auto dos = (IMAGE_DOS_HEADER*)m;
            auto nt = (IMAGE_NT_HEADERS*)((char*)m + dos->e_lfanew);
            if (dos->e_magic == IMAGE_DOS_SIGNATURE &&
                nt->OptionalHeader.Magic == IMAGE_NT_OPTIONAL_HDR32_MAGIC &&
                nt->FileHeader.TimeDateStamp == 0x6a85139a &&
                nt->OptionalHeader.SizeOfImage == 0x26a000) {
                break;
            }
            m = nullptr;
        }
    }
    if (!m) return false;

    // Device::Present vtable slot at offset 0x2515fc
    sDevicePresent = (void**)((char*)m + 0x2515fc);
    oDevicePresent = reinterpret_cast<decltype(oDevicePresent)>(*sDevicePresent);
    if (oDevicePresent) {
        replace(sDevicePresent, (void*)oDevicePresent, (void*)hDevicePresent);
    }

    // SwapChain::Present vtable slot at offset 0x251a10
    sSwapChainPresent = (void**)((char*)m + 0x251a10);
    oSwapChainPresent = reinterpret_cast<decltype(oSwapChainPresent)>(*sSwapChainPresent);
    if (oSwapChainPresent) {
        replace(sSwapChainPresent, (void*)oSwapChainPresent, (void*)hSwapChainPresent);
    }

    // Query::GetData vtable slot at offset 0x2515a0
    sGetData = (void**)((char*)m + 0x2515a0);
    oGetData = reinterpret_cast<decltype(oGetData)>(*sGetData);
    if (oGetData) {
        replace(sGetData, (void*)oGetData, (void*)hGetData);
    }

    return true;
}

static void uninstall() {
    restore(sDevicePresent, (void*)hDevicePresent, (void*)oDevicePresent);
    restore(sSwapChainPresent, (void*)hSwapChainPresent, (void*)oSwapChainPresent);
    restore(sGetData, (void*)hGetData, (void*)oGetData);
}

BOOL WINAPI DllMain(HINSTANCE h, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(h);
        return install();
    }
    if (reason == DLL_PROCESS_DETACH) {
        uninstall();
    }
    return TRUE;
}
