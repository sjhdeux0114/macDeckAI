#!/usr/bin/env python3
"""Run account-free GPU Clear regression probes in the existing isolated lab.
Never chooses the production Steam prefix and never installs renderer files.
Prepare the private candidate + dxmt-clear-v2 map in this lab before running.
"""
from pathlib import Path
import os, subprocess, hashlib
root = Path(__file__).resolve().parent.parent
runtime = root / '.cache/dmc-d3d9-router-lab/Runtime'
prefix = root / '.cache/dmc-metal-alias-prefix'
assert not prefix.is_symlink() and prefix.resolve().is_relative_to(root / '.cache')
configuration = (prefix / 'drive_c/ProgramData/MacDeck/renderers.ini').read_text(encoding='utf16')
assert any(value in configuration for value in ['220440=dxmt-clear-v2', '220440=dxmt-bind-v3']), 'Requires explicitly prepared isolated candidate'
mode = 'dxmt-bind-v3' if '220440=dxmt-bind-v3' in configuration else 'dxmt-clear-v2'
if mode == 'dxmt-bind-v3':
    candidate = runtime / 'lib/wine/i386-windows/macdeck_dmc_dxmt_clear_v3.dll'
    assert hashlib.sha256(candidate.read_bytes()).hexdigest() == '84a4886fd6ac94d8dff5a680652f52068ccfb4be744aa40468a30b6843126627'
compiler = root / '.cache/llvm-mingw/llvm-mingw-20261006-ucrt-macos-universal/bin/i686-w64-mingw32-clang++'
environment = os.environ.copy()
environment.update(WINEPREFIX=str(prefix), WINEDEBUG='-all', WINEMSYNC='0', WINEESYNC='0', SteamAppId='220440', WINEDLLOVERRIDES='d3d9=b;mscoree,mshtml=', DYLD_FALLBACK_LIBRARY_PATH=str(runtime / 'lib'))
for stem in ['wine-dmc-depth-clear-probe', 'wine-dmc-color-clear-probe', 'wine-dmc-sm3-probe']:
    executable = root / '.build' / (stem + '.exe')
    subprocess.run([str(compiler), '-O2', '-static', str(root / 'scripts' / (stem + '.cpp')), '-o', str(executable), '-ld3d9', '-ld3dcompiler'], check=True)
    logfile = root / 'evidence' / (stem + '-isolated.log')
    with logfile.open('w') as output:
        output.write('candidate_mode=' + mode + '\n'); output.flush()
        result = subprocess.run([str(runtime / 'bin/wine'), str(executable)], env=environment, stdout=output, stderr=output, timeout=30)
    logfile.write_text('\n'.join(line.rstrip() for line in logfile.read_text().splitlines()) + '\n')
    assert result.returncode == 0, f'{stem}: exit {result.returncode}; see {logfile}'
    print('PASS', stem)
