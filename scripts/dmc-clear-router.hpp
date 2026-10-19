// Only reached for an explicitly selected AppID 220440 private-renderer patch.
#include "dmc-depth-clear.hpp"
static decltype(IDirect3D9Vtbl::CreateDevice) dmcClearCreateDeviceOriginal=nullptr;
static decltype(IDirect3DDevice9Vtbl::Clear) dmcClearOriginal=nullptr;
static IDirect3D9*(WINAPI*dmcClearCreate9Original)(UINT)=nullptr;
static HRESULT WINAPI dmcClear(IDirect3DDevice9*d,DWORD n,const D3DRECT*r,DWORD flags,D3DCOLOR color,float depth,DWORD stencil){
 // Keep original validation, full-surface fast path, explicit rectangles and MRT.
 if(n||r||!(flags&7)||(flags&~DWORD(7)))return dmcClearOriginal(d,n,r,flags,color,depth,stencil);
 D3DVIEWPORT9 vp={};if(FAILED(d->lpVtbl->GetViewport(d,&vp)))return dmcClearOriginal(d,n,r,flags,color,depth,stencil);
 DWORD scissor=0;d->lpVtbl->GetRenderState(d,D3DRS_SCISSORTESTENABLE,&scissor);bool partial=scissor!=0;
 IDirect3DSurface9*surface=nullptr;D3DSURFACE_DESC desc={};
 if(flags&D3DCLEAR_TARGET){
  for(DWORD i=1;i<4;i++)if(SUCCEEDED(d->lpVtbl->GetRenderTarget(d,i,&surface))&&surface){surface->lpVtbl->Release(surface);return dmcClearOriginal(d,n,r,flags,color,depth,stencil);}
  surface=nullptr;if(FAILED(d->lpVtbl->GetRenderTarget(d,0,&surface))||!surface)return dmcClearOriginal(d,n,r,flags,color,depth,stencil);
  surface->lpVtbl->GetDesc(surface,&desc);surface->lpVtbl->Release(surface);partial=partial||vp.X||vp.Y||vp.Width<desc.Width||vp.Height<desc.Height;
 }
 if(flags&(D3DCLEAR_ZBUFFER|D3DCLEAR_STENCIL)){
  surface=nullptr;if(FAILED(d->lpVtbl->GetDepthStencilSurface(d,&surface))||!surface)return dmcClearOriginal(d,n,r,flags,color,depth,stencil);
  surface->lpVtbl->GetDesc(surface,&desc);surface->lpVtbl->Release(surface);partial=partial||vp.X||vp.Y||vp.Width<desc.Width||vp.Height<desc.Height;
 }
 if(!partial)return dmcClearOriginal(d,n,r,flags,color,depth,stencil);
 return dmcDrawClear(d,n,r,flags,color,depth,stencil);
}
static HRESULT WINAPI dmcClearCreateDevice(IDirect3D9*api,UINT a,D3DDEVTYPE t,HWND w,DWORD f,D3DPRESENT_PARAMETERS*p,IDirect3DDevice9**out){auto hr=dmcClearCreateDeviceOriginal(api,a,t,w,f,p,out);if(SUCCEEDED(hr)&&out&&*out)dmcPatch(*out,offsetof(IDirect3DDevice9Vtbl,Clear)/sizeof(void*),dmcClear,dmcClearOriginal);return hr;}
static IDirect3D9*WINAPI dmcClearCreate9(UINT version){auto api=dmcClearCreate9Original(version);if(api)dmcPatch(api,offsetof(IDirect3D9Vtbl,CreateDevice)/sizeof(void*),dmcClearCreateDevice,dmcClearCreateDeviceOriginal);return api;}
