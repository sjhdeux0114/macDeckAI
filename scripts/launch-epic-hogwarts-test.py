#!/usr/bin/env python3
"""Ask the logged-in Epic launcher to start the exact manifest game; discard auth-bearing output."""
from pathlib import Path
from urllib.parse import quote
import json
import os
import subprocess

home = Path.home() / 'Library/Application Support/MacDeck'
prefix = home / 'Bottles/EpicGames'
runtime = Path(json.loads((home / 'library.json').read_text())['winePath']).parent.parent
marker = prefix / 'drive_c/ProgramData/MacDeck/epic-renderers.json'
assert marker.read_text() == str(runtime)
identity = 'fa4240e57a3c46b39f169041b7811293'
items = []
for file in (prefix / 'drive_c/ProgramData/Epic/EpicGamesLauncher/Data/Manifests').glob('*.item'):
    item = json.loads(file.read_text())
    if item.get('AppName') == identity:
        items.append({key: item.get(key) for key in ['AppName', 'CatalogNamespace', 'CatalogItemId']})
assert len(items) == 1
item = items[0]
assert all(isinstance(value, str) and value for value in item.values())
uri = 'com.epicgames.launcher://apps/' + quote(':'.join([item['CatalogNamespace'], item['CatalogItemId'], item['AppName']]), safe='') + '?action=launch&silent=true'
environment = os.environ.copy()
for key in ['SteamAppId', 'SteamGameId', 'SteamOverlayGameId']:
    environment.pop(key, None)
environment.update(
    WINEPREFIX=str(prefix), WINEDEBUG='-all', WINEMSYNC='1', WINEESYNC='0', WINEMSYNC_QLIMIT='512',
    WINEDLLOVERRIDES='winemenubuilder.exe=d;winedbg.exe=d;mshtml=;dxgi,d3d11,d3d12,d3d12core=n,b;gameoverlayrenderer,gameoverlayrenderer64=d',
    DYLD_FALLBACK_LIBRARY_PATH=str(runtime / 'lib') + ':' + str(runtime / 'lib/external'),
    DYLD_FRAMEWORK_PATH=str(runtime / 'lib/external'),
    D3DMETAL_FRAMEWORK_PATH=str(runtime / 'lib/external/D3DMetal.framework/D3DMetal'),
    D3DM_MTL4='0', MTL_HUD_ENABLED='1', DXMT_CONFIG='dxgi.handleAltTab=True')
launchers = list((prefix / 'drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64').glob('EpicGamesLauncher.exe'))
if not launchers:
    launchers = list((prefix / 'drive_c/Program Files/Epic Games/Launcher/Portal/Binaries/Win64').glob('EpicGamesLauncher.exe'))
assert len(launchers) == 1
process = subprocess.Popen([str(runtime / 'bin/wine'), str(launchers[0]), '-SkipBuildPatchPrereq', '-ForceDX11', uri],
                           env=environment, cwd=launchers[0].parent,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
print('Epic exact Hogwarts launch requested; PID', process.pid)
