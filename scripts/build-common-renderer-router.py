#!/usr/bin/env python3
"""Build ABI-preserving x64 export trampolines for the isolated renderer lab."""
from pathlib import Path
import subprocess, re, argparse
parser = argparse.ArgumentParser()
parser.add_argument("--apple-components", type=Path, help="Directory with macdeck_metal_*.dll aliases from the verified Apple runtime")
args = parser.parse_args()
root=Path(__file__).resolve().parent.parent
compiler=root/'.cache/llvm-mingw/llvm-mingw-20261006-ucrt-macos-universal/bin/x86_64-w64-mingw32-clang++'
out=root/'.build/common-router';out.mkdir(parents=True,exist_ok=True)
exports={
 'dxgi':[(9,'CreateDXGIFactory'),(10,'CreateDXGIFactory1'),(11,'CreateDXGIFactory2'),(12,None),(13,None),(14,None),(15,None),(16,None),(17,'DXGIGetDebugInterface1'),(18,'DXGIDeclareAdapterRemovalSupport')],
 'd3d12':[(100,'GetBehaviorValue'),(101,'D3D12CreateDevice'),(102,'D3D12GetDebugInterface'),(103,'D3D12CoreCreateLayeredDevice'),(104,'D3D12CoreGetLayeredDeviceSize'),(105,'D3D12CoreRegisterLayers'),(106,'D3D12CreateRootSignatureDeserializer'),(107,'D3D12CreateVersionedRootSignatureDeserializer'),(108,'D3D12EnableExperimentalFeatures'),(109,'D3D12GetInterface'),(110,'D3D12SerializeRootSignature'),(111,'D3D12SerializeVersionedRootSignature')]
}
reader=compiler.parent/'llvm-readobj'
for module in ('d3d11','d3d12core'):
 items=[];used=set();names=set()
 for source in (root/f'dist/MacDeck.app/Contents/Resources/Runtime/lib/wine/x86_64-windows/{module}.dll',(args.apple_components/('macdeck_metal_'+module+'.dll') if args.apple_components else Path('/private/tmp/macdeck-gptk4-beta3/redist/lib/wine/x86_64-windows')/(module+'.dll'))):
  content=subprocess.run([str(reader),'--coff-exports',str(source)],capture_output=True,text=True,check=True).stdout
  for number,name in re.findall(r'Ordinal: (\d+)\s+Name: ([^\n]*)\s+RVA:',content):
   name=name.strip()
   if name and name in names:continue
   ordinal=int(number)
   if ordinal in used:ordinal=max(used)+1
   used.add(ordinal);names.add(name);items.append((ordinal,name or None))
 exports[module]=items
for module,items in exports.items():
 asm=[];definitions=['EXPORTS'];data=[]
 for ordinal,name in items:
  label=name or f'ordinal_{ordinal}'
  definitions.append(f'{label} @{ordinal}'+(' NONAME' if not name else ''))
  asm.extend(['.text',f'.globl {label}',f'.seh_proc {label}',f'{label}:',f'cmpq $0, cache_{label}(%rip)',f'jne ready_{label}','subq $168,%rsp','.seh_stackalloc 168','.seh_endprologue','movq %rcx,32(%rsp)','movq %rdx,40(%rsp)','movq %r8,48(%rsp)','movq %r9,56(%rsp)'])
  for i in range(4):asm.append(f'movdqu %xmm{i},{64+16*i}(%rsp)')
  asm.extend([f'leaq name_{label}(%rip),%rcx' if name else 'xorq %rcx,%rcx',f'movl ${ordinal},%edx','call router_resolve',f'movq %rax,cache_{label}(%rip)','movq 32(%rsp),%rcx','movq 40(%rsp),%rdx','movq 48(%rsp),%r8','movq 56(%rsp),%r9'])
  for i in range(4):asm.append(f'movdqu {64+16*i}(%rsp),%xmm{i}')
  asm.extend(['addq $168,%rsp',f'ready_{label}:',f'jmp *cache_{label}(%rip)','.seh_endproc'])
  data.extend(['.data','.p2align 3',f'cache_{label}: .quad 0',f'name_{label}: .asciz "{name or ""}"'])
 (out/f'{module}.S').write_text('\n'.join(asm+data)+'\n');(out/f'{module}.def').write_text('\n'.join(definitions)+'\n')
 subprocess.run([str(compiler),'-O2','-shared','-static','-static-libgcc','-static-libstdc++',f'-DROUTER_MODULE=L"{module}"',str(root/'scripts/common-renderer-router.cpp'),str(out/f'{module}.S'),str(out/f'{module}.def'),'-o',str(out/f'{module}.dll')],check=True)
 print('BUILT',module)
