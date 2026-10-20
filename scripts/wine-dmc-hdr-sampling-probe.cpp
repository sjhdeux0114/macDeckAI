#include <windows.h>
#include <d3d9.h>
#include <d3dcompiler.h>
#include <cstdio>
#include <cstring>
#define HR(x) do{HRESULT hr=(x);if(FAILED(hr)){printf("FAIL line=%d hr=%08lx\n",__LINE__,(unsigned long)hr);return 1;}}while(0)
int main(){setvbuf(stdout,nullptr,_IONBF,0);
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
    const char *vs="float4 main(float4 p:POSITION):POSITION{return p;}";
    const char *ps="sampler2D image:register(s0); float4 main():COLOR0{return tex2D(image,float2(.5,.5));}";
    ID3DBlob *vb=nullptr,*pb=nullptr,*err=nullptr;
    HR(D3DCompile(vs,strlen(vs),nullptr,nullptr,nullptr,"main","vs_3_0",0,0,&vb,&err));
    HR(D3DCompile(ps,strlen(ps),nullptr,nullptr,nullptr,"main","ps_3_0",0,0,&pb,&err));
    IDirect3DVertexShader9 *vshader=nullptr;IDirect3DPixelShader9 *pshader=nullptr;
    HR(device->CreateVertexShader((DWORD*)vb->GetBufferPointer(),&vshader));HR(device->CreatePixelShader((DWORD*)pb->GetBufferPointer(),&pshader));
    HR(device->SetVertexShader(vshader));HR(device->SetPixelShader(pshader));
    IDirect3DTexture9*image=nullptr;HR(device->CreateTexture(4,4,1,D3DUSAGE_RENDERTARGET,D3DFMT_A16B16G16R16F,D3DPOOL_DEFAULT,&image,nullptr));
    IDirect3DSurface9*sourceTarget=nullptr;HR(image->GetSurfaceLevel(0,&sourceTarget));
    D3DVERTEXELEMENT9 elements[]={{0,0,D3DDECLTYPE_FLOAT4,D3DDECLMETHOD_DEFAULT,D3DDECLUSAGE_POSITION,0},D3DDECL_END()};IDirect3DVertexDeclaration9*decl=nullptr;HR(device->CreateVertexDeclaration(elements,&decl));HR(device->SetVertexDeclaration(decl));
    float vertices[]={-1,-1,0,1,-1,1,0,1,1,-1,0,1,1,1,0,1};
    HR(device->SetRenderState(D3DRS_ZENABLE,FALSE));HR(device->SetRenderState(D3DRS_CULLMODE,D3DCULL_NONE));
    const char* bright="float4 main():COLOR0{return float4(2,4,.5,1);}";ID3DBlob*brightCode=nullptr;IDirect3DPixelShader9*brightShader=nullptr;
    HR(D3DCompile(bright,strlen(bright),nullptr,nullptr,nullptr,"main","ps_3_0",0,0,&brightCode,&err));HR(device->CreatePixelShader((DWORD*)brightCode->GetBufferPointer(),&brightShader));
    HR(device->SetRenderTarget(0,sourceTarget));D3DVIEWPORT9 small={0,0,4,4,0,1};HR(device->SetViewport(&small));HR(device->SetPixelShader(brightShader));
    HR(device->BeginScene());HR(device->DrawPrimitiveUP(D3DPT_TRIANGLESTRIP,2,vertices,16));HR(device->EndScene());
    IDirect3DSurface9 *target=nullptr,*readback=nullptr;
    HR(device->CreateRenderTarget(4,4,D3DFMT_A16B16G16R16F,D3DMULTISAMPLE_NONE,0,FALSE,&target,nullptr));HR(device->SetRenderTarget(0,target));HR(device->SetViewport(&small));HR(device->SetPixelShader(pshader));HR(device->SetTexture(0,image));
    HR(device->SetSamplerState(0,D3DSAMP_MINFILTER,D3DTEXF_POINT));HR(device->SetSamplerState(0,D3DSAMP_MAGFILTER,D3DTEXF_POINT));
    HR(device->BeginScene());HR(device->DrawPrimitiveUP(D3DPT_TRIANGLESTRIP,2,vertices,16));HR(device->EndScene());
    HR(device->CreateOffscreenPlainSurface(4,4,D3DFMT_A16B16G16R16F,D3DPOOL_SYSTEMMEM,&readback,nullptr));HR(device->GetRenderTargetData(target,readback));
    D3DLOCKED_RECT locked={};HR(readback->LockRect(&locked,nullptr,D3DLOCK_READONLY));
    unsigned short expected[]={0x4000,0x4400,0x3800,0x3c00};bool good=true;
    for(int y=0;y<4;y++)for(int x=0;x<4;x++){auto pixel=(unsigned short*)((char*)locked.pBits+y*locked.Pitch)+x*4;for(int c=0;c<4;c++)if(pixel[c]!=expected[c]){printf("FAIL xy=%d,%d channel=%d expected=%04x actual=%04x\n",x,y,c,expected[c],pixel[c]);good=false;}}
    HR(readback->UnlockRect());if(!good)return 12;puts("PASS HDR render-to-texture -> sample -> FP16 readback: all 16 pixels preserve 2/4/.5/1");return 0;
}
