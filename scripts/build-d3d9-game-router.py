#!/usr/bin/env python3
"""Preserve i386 export ordinals and calling conventions with tail trampolines."""
from pathlib import Path
import subprocess,re,struct
root=Path(__file__).resolve().parent.parent
compiler=root/'.cache/llvm-mingw/llvm-mingw-20261006-ucrt-macos-universal/bin/i686-w64-mingw32-clang++'
source=root/'dist/MacDeck.app/Contents/Resources/Runtime/lib/wine/i386-windows/d3d9.dll'
content=subprocess.run([str(compiler.parent/'llvm-readobj'),'--coff-exports',str(source)],capture_output=True,text=True,check=True).stdout
exports=re.findall(r'Ordinal: (\d+)\s+Name: ([^\n]+)\s+RVA:',content)
assert len(exports)==14
out=root/'.build/d3d9-router';out.mkdir(exist_ok=True)
asm=[];data=[];definitions=['EXPORTS']
for ordinal,name in exports:
 name=name.strip();definitions.append(f'{name} @{ordinal}')
 asm.extend(['.text',f'.globl _{name}',f'_{name}:',f'cmpl $0, cache_{name}',f'jne ready_{name}','pushfl','pushal',f'pushl ${ordinal}',f'pushl $name_{name}','call _router_resolve','addl $8,%esp',f'movl %eax,cache_{name}','popal','popfl',f'ready_{name}:',f'jmp *cache_{name}'])
 data.extend(['.data','.p2align 2',f'cache_{name}: .long 0',f'name_{name}: .asciz "{name}"'])
(out/'d3d9.S').write_text('\n'.join(asm+data)+'\n');(out/'d3d9.def').write_text('\n'.join(definitions)+'\n')
subprocess.run([str(compiler),'-O2','-shared','-static',str(root/'scripts/d3d9-game-router.cpp'),str(out/'d3d9.S'),str(out/'d3d9.def'),'-o',str(out/'d3d9.dll')],check=True)
# This runtime requests builtin d3d9. Preserve Wine's PE builtin marker in the dispatcher.
p=out/'d3d9.dll';raw=bytearray(p.read_bytes());assert struct.unpack_from('<I',raw,60)[0]>=0x51
raw[64:81]=b'Wine builtin DLL\0';p.write_bytes(raw)
print('BUILT i386 D3D9 dispatcher, 14 ordinal-preserving exports')
