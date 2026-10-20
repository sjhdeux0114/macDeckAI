#!/usr/bin/env python3
"""Deploy exact App ID 214830 Clear candidate (dxmt-clear-v2); backs up state first.
Locks source SHA-256, preserves other game profiles, updates renderers.ini safely.
"""
from pathlib import Path
import hashlib
import json
import shutil
import sys

app_support = Path.home() / 'Library/Application Support/MacDeck'
runtime_dir = app_support / 'SharedSteamRenderer/Runtime/lib/wine/i386-windows'
prefix_dir = app_support / 'Bottles/Steam'
profiles_file = app_support / 'Compatibility/game-profiles.json'
renderers_file = prefix_dir / 'drive_c/ProgramData/MacDeck/renderers.ini'

source_dll = runtime_dir / 'macdeck_dmc_dxmt_clear_v3.dll'
target_dll = runtime_dir / 'macdeck_hmh_dxmt_clear_v2.dll'

expected_clear_sha = '84a4886fd6ac94d8dff5a680652f52068ccfb4be744aa40468a30b6843126627'
source_data = source_dll.read_bytes()
if hashlib.sha256(source_data).hexdigest() != expected_clear_sha:
    sys.exit(f'Error: source DLL hash mismatch: {hashlib.sha256(source_data).hexdigest()}')

repair_dir = app_support / 'Compatibility/Repairs/hmh-clear-v2-20261019'
repair_dir.mkdir(parents=True, exist_ok=True)

# 1. Backups
profiles_before_data = profiles_file.read_bytes()
renderers_before_data = renderers_file.read_bytes()

(repair_dir / 'game-profiles.json.before').write_bytes(profiles_before_data)
(repair_dir / 'renderers.ini.before').write_bytes(renderers_before_data)

# 2. Deploy candidate DLL
shutil.copy2(source_dll, target_dll)
assert target_dll.exists()
assert hashlib.sha256(target_dll.read_bytes()).hexdigest() == expected_clear_sha

# 3. Update game profiles
profiles_json = json.loads(profiles_before_data.decode('utf-8'))
hmh_found = False
for g in profiles_json['games']:
    if g['id'] == 'steam:214830':
        assert g.get('hmhMetalFix') is True
        g['hmhClearFix'] = True
        g['revision'] = 3
        g['status'] = 'failing'
        g['notes'] = (
            "D9VK는 제거됨. exact App ID214830 전용 Direct Metal v1에서 게임 시작 시 검은 화면 현상 보고. "
            "slot30 native Clear 수정이 포함된 macdeck_hmh_dxmt_clear_v2.dll(dxmt-clear-v2) 후보를 격리 GPU 검사 후 적용. "
            "실제 플레이 성공 여부 확인 대기 중."
        )
        hmh_found = True
        break

assert hmh_found, "Could not find steam:214830 profile"
profiles_after_data = json.dumps(profiles_json, indent=2, ensure_ascii=False).encode('utf-8')
profiles_file.write_bytes(profiles_after_data)

# 4. Update renderers.ini (UTF-16 LE)
renderers_text = renderers_before_data.decode('utf-16')
assert '214830=dxmt-v1' in renderers_text, "Expected '214830=dxmt-v1' in renderers.ini"
renderers_text_after = renderers_text.replace('214830=dxmt-v1', '214830=dxmt-clear-v2')
renderers_after_data = renderers_text_after.encode('utf-16')
renderers_file.write_bytes(renderers_after_data)

# 5. Record restore manifest
manifest = {
    "scope": "exact Steam App ID 214830 only",
    "reason": "HMH black screen on game start due to Clear quad constant slot mismatch (slot 0 vs 30)",
    "before": {
        str(profiles_file): hashlib.sha256(profiles_before_data).hexdigest(),
        str(renderers_file): hashlib.sha256(renderers_before_data).hexdigest(),
    },
    "after": {
        str(profiles_file): hashlib.sha256(profiles_after_data).hexdigest(),
        str(renderers_file): hashlib.sha256(renderers_after_data).hexdigest(),
        str(target_dll): hashlib.sha256(target_dll.read_bytes()).hexdigest(),
    },
    "backupFiles": {
        str(profiles_file): "game-profiles.json.before",
        str(renderers_file): "renderers.ini.before",
    }
}
(repair_dir / 'restore.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False))

print("PASS: HMH dxmt-clear-v2 deployment completed successfully.")
print(f"Target DLL: {target_dll} (SHA-256: {expected_clear_sha})")
print(f"Profile: steam:214830 revision 3, hmhClearFix=true")
print(f"Renderers.ini: 214830=dxmt-clear-v2")
