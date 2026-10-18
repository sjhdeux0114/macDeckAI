#!/usr/bin/env python3
"""Read only minidump directory, exception and module metadata; never dump memory."""
from pathlib import Path, PureWindowsPath
import struct,json,sys

def inspect(path):
 with path.open('rb') as f:
  def read(offset,size):
   f.seek(offset);data=f.read(size)
   if len(data)!=size:raise ValueError('truncated metadata')
   return data
  header=read(0,32)
  if header[:4]!=b'MDMP':raise ValueError('not a minidump')
  count,offset=struct.unpack_from('<II',header,8)
  if count>1000:raise ValueError('invalid stream count')
  streams={}
  for i in range(count):
   kind,size,rva=struct.unpack('<III',read(offset+i*12,12));streams[kind]=(size,rva)
  modules=[]
  if 4 in streams:
   count=struct.unpack('<I',read(streams[4][1],4))[0]
   if count>10000:raise ValueError('invalid module count')
   for i in range(count):
    entry=read(streams[4][1]+4+i*108,108);base,size=struct.unpack_from('<QI',entry);name_rva=struct.unpack_from('<I',entry,20)[0]
    n=struct.unpack('<I',read(name_rva,4))[0]
    name=PureWindowsPath(read(name_rva+4,min(n,4096)).decode('utf-16-le',errors='replace')).name
    modules.append((base,size,name))
  def resolve(addr):
   for base,size,name in modules:
    if base<=addr<base+size:return name+'+0x'+format(addr-base,'x')
   return hex(addr)
  result={'file':path.name}
  if 6 in streams:
   entry=read(streams[6][1],168);code=struct.unpack_from('<I',entry,8)[0];address=struct.unpack_from('<Q',entry,24)[0];n=struct.unpack_from('<I',entry,32)[0]
   result.update(exception=hex(code),location=resolve(address),parameters=[hex(x) for x in struct.unpack_from('<'+'Q'*min(n,15),entry,40)])
   context_size,context_rva=struct.unpack_from('<II',entry,160)
   if context_size>=256:
    context=read(context_rva,256);result['instruction']=resolve(struct.unpack_from('<Q',context,248)[0])
  return result
if __name__=='__main__':
 for arg in sys.argv[1:]:print(json.dumps(inspect(Path(arg)),ensure_ascii=False))
