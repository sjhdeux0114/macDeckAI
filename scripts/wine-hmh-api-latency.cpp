// HMH-only bounded D3D9 API latency and frame interval profiler.
// Measures execution times of D3D9 API calls and frame intervals to isolate screen transition stutter.
// Strictly no authentication tokens, credentials, or sensitive inputs are inspected.
#define CINTERFACE
#include <windows.h>
#include <d3d9.h>
#include <cstddef>
#include <cstdio>
#include <atomic>
#include <algorithm>

struct Metric {
    std::atomic<unsigned long> count{0}, over1{0}, over5{0}, over10{0}, over33{0}, over100{0};
    std::atomic<unsigned long long> total_us{0}, max_us{0};
};

static LARGE_INTEGER frequency{};
static std::atomic<long> done{0};
static HANDLE finished = nullptr;

static Metric mPresent, mReset, mClear, mCreateTexture, mSetRenderTarget;
static Metric mDraw, mDrawIndexed, mDrawUP, mDrawIndexedUP;
static Metric mCreateVS, mCreatePS, mCreateQuery, mIssue, mGetData;

// Frame interval tracking
static const unsigned MAX_SAMPLES = 2400;
static double intervals[MAX_SAMPLES] = {};
static unsigned interval_count = 0;
static LARGE_INTEGER last_present_time{};
static SRWLOCK interval_lock = SRWLOCK_INIT;

static decltype(IDirect3DDevice9Vtbl::Present) oPresent = nullptr;
static decltype(IDirect3DDevice9Vtbl::Reset) oReset = nullptr;
static decltype(IDirect3DDevice9Vtbl::Clear) oClear = nullptr;
static decltype(IDirect3DDevice9Vtbl::CreateTexture) oCreateTexture = nullptr;
static decltype(IDirect3DDevice9Vtbl::SetRenderTarget) oSetRenderTarget = nullptr;
static decltype(IDirect3DDevice9Vtbl::DrawPrimitive) oDraw = nullptr;
static decltype(IDirect3DDevice9Vtbl::DrawIndexedPrimitive) oDrawIndexed = nullptr;
static decltype(IDirect3DDevice9Vtbl::DrawPrimitiveUP) oDrawUP = nullptr;
static decltype(IDirect3DDevice9Vtbl::DrawIndexedPrimitiveUP) oDrawIndexedUP = nullptr;
static decltype(IDirect3DDevice9Vtbl::CreateVertexShader) oCreateVS = nullptr;
static decltype(IDirect3DDevice9Vtbl::CreatePixelShader) oCreatePS = nullptr;
static decltype(IDirect3DDevice9Vtbl::CreateQuery) oCreateQuery = nullptr;
static decltype(IDirect3DQuery9Vtbl::Issue) oIssue = nullptr;
static decltype(IDirect3DQuery9Vtbl::GetData) oGetData = nullptr;

static void **sPresent, **sReset, **sClear, **sCreateTexture, **sSetRenderTarget;
static void **sDraw, **sDrawIndexed, **sDrawUP, **sDrawIndexedUP;
static void **sCreateVS, **sCreatePS, **sCreateQuery, **sIssue, **sGetData;

static unsigned long long tick() {
    LARGE_INTEGER v;
    QueryPerformanceCounter(&v);
    return v.QuadPart;
}

static void record(Metric &m, unsigned long long start) {
    auto us = (tick() - start) * 1000000ull / frequency.QuadPart;
    m.count++;
    m.total_us += us;
    m.over1 += us >= 1000;
    m.over5 += us >= 5000;
    m.over10 += us >= 10000;
    m.over33 += us >= 33333;
    m.over100 += us >= 100000;
    auto old = m.max_us.load();
    while (old < us && !m.max_us.compare_exchange_weak(old, us)) {}
}

static HRESULT WINAPI hPresent(IDirect3DDevice9 *d, const RECT *a, const RECT *b, HWND w, const RGNDATA *r) {
    LARGE_INTEGER now;
    QueryPerformanceCounter(&now);

    AcquireSRWLockExclusive(&interval_lock);
    if (last_present_time.QuadPart != 0 && interval_count < MAX_SAMPLES) {
        double ms = double(now.QuadPart - last_present_time.QuadPart) * 1000.0 / frequency.QuadPart;
        intervals[interval_count++] = ms;
    }
    last_present_time = now;
    ReleaseSRWLockExclusive(&interval_lock);

    auto t = tick();
    auto hr = oPresent(d, a, b, w, r);
    record(mPresent, t);
    return hr;
}

static HRESULT WINAPI hReset(IDirect3DDevice9 *d, D3DPRESENT_PARAMETERS *p) {
    auto t = tick();
    auto hr = oReset(d, p);
    record(mReset, t);
    return hr;
}

static HRESULT WINAPI hClear(IDirect3DDevice9 *d, DWORD count, const D3DRECT *r, DWORD f, D3DCOLOR c, float z, DWORD s) {
    auto t = tick();
    auto hr = oClear(d, count, r, f, c, z, s);
    record(mClear, t);
    return hr;
}

static HRESULT WINAPI hCreateTexture(IDirect3DDevice9 *d, UINT w, UINT h, UINT l, DWORD u, D3DFORMAT fmt, D3DPOOL pool, IDirect3DTexture9 **tex, HANDLE *sh) {
    auto t = tick();
    auto hr = oCreateTexture(d, w, h, l, u, fmt, pool, tex, sh);
    record(mCreateTexture, t);
    return hr;
}

static HRESULT WINAPI hSetRenderTarget(IDirect3DDevice9 *d, DWORD idx, IDirect3DSurface9 *s) {
    auto t = tick();
    auto hr = oSetRenderTarget(d, idx, s);
    record(mSetRenderTarget, t);
    return hr;
}

static HRESULT WINAPI hDraw(IDirect3DDevice9 *d, D3DPRIMITIVETYPE a, UINT b, UINT c) {
    auto t = tick();
    auto hr = oDraw(d, a, b, c);
    record(mDraw, t);
    return hr;
}

static HRESULT WINAPI hDrawIndexed(IDirect3DDevice9 *d, D3DPRIMITIVETYPE a, INT b, UINT c, UINT e, UINT f, UINT g) {
    auto t = tick();
    auto hr = oDrawIndexed(d, a, b, c, e, f, g);
    record(mDrawIndexed, t);
    return hr;
}

static HRESULT WINAPI hDrawUP(IDirect3DDevice9 *d, D3DPRIMITIVETYPE a, UINT b, const void *c, UINT e) {
    auto t = tick();
    auto hr = oDrawUP(d, a, b, c, e);
    record(mDrawUP, t);
    return hr;
}

static HRESULT WINAPI hDrawIndexedUP(IDirect3DDevice9 *d, D3DPRIMITIVETYPE a, UINT b, UINT c, UINT e, const void *f, D3DFORMAT g, const void *h, UINT i) {
    auto t = tick();
    auto hr = oDrawIndexedUP(d, a, b, c, e, f, g, h, i);
    record(mDrawIndexedUP, t);
    return hr;
}

static HRESULT WINAPI hCreateVS(IDirect3DDevice9 *d, const DWORD *a, IDirect3DVertexShader9 **b) {
    auto t = tick();
    auto hr = oCreateVS(d, a, b);
    record(mCreateVS, t);
    return hr;
}

static HRESULT WINAPI hCreatePS(IDirect3DDevice9 *d, const DWORD *a, IDirect3DPixelShader9 **b) {
    auto t = tick();
    auto hr = oCreatePS(d, a, b);
    record(mCreatePS, t);
    return hr;
}

static HRESULT WINAPI hCreateQuery(IDirect3DDevice9 *d, D3DQUERYTYPE a, IDirect3DQuery9 **b) {
    auto t = tick();
    auto hr = oCreateQuery(d, a, b);
    record(mCreateQuery, t);
    return hr;
}

static HRESULT WINAPI hIssue(IDirect3DQuery9 *q, DWORD a) {
    auto t = tick();
    auto hr = oIssue(q, a);
    record(mIssue, t);
    return hr;
}

static HRESULT WINAPI hGetData(IDirect3DQuery9 *q, void *a, DWORD b, DWORD c) {
    auto t = tick();
    auto hr = oGetData(q, a, b, c);
    record(mGetData, t);
    return hr;
}

static bool replace(void **slot, void *from, void *to) {
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

static void print_metric(FILE *f, const char *n, Metric &m) {
    auto c = m.count.load();
    fprintf(f, "%-22s count=%-8lu total_ms=%-10.3f mean_us=%-8.2f max_ms=%-8.3f over1=%-5lu over5=%-5lu over10=%-5lu over33=%-5lu over100=%lu\n",
            n, c, m.total_us.load() / 1000.0, c ? double(m.total_us.load()) / c : 0.0,
            m.max_us.load() / 1000.0, m.over1.load(), m.over5.load(), m.over10.load(), m.over33.load(), m.over100.load());
}

static int cmp_double(const void *a, const void *b) {
    double da = *(const double*)a;
    double db = *(const double*)b;
    return (da > db) - (da < db);
}

static void finish() {
    if (done.exchange(1)) return;
    restore(sPresent, (void*)hPresent, (void*)oPresent);
    restore(sReset, (void*)hReset, (void*)oReset);
    restore(sClear, (void*)hClear, (void*)oClear);
    restore(sCreateTexture, (void*)hCreateTexture, (void*)oCreateTexture);
    restore(sSetRenderTarget, (void*)hSetRenderTarget, (void*)oSetRenderTarget);
    restore(sDraw, (void*)hDraw, (void*)oDraw);
    restore(sDrawIndexed, (void*)hDrawIndexed, (void*)oDrawIndexed);
    restore(sDrawUP, (void*)hDrawUP, (void*)oDrawUP);
    restore(sDrawIndexedUP, (void*)hDrawIndexedUP, (void*)oDrawIndexedUP);
    restore(sCreateVS, (void*)hCreateVS, (void*)oCreateVS);
    restore(sCreatePS, (void*)hCreatePS, (void*)oCreatePS);
    restore(sCreateQuery, (void*)hCreateQuery, (void*)oCreateQuery);
    restore(sIssue, (void*)hIssue, (void*)oIssue);
    restore(sGetData, (void*)hGetData, (void*)oGetData);

    FILE *f = fopen("C:\\ProgramData\\MacDeck\\RendererSessions\\hmh-api-latency.txt", "w");
    if (f) {
        fputs("=== Half Minute Hero D3D9 API Latency Profile (30s) ===\n", f);
        print_metric(f, "Present", mPresent);
        print_metric(f, "Reset", mReset);
        print_metric(f, "Clear", mClear);
        print_metric(f, "CreateTexture", mCreateTexture);
        print_metric(f, "SetRenderTarget", mSetRenderTarget);
        print_metric(f, "DrawPrimitive", mDraw);
        print_metric(f, "DrawIndexedPrimitive", mDrawIndexed);
        print_metric(f, "DrawPrimitiveUP", mDrawUP);
        print_metric(f, "DrawIndexedPrimitiveUP", mDrawIndexedUP);
        print_metric(f, "CreateVertexShader", mCreateVS);
        print_metric(f, "CreatePixelShader", mCreatePS);
        print_metric(f, "CreateQuery", mCreateQuery);
        print_metric(f, "QueryIssue", mIssue);
        print_metric(f, "QueryGetData", mGetData);

        AcquireSRWLockExclusive(&interval_lock);
        if (interval_count > 0) {
            double sorted[MAX_SAMPLES];
            memcpy(sorted, intervals, interval_count * sizeof(double));
            qsort(sorted, interval_count, sizeof(double), cmp_double);
            double sum = 0;
            unsigned over33 = 0, over50 = 0, over100 = 0, over250 = 0, over500 = 0;
            for (unsigned i = 0; i < interval_count; ++i) {
                sum += sorted[i];
                over33 += sorted[i] > 33.333;
                over50 += sorted[i] > 50.0;
                over100 += sorted[i] > 100.0;
                over250 += sorted[i] > 250.0;
                over500 += sorted[i] > 500.0;
            }
            fprintf(f, "\n=== Frame Intervals (ms) ===\n");
            fprintf(f, "samples=%u mean=%.2f p50=%.2f p95=%.2f p99=%.2f max=%.2f over33=%u over50=%u over100=%u over250=%u over500=%u fps=%.2f\n",
                    interval_count, sum / interval_count, sorted[interval_count * 50 / 100],
                    sorted[interval_count * 95 / 100], sorted[interval_count * 99 / 100],
                    sorted[interval_count - 1], over33, over50, over100, over250, over500,
                    sum > 0 ? interval_count * 1000.0 / sum : 0.0);
        }
        ReleaseSRWLockExclusive(&interval_lock);
        fclose(f);
    }
    SetEvent(finished);
}

static DWORD WINAPI watchdog(void*) {
    Sleep(30000);
    finish();
    return 0;
}

#define HOOK(base, type, name, hook, orig, slot) do { \
    slot = (base) + offsetof(type, name) / sizeof(void*); \
    orig = reinterpret_cast<decltype(orig)>(*slot); \
    if (!replace(slot, (void*)orig, (void*)hook)) { \
        FILE *eh = fopen("C:\\ProgramData\\MacDeck\\RendererSessions\\hmh-latency-debug.log", "a"); \
        if (eh) { fprintf(eh, "HOOK failed for %s slot=%p orig=%p\n", #name, slot, orig); fclose(eh); } \
        finish(); return 4; \
    } \
} while(0)

static DWORD WINAPI setup(void*) {
    FILE *dbg = fopen("C:\\ProgramData\\MacDeck\\RendererSessions\\hmh-latency-debug.log", "w");
    if (dbg) {
        fprintf(dbg, "setup started\n");
        fflush(dbg);
    }
    HMODULE module = GetModuleHandleW(L"macdeck_hmh_dxmt_clear_v2.dll");
    if (!module) {
        if (dbg) { fprintf(dbg, "GetModuleHandle failed\n"); fclose(dbg); }
        return 1;
    }
    auto dos = (IMAGE_DOS_HEADER*)module;
    auto nt = (IMAGE_NT_HEADERS*)((char*)module + dos->e_lfanew);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE ||
        nt->OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR32_MAGIC ||
        nt->FileHeader.TimeDateStamp != 0x6a85139a ||
        nt->OptionalHeader.SizeOfImage != 0x26a000) {
        if (dbg) { fprintf(dbg, "header check failed: ts=0x%lx size=0x%lx\n", nt->FileHeader.TimeDateStamp, nt->OptionalHeader.SizeOfImage); fclose(dbg); }
        return 2;
    }

    QueryPerformanceFrequency(&frequency);
    finished = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (!finished) {
        if (dbg) { fprintf(dbg, "CreateEvent failed\n"); fclose(dbg); }
        return 3;
    }
    if (dbg) { fprintf(dbg, "hooking device vtable...\n"); fflush(dbg); fclose(dbg); }

    auto device = (void**)((char*)module + 0x2515b0 + 8);
    auto query = (void**)((char*)module + 0x251580 + 8);

    HOOK(device, IDirect3DDevice9Vtbl, Present, hPresent, oPresent, sPresent);
    HOOK(device, IDirect3DDevice9Vtbl, Reset, hReset, oReset, sReset);
    HOOK(device, IDirect3DDevice9Vtbl, Clear, hClear, oClear, sClear);
    HOOK(device, IDirect3DDevice9Vtbl, CreateTexture, hCreateTexture, oCreateTexture, sCreateTexture);
    HOOK(device, IDirect3DDevice9Vtbl, SetRenderTarget, hSetRenderTarget, oSetRenderTarget, sSetRenderTarget);
    HOOK(device, IDirect3DDevice9Vtbl, DrawPrimitive, hDraw, oDraw, sDraw);
    HOOK(device, IDirect3DDevice9Vtbl, DrawIndexedPrimitive, hDrawIndexed, oDrawIndexed, sDrawIndexed);
    HOOK(device, IDirect3DDevice9Vtbl, DrawPrimitiveUP, hDrawUP, oDrawUP, sDrawUP);
    HOOK(device, IDirect3DDevice9Vtbl, DrawIndexedPrimitiveUP, hDrawIndexedUP, oDrawIndexedUP, sDrawIndexedUP);
    HOOK(device, IDirect3DDevice9Vtbl, CreateVertexShader, hCreateVS, oCreateVS, sCreateVS);
    HOOK(device, IDirect3DDevice9Vtbl, CreatePixelShader, hCreatePS, oCreatePS, sCreatePS);
    HOOK(device, IDirect3DDevice9Vtbl, CreateQuery, hCreateQuery, oCreateQuery, sCreateQuery);
    HOOK(query, IDirect3DQuery9Vtbl, Issue, hIssue, oIssue, sIssue);
    HOOK(query, IDirect3DQuery9Vtbl, GetData, hGetData, oGetData, sGetData);

    HANDLE t = CreateThread(nullptr, 0, watchdog, nullptr, 0, nullptr);
    if (t) CloseHandle(t);
    else finish();
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE i, DWORD r, LPVOID) {
    if (r == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(i);
        HANDLE t = CreateThread(nullptr, 0, setup, nullptr, 0, nullptr);
        if (t) CloseHandle(t);
    }
    return TRUE;
}
