#!/usr/bin/env python3
"""Explicit local Epic-only trial deployment. No game or Steam files are changed."""
from pathlib import Path
import hashlib
import json
import subprocess
import time

root = Path(__file__).resolve().parent.parent
home = Path.home() / 'Library/Application Support/MacDeck'
database = home / 'Compatibility/game-profiles.json'
identity = 'epic:fa4240e57a3c46b39f169041b7811293'
original = database.read_bytes()
profiles = json.loads(original)
matches = [item for item in profiles['games'] if item['id'] == identity]
assert len(matches) == 1 and not matches[0].get('baseline')
profile = matches[0]
assert not profile.get('epicMetalFix'), 'Already enabled; inspect existing backup instead of overwriting it'
backup = home / 'Compatibility/Repairs/epic-hogwarts-metal-20261020'
backup.mkdir(parents=True, exist_ok=False)
(backup / 'game-profiles.json.before').write_bytes(original)
library = json.loads((home / 'library.json').read_text())
runtime = Path(library['winePath']).parent.parent
protected = [runtime / 'lib/wine/x86_64-windows/macdeck_dxmt_gsts_v1_d3d11.dll',
             runtime / 'lib/wine/i386-windows/d3d9.dll',
             home / 'Bottles/Steam/drive_c/ProgramData/MacDeck/renderers.ini']
before = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in protected}
profile['epicMetalFix'] = True
profile['revision'] = profile.get('revision', 1) + 1
profile['status'] = 'failing'
profile['updated'] = time.time() - 978307200
profile['notes'] = ('2026-10-20 VC++ requirement passed; DX12 initialization failed. '
                    'Exact Epic ID/executable Apple D3DMetal trial; isolated GPU PASS; actual gameplay unverified.')
temp = database.with_suffix('.json.new')
temp.write_text(json.dumps(profiles, ensure_ascii=False, indent=2, sort_keys=True) + '\n')
temp.replace(database)
result = subprocess.run([
    str(root / 'dist/MacDeck.app/Contents/MacOS/MacDeck'),
    '--prepare-epic-renderers', str(root / '.build/epic-router')], timeout=60)
if result.returncode:
    database.write_bytes(original)
    raise SystemExit(result.returncode)
after = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in protected}
assert before == after, 'Protected Steam assets changed unexpectedly'
for old, new in zip(json.loads(original)['games'], profiles['games']):
    assert old['id'] == identity or old == new, 'Foreign profile changed'
(backup / 'deployment.json').write_text(json.dumps({
    'identity': identity, 'revision': profile['revision'], 'status': 'failing',
    'protectedSteamFiles': before, 'foreignProfilesUnchanged': True,
}, indent=2) + '\n')
print('PASS exact Epic trial enabled; Steam assets and foreign profiles unchanged; actual game test required')
