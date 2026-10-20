#include <windows.h>
#include <d3d9.h>
#include <d3dcompiler.h>
#include <cstdio>
#include <cstring>
#include <cmath>
#define HR(x) do{HRESULT hr=(x);if(FAILED(hr)){printf("FAIL line=%d hr=%08lx\n",__LINE__,(unsigned long)hr);return 1;}}while(0)
int main(int argc,char**argv){if(argc<2||argc>3)return 20;setvbuf(stdout,nullptr,_IONBF,0);
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
    const char *vs="struct O{float4 p:POSITION;float4 uv:TEXCOORD0;float4 uv1:TEXCOORD1;};O main(float4 p:POSITION){O o;o.p=p;o.uv=.5;o.uv1=float4(.5,.5,0,0);return o;}";
    const char *ps="sampler2D image:register(s0); float4 main():COLOR0{return pow(tex2D(image,float2(.5,.5)),1.0/2.2);}";
    ID3DBlob *vb=nullptr,*pb=nullptr,*err=nullptr;
    HR(D3DCompile(vs,strlen(vs),nullptr,nullptr,nullptr,"main","vs_3_0",0,0,&vb,&err));
    HR(D3DCompile(ps,strlen(ps),nullptr,nullptr,nullptr,"main","ps_3_0",0,0,&pb,&err));
    IDirect3DVertexShader9 *vshader=nullptr;IDirect3DPixelShader9 *pshader=nullptr;
    HR(device->CreateVertexShader((DWORD*)vb->GetBufferPointer(),&vshader));HR(device->CreatePixelShader((DWORD*)pb->GetBufferPointer(),&pshader));
    FILE*shaderFile=fopen(argv[1],"rb");if(!shaderFile)return 21;unsigned char shaderBytes[65536];size_t shaderSize=fread(shaderBytes,1,sizeof(shaderBytes),shaderFile);fclose(shaderFile);if(!shaderSize||shaderSize==sizeof(shaderBytes))return 22;if(argc==2){pshader->Release();HR(device->CreatePixelShader((DWORD*)shaderBytes,&pshader));}
    HR(device->SetVertexShader(vshader));HR(device->SetPixelShader(pshader));
    for(int sampler=0;sampler<4;sampler++){
     IDirect3DTexture9*image=nullptr;unsigned w=sampler==2?256:4,h=sampler==2?16:4;D3DFORMAT format=sampler==2?D3DFMT_A8R8G8B8:D3DFMT_A16B16G16R16F;
     HR(device->CreateTexture(w,h,1,0,format,D3DPOOL_MANAGED,&image,nullptr));D3DLOCKED_RECT lock={};HR(image->LockRect(0,&lock,nullptr,0));
     for(unsigned y=0;y<h;y++)for(unsigned x=0;x<w;x++){
      if(sampler==2)((DWORD*)((char*)lock.pBits+y*lock.Pitch))[x]=0xff000000u|((x%16)*17u<<16)|(y*17u<<8)|((x/16)*17u);
      else {auto pixel=(unsigned short*)((char*)lock.pBits+y*lock.Pitch)+x*4;pixel[0]=sampler==0?0x3400:0;pixel[1]=sampler==0?0x3800:0;pixel[2]=sampler==0?0x3a00:0;pixel[3]=(sampler==0||sampler==3)?0x3c00:0;}
     }
     HR(image->UnlockRect(0));HR(device->SetTexture(sampler,image));HR(device->SetSamplerState(sampler,D3DSAMP_MINFILTER,D3DTEXF_LINEAR));HR(device->SetSamplerState(sampler,D3DSAMP_MAGFILTER,D3DTEXF_LINEAR));HR(device->SetSamplerState(sampler,D3DSAMP_ADDRESSU,D3DTADDRESS_CLAMP));HR(device->SetSamplerState(sampler,D3DSAMP_ADDRESSV,D3DTADDRESS_CLAMP));image->Release();
    }
    float constants[8*4]={};constants[0]=constants[1]=constants[2]=1;constants[7*4+2]=constants[7*4+3]=1;HR(device->SetPixelShaderConstantF(0,constants,8));
    D3DVERTEXELEMENT9 elements[]={{0,0,D3DDECLTYPE_FLOAT4,D3DDECLMETHOD_DEFAULT,D3DDECLUSAGE_POSITION,0},D3DDECL_END()};IDirect3DVertexDeclaration9*decl=nullptr;HR(device->CreateVertexDeclaration(elements,&decl));HR(device->SetVertexDeclaration(decl));
    float vertices[]={-1,-1,0,1,-1,1,0,1,1,-1,0,1,1,1,0,1};
    HR(device->SetRenderState(D3DRS_ZENABLE,FALSE));HR(device->SetRenderState(D3DRS_CULLMODE,D3DCULL_NONE));
    IDirect3DSurface9 *target=nullptr,*readback=nullptr;
    HR(device->CreateRenderTarget(4,4,D3DFMT_A16B16G16R16F,D3DMULTISAMPLE_NONE,0,FALSE,&target,nullptr));HR(device->SetRenderTarget(0,target));D3DVIEWPORT9 small={0,0,4,4,0,1};HR(device->SetViewport(&small));HR(device->SetPixelShader(pshader));
    HR(device->SetSamplerState(0,D3DSAMP_MINFILTER,D3DTEXF_POINT));HR(device->SetSamplerState(0,D3DSAMP_MAGFILTER,D3DTEXF_POINT));
    HR(device->BeginScene());HR(device->DrawPrimitiveUP(D3DPT_TRIANGLESTRIP,2,vertices,16));HR(device->EndScene());
    HR(device->CreateOffscreenPlainSurface(4,4,D3DFMT_A16B16G16R16F,D3DPOOL_SYSTEMMEM,&readback,nullptr));HR(device->GetRenderTargetData(target,readback));
    D3DLOCKED_RECT locked={};HR(readback->LockRect(&locked,nullptr,D3DLOCK_READONLY));
    auto fromHalf=[](unsigned short h){int e=(h>>10)&31;return std::ldexp(float(e?(h&1023)+1024:h&1023),e?e-25:-24)*(h&32768?-1:1);};
    float expected[]={std::pow(.25f,1/2.2f),std::pow(.5f,1/2.2f),std::pow(.75f,1/2.2f)};bool good=true;
    for(int y=0;y<4;y++)for(int x=0;x<4;x++){auto pixel=(unsigned short*)((char*)locked.pBits+y*locked.Pitch)+x*4;for(int c=0;c<3;c++){float actual=fromHalf(pixel[c]);if(x==2&&y==2)printf("channel%d expected=%g actual=%g\n",c,expected[c],actual);if(std::fabs(actual-expected[c])>.012f)good=false;}}
    HR(readback->UnlockRect());if(!good){puts("FAIL exact DmC final shader vs CPU gamma + identity LUT");return 12;}puts("PASS shader vs CPU gamma + identity LUT: 16 pixels");return 0;
}
