#!/usr/bin/env python3
"""Account-free exact AppID220440 router/helper GPU check; restores the lab environment."""
from pathlib import Path
import os, subprocess, shutil, hashlib
root=Path(__file__).resolve().parent.parent
runtime=root/'.cache/dmc-d3d9-router-lab/Runtime'
prefix=root/'.cache/dmc-metal-alias-prefix'
renderer=runtime/'lib/wine/i386-windows'
mapping=prefix/'drive_c/ProgramData/MacDeck/renderers.ini'
targets=[renderer/'d3d9.dll',renderer/'macdeck_dmc_query_yield_v1.dll',mapping]
original=[p.read_bytes() if p.exists() else None for p in targets]
try:
    shutil.copy2(root/'.build/d3d9-router/d3d9.dll',targets[0])
    shutil.copy2(root/'.build/dmc-query-yield-v1.dll',targets[1])
    mapping.write_text('[runtime]\r\ndllDirectory32=Z:'+str(renderer).replace('/','\\')+'\r\n[patches]\r\n220440=dxmt-smooth-v5\r\n',encoding='utf16')
    base=os.environ.copy();base.update(WINEPREFIX=str(prefix),WINEDEBUG='-all',WINEMSYNC='0',WINEESYNC='0',WINEDLLOVERRIDES='d3d9=b;mscoree,mshtml=',DYLD_FALLBACK_LIBRARY_PATH=str(runtime/'lib'))
    for appid in ['220440','0','601150','952060','214830']:
        env=base.copy();env['SteamAppId']=appid
        if appid=='220440':env['EXPECT_DMC_YIELD']='1'
        result=subprocess.run([str(runtime/'bin/wine'),str(root/'.build/dmc-query-yield-probe.exe')],env=env,capture_output=True,text=True,timeout=30)
        print('AppID',appid);print(result.stdout,end='')
        if result.returncode!=0:print(result.stderr,end='')
        expected='PASS exact DmC query-yield helper' if appid=='220440' else 'PASS foreign App ID kept original route'
        assert result.returncode==0 and expected in result.stdout
finally:
    for p,data in zip(targets,original):
        if data is None:
            if p.exists(): p.unlink()
        else: p.write_bytes(data)
