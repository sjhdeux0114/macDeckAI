// Experimental DmC-only fallback for broken partial depth clears in the locked
// private D3D9 renderer. Caller must enforce exact AppID and explicit opt-in.
#pragma once
#include <d3d9.h>
#include <algorithm>
#ifdef CINTERFACE
#define DMC_CALL(o,m,...) ((o)->lpVtbl->m((o), ##__VA_ARGS__))
#else
#define DMC_CALL(o,m,...) ((o)->m(__VA_ARGS__))
#endif
static HRESULT dmcDrawClear(IDirect3DDevice9*d,DWORD count,const D3DRECT*rects,DWORD flags,D3DCOLOR color,float depth,DWORD stencil){
 if(!(flags&(D3DCLEAR_TARGET|D3DCLEAR_ZBUFFER|D3DCLEAR_STENCIL)) || (count && !rects))return D3DERR_INVALIDCALL;
 if(!count && rects)return D3D_OK;
 D3DVIEWPORT9 viewport={};HRESULT hr=DMC_CALL(d,GetViewport,&viewport);if(FAILED(hr))return hr;
 RECT clip={(LONG)viewport.X,(LONG)viewport.Y,(LONG)(viewport.X+viewport.Width),(LONG)(viewport.Y+viewport.Height)};
 DWORD scissor=0;DMC_CALL(d,GetRenderState,D3DRS_SCISSORTESTENABLE,&scissor);
 if(scissor){RECT s={};DMC_CALL(d,GetScissorRect,&s);clip.left=std::max(clip.left,s.left);clip.top=std::max(clip.top,s.top);clip.right=std::min(clip.right,s.right);clip.bottom=std::min(clip.bottom,s.bottom);}
 IDirect3DStateBlock9*saved=nullptr;hr=DMC_CALL(d,CreateStateBlock,D3DSBT_ALL,&saved);if(FAILED(hr))return hr;
 bool began=SUCCEEDED(DMC_CALL(d,BeginScene));
#define DMC_TRY(x) do{if(SUCCEEDED(hr)){HRESULT h=(x);if(FAILED(h))hr=h;}}while(0)
#define RS(state,value) DMC_TRY(DMC_CALL(d,SetRenderState,state,value))
 DMC_TRY(DMC_CALL(d,SetVertexShader,nullptr));DMC_TRY(DMC_CALL(d,SetPixelShader,nullptr));DMC_TRY(DMC_CALL(d,SetFVF,D3DFVF_XYZRHW|D3DFVF_DIFFUSE));DMC_TRY(DMC_CALL(d,SetTexture,0,nullptr));
 RS(D3DRS_ZENABLE,(flags&(D3DCLEAR_ZBUFFER|D3DCLEAR_STENCIL))!=0);RS(D3DRS_ZWRITEENABLE,(flags&D3DCLEAR_ZBUFFER)!=0);RS(D3DRS_ZFUNC,D3DCMP_ALWAYS);
 RS(D3DRS_STENCILENABLE,(flags&D3DCLEAR_STENCIL)!=0);RS(D3DRS_TWOSIDEDSTENCILMODE,FALSE);RS(D3DRS_STENCILFUNC,D3DCMP_ALWAYS);RS(D3DRS_STENCILREF,stencil&255);RS(D3DRS_STENCILMASK,255);RS(D3DRS_STENCILWRITEMASK,255);RS(D3DRS_STENCILFAIL,D3DSTENCILOP_REPLACE);RS(D3DRS_STENCILZFAIL,D3DSTENCILOP_REPLACE);RS(D3DRS_STENCILPASS,D3DSTENCILOP_REPLACE);
 RS(D3DRS_COLORWRITEENABLE,(flags&D3DCLEAR_TARGET)?15:0);RS(D3DRS_COLORWRITEENABLE1,0);RS(D3DRS_COLORWRITEENABLE2,0);RS(D3DRS_COLORWRITEENABLE3,0);
 DMC_TRY(DMC_CALL(d,SetTextureStageState,0,D3DTSS_COLOROP,D3DTOP_SELECTARG1));DMC_TRY(DMC_CALL(d,SetTextureStageState,0,D3DTSS_COLORARG1,D3DTA_DIFFUSE));DMC_TRY(DMC_CALL(d,SetTextureStageState,0,D3DTSS_ALPHAOP,D3DTOP_SELECTARG1));DMC_TRY(DMC_CALL(d,SetTextureStageState,0,D3DTSS_ALPHAARG1,D3DTA_DIFFUSE));DMC_TRY(DMC_CALL(d,SetTextureStageState,1,D3DTSS_COLOROP,D3DTOP_DISABLE));
 RS(D3DRS_COLORVERTEX,TRUE);RS(D3DRS_SHADEMODE,D3DSHADE_GOURAUD);RS(D3DRS_MULTISAMPLEMASK,0xffffffff);
 DMC_TRY(DMC_CALL(d,SetStreamSourceFreq,0,1));
 RS(D3DRS_CULLMODE,D3DCULL_NONE);RS(D3DRS_FILLMODE,D3DFILL_SOLID);RS(D3DRS_ALPHATESTENABLE,FALSE);RS(D3DRS_ALPHABLENDENABLE,FALSE);RS(D3DRS_FOGENABLE,FALSE);RS(D3DRS_LIGHTING,FALSE);RS(D3DRS_CLIPPLANEENABLE,0);RS(D3DRS_SCISSORTESTENABLE,FALSE);RS(D3DRS_DEPTHBIAS,0);RS(D3DRS_SLOPESCALEDEPTHBIAS,0);
 viewport.MinZ=0;viewport.MaxZ=1;DMC_TRY(DMC_CALL(d,SetViewport,&viewport));
 struct V{float x,y,z,w;DWORD color;};
 for(DWORD i=0;SUCCEEDED(hr)&&i<std::max(DWORD(1),count);++i){RECT r=clip;if(count){r.left=std::max(r.left,(LONG)rects[i].x1);r.top=std::max(r.top,(LONG)rects[i].y1);r.right=std::min(r.right,(LONG)rects[i].x2);r.bottom=std::min(r.bottom,(LONG)rects[i].y2);}if(r.left>=r.right||r.top>=r.bottom)continue;float l=r.left-.5f,t=r.top-.5f,right=r.right-.5f,bottom=r.bottom-.5f;V v[]={{l,t,depth,1,color},{right,t,depth,1,color},{l,bottom,depth,1,color},{right,bottom,depth,1,color}};DMC_TRY(DMC_CALL(d,DrawPrimitiveUP,D3DPT_TRIANGLESTRIP,2,v,sizeof(V)));}
 if(began){HRESULT h=DMC_CALL(d,EndScene);if(SUCCEEDED(hr))hr=h;}
 HRESULT restored=DMC_CALL(saved,Apply);DMC_CALL(saved,Release);if(SUCCEEDED(hr))hr=restored;
#undef RS
#undef DMC_TRY
 return hr;
}
#undef DMC_CALL

static HRESULT dmcDrawDepthClear(IDirect3DDevice9*d,DWORD n,const D3DRECT*r,DWORD f,float z,DWORD s){return dmcDrawClear(d,n,r,f,0,z,s);}
