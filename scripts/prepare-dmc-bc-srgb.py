#!/usr/bin/env python3
"""Exact DmC v3->v4 candidate: retain native BC sRGB texture views.
The original TextureView constructor incorrectly replaces BC sRGB aliases with
linear parents. M5 native Metal and isolated D3D9 tests provide the oracle.
No installation; refuses unknown inputs and existing outputs, including -O.
"""
import hashlib,json,struct,sys
from pathlib import Path
if len(sys.argv)!=3:raise SystemExit('usage: prepare-dmc-bc-srgb.py V3_DLL NEW_V4_DLL')
source,target=map(Path,sys.argv[1:]);data=source.read_bytes()
expected='84a4886fd6ac94d8dff5a680652f52068ccfb4be744aa40468a30b6843126627'
if hashlib.sha256(data).hexdigest()!=expected:raise ValueError('Unknown v3 input')
if target.exists():raise FileExistsError('Refusing overwrite')
pe=struct.unpack_from('<I',data,60)[0]
if data[:2]!=b'MZ' or data[pe:pe+4]!=b'PE\0\0' or struct.unpack_from('<H',data,pe+24)[0]!=0x10b:raise ValueError('Not PE32')
location=840678
if data[location-2:location+13]!=bytes.fromhex('84c00f85240600008b9590feffff0f'):raise ValueError('TextureView branch/context mismatch')
patched=bytearray(data);patched[location:location+6]=b'\x90'*6
digest=hashlib.sha256(patched).hexdigest()
if digest!='def19eca660d29eb9065624971a2b3003a59a21896e1e62d58c096404f54a719':raise ValueError('Unexpected candidate')
target.parent.mkdir(parents=True,exist_ok=True)
with target.open('xb') as f:f.write(patched)
print(json.dumps({'inputSHA256':expected,'outputSHA256':digest,'offset':location,'changedBytes':6,'scope':'private DmC experiment'},indent=2))
