#!/usr/bin/env python3
"""Check native fix identity and refusal rules against the cached release only."""
from pathlib import Path
import tempfile,subprocess,sys,hashlib,json
root=Path(__file__).resolve().parent.parent
source=root/'.cache/dmc-d3d9-router-lab/Runtime/lib/wine/i386-windows/macdeck_dmc_dxmt_clear_v3.dll'
original=source.read_bytes();patcher=root/'scripts/prepare-dmc-bc-srgb.py'
with tempfile.TemporaryDirectory() as td:
 target=Path(td)/'fixed.dll'
 p=subprocess.run([sys.executable,str(patcher),str(source),str(target)],capture_output=True,text=True,check=True)
 fixed=target.read_bytes();report=json.loads(p.stdout)
 assert len(fixed)==len(original) and [i for i,(a,b) in enumerate(zip(original,fixed)) if a!=b]==list(range(840678,840684))
 assert source.read_bytes()==original and report['changedBytes']==6
 assert hashlib.sha256(fixed).hexdigest()=='def19eca660d29eb9065624971a2b3003a59a21896e1e62d58c096404f54a719'
 print('PASS exact six-byte branch correction and original preservation')
 p=subprocess.run([sys.executable,'-O',str(patcher),str(source),str(target)],capture_output=True)
 assert p.returncode!=0 and target.read_bytes()==fixed
 print('PASS refuses overwrite including optimized Python')
 wrong=Path(td)/'unknown.dll';wrong.write_bytes(b'unknown input');out=Path(td)/'must-not-exist.dll'
 p=subprocess.run([sys.executable,'-O',str(patcher),str(wrong),str(out)],capture_output=True)
 assert p.returncode!=0 and not out.exists()
 print('PASS refuses unknown input including optimized Python')
