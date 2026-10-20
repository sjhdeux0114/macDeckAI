#!/usr/bin/env python3
"""Account-free Epic exact-file routing, D3D12 Metal and foreign D3D11 GPU test."""
from pathlib import Path
import os
import shutil
import subprocess

root = Path(__file__).resolve().parent.parent
runtime = Path.home() / 'Library/Application Support/MacDeck/SharedSteamRenderer/Runtime'
prefix = root / '.cache/epic-metal-gpu-prefix'
routers = root / '.build/epic-router'
game = root / '.build/epic-metal-game/HogwartsLegacy.exe'
foreign = root / '.build/epic-foreign-game/HogwartsLegacy.exe'
identity = 'fa4240e57a3c46b39f169041b7811293'
environment = os.environ.copy()
environment.update(
    WINEPREFIX=str(prefix), WINEDEBUG='-all', WINEMSYNC='0', WINEESYNC='0',
    WINEDLLOVERRIDES='winemenubuilder.exe=d;winedbg.exe=d;mscoree,mshtml=;dxgi,d3d11,d3d12,d3d12core=n,b',
    DYLD_FALLBACK_LIBRARY_PATH=str(runtime / 'lib') + ':' + str(runtime / 'lib/external'),
    DYLD_FRAMEWORK_PATH=str(runtime / 'lib/external'),
    D3DMETAL_FRAMEWORK_PATH=str(runtime / 'lib/external/D3DMetal.framework/D3DMetal'),
    D3DM_MTL4='0', SteamAppId='1245620')  # A foreign inherited Steam ID must not select Apple.

def run(arguments, timeout=45):
    result = subprocess.run([str(runtime / 'bin/wine')] + arguments, env=environment,
                            capture_output=True, text=True, timeout=timeout)
    print(result.stdout, end='', flush=True)
    if result.returncode:
        print(result.stderr[-8000:], flush=True)
        raise RuntimeError(f'probe exit {result.returncode}')
    return result.stdout

prefix.mkdir(parents=True, exist_ok=True)
run(['wineboot', '-u'], timeout=60)
for name in ['dxgi', 'd3d11', 'd3d12', 'd3d12core']:
    shutil.copy2(routers / (name + '.dll'), prefix / ('drive_c/windows/system32/' + name + '.dll'))
for target, source in [(game, 'game-d3d12-probe.exe'), (foreign, 'game-d3d11-probe.exe')]:
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / '.build' / source, target)
data = prefix / 'drive_c/ProgramData/MacDeck'
data.mkdir(parents=True, exist_ok=True)
directory = 'Z:' + str(runtime / 'lib/wine/x86_64-windows').replace('/', '\\')
expected = 'Z:' + str(game).replace('/', '\\')
(data / 'renderers.ini').write_text(
    '[runtime]\r\ndllDirectory=' + directory + '\r\n[renderers]\r\ndefault=dxmt\r\n0=dxmt\r\n'
    + identity + '=metal\r\n[epic-paths]\r\n' + identity + '=' + expected + '\r\n', encoding='utf16')
link = prefix / 'dosdevices/e:'
if link.is_symlink():
    assert link.resolve() == game.parent.resolve()
elif link.exists():
    raise RuntimeError('unexpected E: mapping')
else:
    link.symlink_to(game.parent)
output = run(['E:\\HogwartsLegacy.exe'])
assert 'PASS D3D12 GPU clear/copy/fence/readback' in output
output = run([str(foreign)])
assert 'PASS' in output
logs = list((data / 'RendererSessions').glob(identity + '-*.log'))
assert logs and any('renderer=metal' in file.read_text() for file in logs)
foreign_logs = list((data / 'RendererSessions').glob('0-*.log'))
assert foreign_logs and any('module=d3d11 renderer=dxmt' in file.read_text() for file in foreign_logs)
assert not list((data / 'RendererSessions').glob('1245620-*.log'))
print('PASS exact Epic file via E:/Z: alias -> Apple D3D12; same-name foreign executable -> DXMT; inherited Steam ID ignored')
