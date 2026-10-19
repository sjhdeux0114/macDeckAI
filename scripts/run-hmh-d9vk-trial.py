#!/usr/bin/env python3
"""Run the verified local HMH D9VK candidate; never installs/replaces a DLL."""
import csv
import datetime
import hashlib
import json
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = pathlib.Path.home() / 'Library/Application Support/MacDeck'


def main():
    library = json.loads((DATA / 'library.json').read_text())
    game = next((g for g in library['games'] if str(g.get('steamAppID')) == '214830'), None)
    if not game or not game.get('installedLocation'):
        raise SystemExit('MacDeck에서 30초전사 설치 게임을 먼저 가져와 주세요.')
    exe = pathlib.Path(game['installedLocation']) / 'HMH.exe'
    dll = exe.parent / 'd3d9.dll'
    trial = json.loads((ROOT / 'evidence/hmh-d9vk-file.json').read_text())
    if pathlib.Path(trial['target']).resolve() != dll.resolve() or not dll.is_file() or hashlib.sha256(dll.read_bytes()).hexdigest() != trial['sha256']:
        raise SystemExit('기록한 시험 DLL과 게임 폴더가 다릅니다. 파일을 변경하지 않고 중단합니다.')
    apps = [pathlib.Path('/Applications/MacDeck.app'), pathlib.Path.home() / 'Applications/MacDeck.app', ROOT / 'dist/MacDeck.app']
    app = next((p for p in apps if (p / 'Contents/Resources/Runtime/bin/wine').is_file()), None)
    if app is None:
        raise SystemExit('MacDeck 앱 런타임을 찾을 수 없습니다.')
    runtime = app / 'Contents/Resources/Runtime'
    wine = runtime / 'bin/wine'
    collector = app / 'Contents/MacOS/graphics-log-filter'
    prefix = pathlib.Path(game.get('prefix') or DATA / 'Bottles/Steam')
    env = dict(os.environ)
    env.update({'WINEPREFIX': str(prefix), 'WINEMSYNC': '0', 'WINEESYNC': '0', 'WINEDEBUG': '-all,err+d3d,err+d3d9,err+vulkan,warn+vulkan', 'MTL_HUD_ENABLED': '0', 'DYLD_FALLBACK_LIBRARY_PATH': str(runtime / 'lib') + ':' + str(runtime / 'Media/lib')})
    tasks = subprocess.run([str(wine), 'tasklist.exe', '/fo', 'csv', '/nh'], env=env, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=20, check=True)
    names = {row[0].lower() for row in csv.reader(tasks.stdout.decode('utf-8', errors='replace').splitlines()) if row}
    if 'hmh.exe' in names:
        raise SystemExit('30초전사가 이미 실행 중입니다. 종료 후 다시 실행해 주세요.')
    if 'steam.exe' not in names:
        subprocess.Popen([str(wine), game['path'], '-silent'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print('Steam을 시작했습니다. 직접 로그인한 뒤 이 시험 실행기를 다시 실행해 주세요.')
        return 2
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H-%M-%SZ')
    folder = DATA / 'Logs/HMH-D9VK-Trials' / stamp
    folder.mkdir(parents=True)
    config = folder / 'dxvk.conf'
    config.write_text('d3d9.maxFrameRate = 60\n')
    env.update({'SteamAppId': '214830', 'SteamGameId': '214830', 'WINEDLLOVERRIDES': 'winemenubuilder.exe=d;winedbg.exe=d;d3d9=n;d3dx9_42=b;d3d11,dxgi,d3d10core=b;mfplat,mfreadwrite,mf,mfmediaengine,winegstreamer=b;quartz,amstream=b', 'DXVK_CONFIG_FILE': str(config), 'DXVK_LOG_PATH': str(folder), 'DXVK_STATE_CACHE_PATH': str(folder)})
    media = runtime / 'Media'
    if (media / 'lib/libgstreamer-1.0.0.dylib').is_file():
        env.update({'GST_PLUGIN_SYSTEM_PATH_1_0': str(media / 'lib/gstreamer-1.0'), 'GST_PLUGIN_PATH_1_0': '', 'GST_PLUGIN_SCANNER_1_0': str(media / 'libexec/gstreamer-1.0/gst-plugin-scanner'), 'GST_REGISTRY_1_0': str(DATA / 'Logs/gst-registry-x86_64.bin')})
    record = {'game': game['name'], 'steamAppID': '214830', 'backend': 'experimental patched D9VK -> MoltenVK -> Metal', 'dllSHA256': trial['sha256'], 'size': '1280x720', 'WINEMSYNC': '0', 'WINEESYNC': '0', 'status': 'starting', 'note': 'Steam remains responsible for authentication/ownership. An Explorer exit code is not proof of game success. This is not the normal MacDeck launch profile.'}
    metadata = folder / 'trial.json'
    metadata.write_text(json.dumps(record, indent=2))
    print('시험 실행입니다. 타이틀/플레이 성능과 화면 잘림을 확인해 주세요. 로그:', folder)
    with subprocess.Popen([str(collector), str(folder / 'graphics-stderr.log')], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as log:
        process = subprocess.Popen([str(wine), 'explorer.exe', '/desktop=HMH,1280x720', str(exe), '-console'], env=env, cwd=exe.parent, stdout=subprocess.DEVNULL, stderr=log.stdin)
        log.stdin.close()
        record.update({'status': 'launcher-exited', 'launcherExitCode': process.wait()})
        metadata.write_text(json.dumps(record, indent=2))
        log.wait()
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error))
