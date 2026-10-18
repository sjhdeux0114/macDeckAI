#!/usr/bin/env python3
"""Version-locked experimental DXMT0.80 embedded Metal-library replacement.
Appends a read-only PE section; does not overwrite adjacent original data.
Output is a separate file. The caller retains/restores the original DLL.
"""
from pathlib import Path
import hashlib
import json
import struct
import sys

source, library, output = map(Path, sys.argv[1:4])
raw = source.read_bytes()
EXPECTED_SHA = 'cafb32ba2b58e2e8decc1d6feabccdc131e1bf186713b34913a98974f94a3f02'
if hashlib.sha256(raw).hexdigest() != EXPECTED_SHA:
    raise RuntimeError('Unknown DXMT input; refusing patch')
b = bytearray(raw)
lib = library.read_bytes()
if lib[:4] != b'MTLB' or struct.unpack_from('<Q', lib, 16)[0] != len(lib):
    raise RuntimeError('Invalid Metal library length')
pe = struct.unpack_from('<I', b, 60)[0]
assert b[pe:pe+4] == b'PE\0\0'
count = struct.unpack_from('<H', b, pe+6)[0]
optional = pe+24
assert struct.unpack_from('<H', b, optional)[0] == 0x20b
headers = optional+struct.unpack_from('<H', b, pe+20)[0]
section_align, file_align = struct.unpack_from('<II', b, optional+32)
def align(n, size): return (n+size-1)//size*size
sections=[]
for i in range(count):
    h=headers+i*40
    vs,va,rs,rp=struct.unpack_from('<IIII',b,h+8)
    sections.append((vs,va,rs,rp))
def offset(rva):
    for vs,va,rs,rp in sections:
        if va <= rva < va+rs: return rp+rva-va
    raise RuntimeError('Unmapped RVA')
old_data_rva=0x276060
old_length_rva=0x276040
old_data_offset=offset(old_data_rva)
assert b[old_data_offset:old_data_offset+4] == b'MTLB'
assert struct.unpack_from('<I',b,offset(old_length_rva))[0] == 152339
instruction_rva=0x55bb8
instruction=offset(instruction_rva)
assert b[instruction:instruction+7] == bytes.fromhex('488d0da1042200')
new_header=headers+count*40
assert new_header+40 <= struct.unpack_from('<I',b,optional+60)[0]
assert not any(b[new_header:new_header+40])
new_rva=align(max(va+max(vs,rs) for vs,va,rs,rp in sections),section_align)
new_raw=align(len(b),file_align)
new_raw_size=align(len(lib),file_align)
b.extend(bytes(new_raw-len(b)))
b.extend(lib); b.extend(bytes(new_raw_size-len(lib)))
b[new_header:new_header+8]=b'.mdmetal'
struct.pack_into('<IIIIIIHHI',b,new_header+8,len(lib),new_rva,new_raw_size,new_raw,0,0,0,0,0x40000040)
struct.pack_into('<H',b,pe+6,count+1)
struct.pack_into('<I',b,optional+56,align(new_rva+len(lib),section_align))
struct.pack_into('<I',b,optional+8,struct.unpack_from('<I',b,optional+8)[0]+new_raw_size)
struct.pack_into('<I',b,optional+64,0)
struct.pack_into('<i',b,instruction+3,new_rva-(instruction_rva+7))
struct.pack_into('<I',b,offset(old_length_rva),len(lib))
assert b[new_raw:new_raw+len(lib)] == lib
assert instruction_rva+7+struct.unpack_from('<i',b,instruction+3)[0] == new_rva
output.write_bytes(b)
print(json.dumps({'sourceSHA256':EXPECTED_SHA,'metalSHA256':hashlib.sha256(lib).hexdigest(),
 'outputSHA256':hashlib.sha256(b).hexdigest(),'newSectionRVA':hex(new_rva),'libraryBytes':len(lib),
 'originalBytes':len(raw),'patchedBytes':len(b)},indent=2))
