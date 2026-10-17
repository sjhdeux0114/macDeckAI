#!/usr/bin/env python3
"""Exercise a mapped storage folder through an actual Windows process."""
import os
from pathlib import Path
import subprocess
import uuid

root = Path(__file__).resolve().parent.parent
work = root / '.cache' / ('external-storage-' + uuid.uuid4().hex)
prefix = work / 'prefix'
storage = work / 'External Disk 한글'
storage.mkdir(parents=True)
(prefix / 'dosdevices').mkdir(parents=True)
(prefix / 'drive_c').mkdir()
(prefix / 'dosdevices/c:').symlink_to('../drive_c', target_is_directory=True)
(prefix / 'dosdevices/z:').symlink_to('/', target_is_directory=True)
(prefix / 'dosdevices/d:').symlink_to(storage, target_is_directory=True)
for name in ['Desktop', 'Documents', 'Downloads', 'Music', 'Pictures', 'Videos']:
    (prefix / 'drive_c/users' / os.environ.get('USER', 'user') / name).mkdir(parents=True, exist_ok=True)
runtime = root / 'dist/MacDeck.app/Contents/Resources/Runtime'
env = os.environ.copy()
env.update(WINEPREFIX=str(prefix), DYLD_FALLBACK_LIBRARY_PATH=str(runtime / 'lib'), WINEDEBUG='-all', WINEDLLOVERRIDES='winemenubuilder.exe=d;mscoree,mshtml=')
try:
    result = subprocess.run([str(runtime / 'bin/wine'), 'cmd.exe', '/c', r'echo MACDECK_EXTERNAL_WRITE>D:\write-check.txt'], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
finally:
    subprocess.run([str(runtime / 'bin/wineserver'), '-k'], env=env, timeout=15)
print(result.stdout.decode(errors='replace'))
assert result.returncode == 0, result.returncode
assert (storage / 'write-check.txt').read_text().strip() == 'MACDECK_EXTERNAL_WRITE'
print('PASS: actual Windows cmd.exe wrote through D: into the mapped Unicode storage folder')
print('Isolated test data:', work)
