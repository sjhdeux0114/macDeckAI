#!/usr/bin/env python3
"""Locked v0.4 DmC private Clear constant-slot correction; never overwrites input.
Upstream D3D9ClearQuad::clear uses slot0, dxmt_command.metal uses
kCustomBufferArgumentIndex0=30. Change that one instruction immediate only.
"""
from pathlib import Path
import hashlib,struct,sys,json
if len(sys.argv)!=3:raise SystemExit('usage: prepare-dmc-clear-binding.py INPUT_PRIVATE_DLL NEW_OUTPUT_DLL')
source=Path(sys.argv[1]);target=Path(sys.argv[2]);raw=bytearray(source.read_bytes())
expected='af9a4837efa8a3f789381bf7fa1ae8a54f8e0bc3ab9a891fb5166659ce8998fd'
if hashlib.sha256(raw).hexdigest()!=expected:raise ValueError('Wrong private DmC input')
if target.exists():raise FileExistsError('Refusing overwrite')
pe=struct.unpack_from('<I',raw,60)[0];nsec=struct.unpack_from('<H',raw,pe+6)[0];optsize=struct.unpack_from('<H',raw,pe+20)[0];opt=pe+24
assert struct.unpack_from('<H',raw,opt)[0]==0x10b
base=struct.unpack_from('<I',raw,opt+28)[0];rva=0x624457c4-base
for i in range(nsec):
 section=opt+optsize+40*i;size,va,rawsize,offset=struct.unpack_from('<IIII',raw,section+8)
 if va<=rva<va+rawsize:location=offset+rva-va;break
else:raise AssertionError('Clear instruction not mapped')
if raw[location:location+10]!=bytes.fromhex('c64020008bb7747d0000'):raise ValueError('Clear instruction/context changed')
raw[location+3]=30
original=source.read_bytes();assert sum(a!=b for a,b in zip(original,raw))==1
assert len(original)==len(raw)
digest=hashlib.sha256(raw).hexdigest()
if digest!='84a4886fd6ac94d8dff5a680652f52068ccfb4be744aa40468a30b6843126627':raise ValueError('Unexpected patched DLL hash')
target.parent.mkdir(parents=True,exist_ok=True)
with target.open('xb') as out:out.write(raw)
print(json.dumps({'input_sha256':expected,'output_sha256':hashlib.sha256(raw).hexdigest(),'changed_bytes':1,'file_offset':location+3,'original_slot':0,'fixed_slot':30,'size':len(raw)},indent=2))
