#!/usr/bin/env python3
"""Account-free exact AppID214830 Clear candidate GPU probes; restores lab."""
from pathlib import Path
import hashlib
import os
import shutil
import subprocess

root = Path(__file__).resolve().parent.parent
runtime = root / '.cache/dmc-d3d9-router-lab/Runtime'
prefix = root / '.cache/dmc-metal-alias-prefix'
renderer = runtime / 'lib/wine/i386-windows'
mapping = prefix / 'drive_c/ProgramData/MacDeck/renderers.ini'
source = renderer / 'macdeck_dmc_dxmt_clear_v3.dll'
candidate = renderer / 'macdeck_hmh_dxmt_clear_v2.dll'
targets = [renderer / 'd3d9.dll', candidate, mapping]
original = [path.read_bytes() if path.exists() else None for path in targets]
assert hashlib.sha256(source.read_bytes()).hexdigest() == '84a4886fd6ac94d8dff5a680652f52068ccfb4be744aa40468a30b6843126627'
compiler = root / '.cache/llvm-mingw/llvm-mingw-20261006-ucrt-macos-universal/bin/i686-w64-mingw32-clang++'

try:
    shutil.copy2(root / '.build/d3d9-router/d3d9.dll', targets[0])
    shutil.copy2(source, candidate)
    mapping.write_text(
        '[runtime]\r\ndllDirectory32=Z:' + str(renderer).replace('/', '\\')
        + '\r\n[patches]\r\n214830=dxmt-clear-v2\r\n', encoding='utf16')
    environment = os.environ.copy()
    environment.update(
        WINEPREFIX=str(prefix), WINEDEBUG='-all', WINEMSYNC='0', WINEESYNC='0',
        SteamAppId='214830', WINEDLLOVERRIDES='d3d9=b;mscoree,mshtml=',
        DYLD_FALLBACK_LIBRARY_PATH=str(runtime / 'lib'))
    for stem in ['wine-dmc-depth-clear-probe', 'wine-dmc-color-clear-probe', 'wine-dmc-sm3-probe']:
        executable = root / '.build' / (stem + '.exe')
        subprocess.run([
            str(compiler), '-O2', '-static', str(root / 'scripts' / (stem + '.cpp')),
            '-o', str(executable), '-ld3d9', '-ld3dcompiler'], check=True)
        result = subprocess.run(
            [str(runtime / 'bin/wine'), str(executable)], env=environment,
            capture_output=True, text=True, timeout=30)
        print(stem); print(result.stdout, end='')
        if result.returncode != 0: print(result.stderr, end='')
        assert result.returncode == 0
    for appid in ['0', '220440', '601150', '952060']:
        foreign = environment.copy(); foreign['SteamAppId'] = appid
        result = subprocess.run(
            [str(runtime / 'bin/wine'), str(root / '.build/game-d3d9-probe.exe')],
            env=foreign, capture_output=True, text=True, timeout=30)
        assert result.returncode == 0 and 'Adapter: NVIDIA GeForce 6800' in result.stdout
    print('PASS exact HMH Clear route and four foreign App IDs preserved')
finally:
    for path, data in zip(targets, original):
        if data is None:
            if path.exists(): path.unlink()
        else:
            path.write_bytes(data)
