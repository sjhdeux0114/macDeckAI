#!/usr/bin/env python3
"""Account-free exact AppID214830 Direct Metal GPU check; restores the lab."""
from pathlib import Path
import os
import shutil
import subprocess

root = Path(__file__).resolve().parent.parent
runtime = root / '.cache/dmc-d3d9-router-lab/Runtime'
prefix = root / '.cache/dmc-metal-alias-prefix'
renderer = runtime / 'lib/wine/i386-windows'
mapping = prefix / 'drive_c/ProgramData/MacDeck/renderers.ini'
sessions = prefix / 'drive_c/ProgramData/MacDeck/RendererSessions'
targets = [renderer / 'd3d9.dll', renderer / 'macdeck_hmh_dxmt_v1.dll', mapping]
original = [path.read_bytes() if path.exists() else None for path in targets]

try:
    shutil.copy2(root / '.build/d3d9-router/d3d9.dll', targets[0])
    shutil.copy2(renderer / 'macdeck_dmc_dxmt_v1.dll', targets[1])
    mapping.write_text(
        '[runtime]\r\ndllDirectory32=Z:' + str(renderer).replace('/', '\\')
        + '\r\n[patches]\r\n214830=dxmt-v1\r\n', encoding='utf16')
    sessions.mkdir(parents=True, exist_ok=True)
    before = {path.name for path in sessions.glob('d3d9-*.log')}
    base = os.environ.copy()
    base.update(
        WINEPREFIX=str(prefix), WINEDEBUG='-all', WINEMSYNC='0', WINEESYNC='0',
        WINEDLLOVERRIDES='d3d9=b;mscoree,mshtml=',
        DYLD_FALLBACK_LIBRARY_PATH=str(runtime / 'lib'))
    for appid in ['214830', '0', '220440', '601150', '952060']:
        env = base.copy(); env['SteamAppId'] = appid
        result = subprocess.run(
            [str(runtime / 'bin/wine'), str(root / '.build/game-d3d9-probe.exe')],
            env=env, capture_output=True, text=True, timeout=45)
        print('AppID', appid); print(result.stdout, end='')
        if result.returncode != 0: print(result.stderr, end='')
        assert result.returncode == 0 and 'PASS D3D9 GPU clear/readback' in result.stdout
    new_logs = [path for path in sessions.glob('d3d9-*.log') if path.name not in before]
    combined = ''.join(path.read_text(errors='replace') for path in new_logs)
    assert 'd3d9=dxmt-metal-v1 appid=214830' in combined
    assert combined.count('d3d9=dxmt-metal-v1 appid=214830') >= 1
    assert 'd3d9=dxmt-metal-v1 appid=220440' not in combined
    print('PASS exact HMH route and four foreign App IDs preserved')
finally:
    for path, data in zip(targets, original):
        if data is None:
            if path.exists(): path.unlink()
        else:
            path.write_bytes(data)
