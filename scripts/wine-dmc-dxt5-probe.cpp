// GPU integration probe: no Steam, game files, authentication or automatic input.
#include <windows.h>
#include <cstdio>
#include <cstdint>
#include <initializer_list>
#include <cstring>
#ifdef PROBE_D3D12
#include <d3d12.h>
#include <dxgi1_4.h>
#else
#include <d3d9.h>
#endif
#define HR(x) do { HRESULT result = (x); if (FAILED(result)) { std::printf("FAIL line=%d hr=0x%08lx\n", __LINE__, (unsigned long)result); return 1; } } while (0)
int main(int argc, char **) {
    std::setvbuf(stdout, nullptr, _IONBF, 0);
#ifdef PROBE_D3D12
    std::puts("START D3D12 feature level 12_0 device probe");
    ID3D12Device *device = nullptr;
    HR(D3D12CreateDevice(nullptr, D3D_FEATURE_LEVEL_12_0, __uuidof(ID3D12Device), (void **)&device));
    std::puts("D3D12 feature level 12_0 device created");
    ID3D12CommandQueue *queue = nullptr;
    D3D12_COMMAND_QUEUE_DESC queueDesc = {}; queueDesc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    HR(device->CreateCommandQueue(&queueDesc, __uuidof(ID3D12CommandQueue), (void **)&queue));
    ID3D12CommandAllocator *allocator = nullptr;
    HR(device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT, __uuidof(ID3D12CommandAllocator), (void **)&allocator));
    ID3D12GraphicsCommandList *commands = nullptr;
    HR(device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, allocator, nullptr, __uuidof(ID3D12GraphicsCommandList), (void **)&commands));
    D3D12_RESOURCE_DESC textureDesc = {};
    textureDesc.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D; textureDesc.Width = 4; textureDesc.Height = 4;
    textureDesc.DepthOrArraySize = 1; textureDesc.MipLevels = 1; textureDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    textureDesc.SampleDesc.Count = 1; textureDesc.Flags = D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET;
    D3D12_HEAP_PROPERTIES gpuHeap = {}; gpuHeap.Type = D3D12_HEAP_TYPE_DEFAULT; gpuHeap.CreationNodeMask = gpuHeap.VisibleNodeMask = 1;
    ID3D12Resource *texture = nullptr;
    HR(device->CreateCommittedResource(&gpuHeap, D3D12_HEAP_FLAG_NONE, &textureDesc, D3D12_RESOURCE_STATE_RENDER_TARGET, nullptr, __uuidof(ID3D12Resource), (void **)&texture));
    D3D12_DESCRIPTOR_HEAP_DESC rtvDesc = {}; rtvDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV; rtvDesc.NumDescriptors = 1;
    ID3D12DescriptorHeap *rtv = nullptr;
    HR(device->CreateDescriptorHeap(&rtvDesc, __uuidof(ID3D12DescriptorHeap), (void **)&rtv));
    const auto cpu = rtv->GetCPUDescriptorHandleForHeapStart(); device->CreateRenderTargetView(texture, nullptr, cpu);
    const FLOAT color[] = {0.25f, 0.5f, 0.75f, 1.0f}; commands->ClearRenderTargetView(cpu, color, 0, nullptr);
    D3D12_RESOURCE_BARRIER barrier = {}; barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Transition.pResource = texture; barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET; barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_SOURCE;
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES; commands->ResourceBarrier(1, &barrier);
    D3D12_PLACED_SUBRESOURCE_FOOTPRINT layout = {}; UINT rows = 0; UINT64 rowBytes = 0, totalBytes = 0;
    device->GetCopyableFootprints(&textureDesc, 0, 1, 0, &layout, &rows, &rowBytes, &totalBytes);
    D3D12_RESOURCE_DESC buffer = {}; buffer.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER; buffer.Width = totalBytes; buffer.Height = 1; buffer.DepthOrArraySize = 1; buffer.MipLevels = 1; buffer.SampleDesc.Count = 1; buffer.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    D3D12_HEAP_PROPERTIES cpuHeap = {}; cpuHeap.Type = D3D12_HEAP_TYPE_READBACK; cpuHeap.CreationNodeMask = cpuHeap.VisibleNodeMask = 1;
    ID3D12Resource *readback = nullptr;
    HR(device->CreateCommittedResource(&cpuHeap, D3D12_HEAP_FLAG_NONE, &buffer, D3D12_RESOURCE_STATE_COPY_DEST, nullptr, __uuidof(ID3D12Resource), (void **)&readback));
    D3D12_TEXTURE_COPY_LOCATION destination = {}; destination.pResource = readback; destination.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT; destination.PlacedFootprint = layout;
    D3D12_TEXTURE_COPY_LOCATION source = {}; source.pResource = texture; source.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
    commands->CopyTextureRegion(&destination, 0, 0, 0, &source, nullptr); HR(commands->Close());
    ID3D12CommandList *lists[] = {commands}; queue->ExecuteCommandLists(1, lists);
    ID3D12Fence *fence = nullptr; HR(device->CreateFence(0, D3D12_FENCE_FLAG_NONE, __uuidof(ID3D12Fence), (void **)&fence));
    HANDLE event = CreateEventW(nullptr, FALSE, FALSE, nullptr); HR(queue->Signal(fence, 1)); HR(fence->SetEventOnCompletion(1, event));
    if (WaitForSingleObject(event, 15000) != WAIT_OBJECT_0) { std::puts("FAIL GPU fence timeout"); return 2; }
    unsigned char *pixels = nullptr; D3D12_RANGE range = {0, (SIZE_T)totalBytes}; HR(readback->Map(0, &range, (void **)&pixels));
    int checked = 0;
    for (unsigned y = 0; y < 4; ++y) for (unsigned x = 0; x < 4; ++x) {
        const unsigned char *pixel = pixels + layout.Offset + y * layout.Footprint.RowPitch + x * 4;
        if (pixel[0] < 63 || pixel[0] > 64 || pixel[1] < 127 || pixel[1] > 128 || pixel[2] < 191 || pixel[2] > 192 || pixel[3] != 255) {
            std::printf("FAIL pixel=%u,%u,%u,%u\n",pixel[0],pixel[1],pixel[2],pixel[3]); return 3;
        }
        ++checked;
    }
    readback->Unmap(0, nullptr);
    std::printf("PASS D3D12 GPU clear/copy/fence/readback: %d pixels\n", checked);
    CloseHandle(event); fence->Release(); readback->Release(); rtv->Release(); texture->Release(); commands->Release(); allocator->Release(); queue->Release(); device->Release();
#else
    WNDCLASSW windowClass = {}; windowClass.lpfnWndProc = DefWindowProcW; windowClass.hInstance = GetModuleHandleW(nullptr); windowClass.lpszClassName = L"MacDeckD3D9Probe";
    RegisterClassW(&windowClass); RECT rectangle = {0, 0, 1280, 720}; AdjustWindowRect(&rectangle, WS_OVERLAPPEDWINDOW, FALSE);
    HWND window = CreateWindowW(windowClass.lpszClassName, L"MacDeck D3D9 GPU probe", WS_OVERLAPPEDWINDOW, 50, 50, rectangle.right-rectangle.left, rectangle.bottom-rectangle.top, nullptr,nullptr,windowClass.hInstance,nullptr);
    if (!window) { std::puts("FAIL create probe window"); return 4; }
    ShowWindow(window, SW_SHOW);
    IDirect3D9 *api = Direct3DCreate9(D3D_SDK_VERSION);
    if (!api) { std::puts("FAIL Direct3DCreate9"); return 5; }
    D3DADAPTER_IDENTIFIER9 adapter = {}; HR(api->GetAdapterIdentifier(0, 0, &adapter)); std::printf("Adapter: %s\n", adapter.Description);
    D3DPRESENT_PARAMETERS present = {}; present.BackBufferWidth=1280; present.BackBufferHeight=720; present.BackBufferFormat=D3DFMT_X8R8G8B8; present.BackBufferCount=1;
    present.SwapEffect=D3DSWAPEFFECT_COPY; present.hDeviceWindow=window; present.Windowed=TRUE; present.PresentationInterval=D3DPRESENT_INTERVAL_IMMEDIATE;
    IDirect3DDevice9 *device = nullptr;
    HR(api->CreateDevice(0,D3DDEVTYPE_HAL,window,D3DCREATE_HARDWARE_VERTEXPROCESSING|D3DCREATE_FPU_PRESERVE,&present,&device));
    for (DWORD usage : {DWORD(0), DWORD(D3DUSAGE_DYNAMIC)}) {
        IDirect3DTexture9 *texture = nullptr;
        HR(device->CreateTexture(64,64,1,usage,D3DFMT_DXT5,D3DPOOL_DEFAULT,&texture,nullptr));
        IDirect3DTexture9 *upload = texture;
        if (!usage) HR(device->CreateTexture(64,64,1,0,D3DFMT_DXT5,D3DPOOL_SYSTEMMEM,&upload,nullptr));
        D3DLOCKED_RECT texLock = {}; HR(upload->LockRect(0,&texLock,nullptr,0));
        memset(texLock.pBits,0,texLock.Pitch * 16); HR(upload->UnlockRect(0));
        if (!usage) { HR(device->UpdateTexture(upload,texture)); upload->Release(); }
        texture->Release();
    }
    std::puts("PASS DXT5 static/dynamic texture creation and upload");
    HR(device->Clear(0,nullptr,D3DCLEAR_TARGET,0xff204080,1,0));
    IDirect3DSurface9 *target=nullptr, *readback=nullptr;
    HR(device->GetBackBuffer(0,0,D3DBACKBUFFER_TYPE_MONO,&target));
    HR(device->CreateOffscreenPlainSurface(1280,720,D3DFMT_X8R8G8B8,D3DPOOL_SYSTEMMEM,&readback,nullptr));
    HR(device->GetRenderTargetData(target,readback));
    D3DLOCKED_RECT locked={}; HR(readback->LockRect(&locked,nullptr,D3DLOCK_READONLY));
    const uint32_t pixel=*(const uint32_t *)locked.pBits; readback->UnlockRect();
    if ((pixel & 0xffffff)!=0x204080) {std::printf("FAIL pixel=%08x\n",pixel); return 6;}
    HR(device->Present(nullptr,nullptr,nullptr,nullptr));
    RECT src={0,0,640,360}, dst={64,64,704,424}; HR(device->Present(&src,&dst,nullptr,nullptr));
    std::puts("PASS D3D9 GPU clear/readback, full and partial rectangle Present, 1280x720 client");
    readback->Release(); target->Release();
    if (argc > 1) {
        const ULONGLONG started = GetTickCount64();
        for (unsigned frame = 0; frame < 600; ++frame) {
            MSG message;
            while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) { TranslateMessage(&message); DispatchMessageW(&message); }
            if (frame && frame % 100 == 0) {
                present.BackBufferWidth = (frame % 200) ? 960 : 1280;
                present.BackBufferHeight = (frame % 200) ? 540 : 720;
                HR(device->Reset(&present));
            }
            HR(device->Clear(0,nullptr,D3DCLEAR_TARGET,0xff000000 | ((frame * 7919) & 0xffffff),1,0));
            HR(device->Present(nullptr,nullptr,nullptr,nullptr));
        }
        std::printf("PASS D3D9 600-frame Present + 5 Reset stress elapsed_ms=%llu\n", (unsigned long long)(GetTickCount64()-started));
    }
    device->Release(); api->Release(); DestroyWindow(window);
#endif
    return 0;
}
