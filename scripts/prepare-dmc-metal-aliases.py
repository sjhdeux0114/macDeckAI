#!/usr/bin/env python3
"""Create isolated DXMT D3D9/Unix aliases; never overwrite shared Metal libraries."""
from pathlib import Path
import hashlib,sys
source, runtime = map(Path,sys.argv[1:3])
expected = {
 'i386-windows/d3d9.dll':'d05cf0284db3452e2528faa7f2779dae66e9322dc19f3735a8d04864bd0b0e54',
 'i386-windows/winemetal.dll':'e3d0a8334841e712811fcecad9a6517a6fecfcc993b5c9381a93a9a522614292',
 'x86_64-unix/winemetal.so':'5fc2d029315798c53d42c86fc7d85fe9e23960be1c6d8ffc51f13975a29d6631'}
for relative, digest in expected.items():
 assert hashlib.sha256((source/relative).read_bytes()).hexdigest()==digest, 'Unknown candidate: '+relative
b=(source/'i386-windows/d3d9.dll').read_bytes()
assert b.count(b'winemetal.dll\0')==1
b=b.replace(b'winemetal.dll\0',b'wm_dmc001.dll\0')
for relative,data in [
 ('i386-windows/macdeck_dmc_dxmt_v1.dll',b),
 ('i386-windows/wm_dmc001.dll',(source/'i386-windows/winemetal.dll').read_bytes()),
 ('x86_64-unix/wm_dmc001.so',(source/'x86_64-unix/winemetal.so').read_bytes())]:
 p=runtime/'lib/wine'/relative
 assert not p.exists(), 'Refusing overwrite: '+str(p)
 p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
 print(relative,hashlib.sha256(data).hexdigest())
