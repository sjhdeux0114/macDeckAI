#!/usr/bin/env python3
"""Explicit maintenance only; refuse cleanup while any owned game process runs."""
from pathlib import Path
import os,signal,subprocess,sys
project=Path(__file__).resolve().parent.parent
support=Path.home()/'Library/Application Support/MacDeck'
roots=[project/'dist/MacDeck.app/Contents/Resources/Runtime',project/'.cache/common-steam-runtime',support/'SharedSteamRenderer/Runtime']
roots += list((support/'GameTrials').glob('*/Runtime'))
roots=[str(p.resolve())+'/' for p in roots]
helpers={'steam.exe','steamwebhelper.exe','steamservice.exe','services.exe','plugplay.exe','svchost.exe','winedevice.exe','explorer.exe','rpcss.exe','conhost.exe','winedbg.exe','cmd.exe','wineboot.exe','rundll32.exe','wineserver','wine-preloader','wine64-preloader'}
rows=subprocess.run(['/bin/ps','-axo','pid=,comm='],capture_output=True,text=True,check=True).stdout.splitlines()
candidates=[];blocked=[]
for row in rows:
 a=row.strip().split(None,1)
 if len(a)!=2:continue
 pid=int(a[0]);name=a[1].replace('\\','/').rsplit('/',1)[-1].lower()
 if pid==os.getpid() or not (name.endswith('.exe') or name in helpers):continue
 result=subprocess.run(['/usr/sbin/lsof','-a','-p',str(pid),'-d','txt','-Fn'],capture_output=True,text=True)
 owned=any(line.startswith('n'+root) for line in result.stdout.splitlines() for root in roots)
 if not owned:continue
 if name not in helpers:blocked.append((pid,name))
 else:candidates.append((pid,name))
if blocked:
 print('REFUSED: owned game/non-helper processes still run:',blocked);sys.exit(2)
for pid,name in candidates:
 print('OWNED_HELPER',pid,name)
 if '--apply' in sys.argv:
  try:os.kill(pid,signal.SIGKILL)
  except ProcessLookupError:pass
print('APPLIED' if '--apply' in sys.argv else 'DRY_RUN',len(candidates))
