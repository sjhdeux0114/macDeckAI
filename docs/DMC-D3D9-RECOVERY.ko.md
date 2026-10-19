# DmC220440 D3D9 실행 복구 — 2026-10-19

> 최신: 아래 D9VK 실험은 사용 불가능한 성능이라는 사용자 보고로 철회했습니다. D9VK 재활성화는 프로필 검증에서 거부합니다. 현재 경로는 이 문서 끝의 직접 Metal 수정본입니다.

## 확인한 실패 경로

DmC는 DMC5와 다른 32비트 UE3/D3D9 게임이다. .NET4/VC 기능 검사를 통과한 일반 Steam 환경에서 접근 위반 `0183c9b4`로 종료됐다. 게임 실행 파일은 수정하지 않았다.

선별한 WineD3D 로그에서 DXT5 텍스처 생성이 `0x8876086c`로 실패한 직후 같은 주소의 접근 위반이 확인됐다. 해당 주소의 코드는 생성 결과 객체를 역참조한다. `evidence/dmc-texture-failure-20261019.log`가 직접 근거다. 과거 AppleDouble 중복 패키지 경고와 런타임 누락은 앞서 별도로 처리했으며 이번 문제와 구분한다.

Valve의 [원본 호환성 이슈](https://github.com/ValveSoftware/Proton/issues/820)는 .NET/XAudio2 관련 이력을 제공하지만 현재 크래시의 근본 원인이나 해결 검증을 대신하지 않는다.

## 선택한 수정과 범위

- `scripts/wine-dmc-dxt5-probe.cpp`: DXT5 정적/동적 텍스처 생성·업로드 및 실제 GPU clear/readback/Present 검사. 정적 DEFAULT 텍스처는 SYSTEMMEM staging으로 업로드한다.
- 기존 WineD3D Vulkan: DXT5 생성 실패 재현.
- 보관된 D9VK 후보: DXT5 생성·업로드와 GPU 검사 통과. Vulkan → MoltenVK → Metal 경로이며 소프트웨어 렌더러가 아니다.
- `scripts/d3d9-game-router.cpp`: 정확한 `SteamAppId=220440`와 관리 `[patches]220440=d9vk-v1`에서만 별도 후보를 선택한다. 그 외에는 원본 D3D9 별칭으로 전달한다.
- `scripts/build-d3d9-game-router.py`: i386 14개 export와 ordinal 및 호출 스택을 보존하는 trampoline을 생성한다. 기존 `d3d9=b` 환경을 유지하기 위해 Wine builtin marker를 포함한다.
- 프로필 `dmcD9VKFix`는 기본 비활성이며 다른 AppID나 보호 기준이 있는 프로필의 활성화를 거부한다. 실제 후보 fingerprint를 기준 검사에 포함한다.

게임 폴더·EXE·INI·Steam 인증 설정은 수정하지 않는다. 별도 런타임/인증 없는 prefix에서 먼저 검증한 뒤 일반 Steam 런타임에 적용했다. 공유 i386 D3D9 선택기 파일은 공통 코드 변경이므로 기존 정상 보호 기준에 변경이 감지될 수 있으며 기준을 자동 갱신하지 않는다. 다른 게임의 장시간 회귀를 완료했다는 의미는 아니다.

## 비교와 실제 실행 결과

- 별도 환경에서 원본 D3D9와 기본 선택기 경로는 모두 기존 readback pixel0/exit6. 이 실패를 해결했다고 주장하지 않는다. DmC 후보 경로의 DXT5/GPU 검사만 통과했다.
- 일반 Steam 환경에서 수정 후 DmC가 `macdeck_dmc_d9vk_v1.dll`을 로드하고 25초 이상 생존, 게임 소유 창 `DMC-DevilMayCry (32-bit, DX9)` 표시 확인.
- 실제 타이틀·새 게임·플레이 안정성·게임패드·FPS는 사용자 확인 대기다. 단순 프로세스 생존을 플레이 성공으로 승격하지 않는다.

## 백업과 유지

일반 데이터 폴더의 `Compatibility/Repairs/dmc-d9vk-20261019/restore.json`에 수정 대상·원본 존재 여부·해시와 백업이 있다. 원본 D3D9는 `macdeck_original_d3d9.dll`, 후보는 `macdeck_dmc_d9vk_v1.dll`로 따로 보관한다. 이번 프로필 revision은 3이며 상태는 failing 유지다. DMC5 프로필과 x64 렌더러는 보존했다.

복원 시 Steam/게임을 종료하고 manifest에 따라 원본을 복원한다. 이 후보를 다른 게임이나 새 DLL 버전에 자동 적용하지 않는다. 새 설치에 프로필 옵션만 복사하면 후보·선택기가 없으므로 별도 검증된 설치 절차가 필요하다.


## 사용자 금지 반영: 직접 Metal 수정본 (revision5)

정상 로그에서도 타이틀부터 심한 버벅임을 사용자에게 확인받았다. D9VK 경로를 해제하고 `dmcD9VKFix=true`를 검증에서 거부한다. D3D9 선택기에도 D9VK 분기가 없다.

`dmcMetalFix=true`와 `[patches]220440=dxmt-v1`에서만 직접 Metal DXMT D3D9를 사용한다. 다른 게임과 기본 선택은 기존 원본 D3D9를 유지한다. 별도 구성요소 이름은 다음과 같다.

- `lib/wine/i386-windows/macdeck_dmc_dxmt_v1.dll`
- `lib/wine/i386-windows/wm_dmc001.dll`
- `lib/wine/x86_64-unix/wm_dmc001.so`
- 기존 prefix의 `drive_c/windows/syswow64/wm_dmc001.dll` 등록 파일.

`prepare-dmc-metal-aliases.py`는 원본 3개 해시를 고정하고, D3D9 import의 winemetal 이름만 같은 길이의 전용 이름으로 바꾼다. 기존 공통 Metal DLL/Unix 파일을 교체하지 않는다. Wine loader의 builtin Unix 탐색 규칙에 맞춰 전용 DLL과 Unix 쌍을 로드한다. 일반 이름의 DLL만 따로 로드한 앞선 실험은 제한시간 실패하여 사용하지 않았다.

별도 환경에서 DXT5 생성·업로드·GPU readback·Present 및 600프레임+5Reset 검사가 통과했다(1907ms). 합성 검사 시간이며 게임 FPS가 아니다. 일반 prefix 첫 실행은 전용 등록 파일 누락으로 실패했으며, 새 prefix wineboot가 생성했던 파일을 기존 환경에도 등록한 뒤 게임 창이 표시됐다. lsof에서 전용 DLL2개와 Unix 모듈 로드 및 D9VK 미로드를 확인했다. 실제 타이틀/플레이 성능은 사용자 확인 대기다.

백업은 `Compatibility/Repairs/dmc-direct-metal-20261019/restore.json`에 추가 등록 파일까지 기록했다. 다른 게임 프로필과 DMC5 보완판은 보존했고 정상 기준을 자동 갱신하지 않았다. 최종 자체 검사162개 및 strict 서명 검사 통과. 새 배포에서는 이 전용 구성요소와 등록 파일이 모두 필요하며 프로필만 옮기면 안 된다.

## 2026-10-19 - Partial Clear experiment and remaining color defect

The current production DmC profile is revision7/failing. D9VK remains retired.
The optional `dmcClearFix` defaults to false; it requires the exact AppID220440,
private direct Metal, and no protected baseline. `dxmt-clear-v2` is a laboratory
candidate, not an automatically deployed renderer. Do not enable this map value
against the old production router: only the newly compiled experimental router
understands it. The installed production map remains `220440=dxmt-v1`.

Actual new-game reproduction shows a working opening movie followed by HUD over
a black scene. The viewport is1512x982 and depth allocation1512x984. A GPU-only
reproducer independently demonstrates incorrect partial color/depth Clear values.
A normal programmable SM3 triangle to FP16 works, separating basic shader support
from this Clear defect.

`scripts/dmc-depth-clear.hpp` preserves state and the requested viewport/scissor
while drawing the Clear value. The exact-game experimental router retains the
original full-clear fast path, explicit-rectangle calls and MRT behavior. Separate
GPU tests verify expected color/depth pixels, viewport restoration and untouched
padding. Run `python3 scripts/test-dmc-clear-gpu.py` only after preparing the
account-free candidate lab referenced in that script; it refuses a production
prefix and does not deploy binaries.

Bounded180/1200-frame actual-game trials restored their original hooks afterward.
They displayed the character/background and improved shadows, but severe
color/overexposure artifacts remain. This is NOT successful gameplay validation.
The Clear fallback may isolate one defect without fixing the remaining renderer
or postprocess defect. No normal-game baseline was promoted. No game-folder DLL,
INI, launcher or Steam authentication file was changed.

Final checks:169 app checks,3 isolated GPU probes,3 graphics-filter checks,
strict app signature and `git diff --check` PASS. The owned reproduction game was
closed to unload diagnostics; normal Steam was retained. Temporary frame tracing
was disabled. Production binaries were not replaced with the Clear candidate.
Backup of the exact-game DB notes/map cleanup:
`Compatibility/Repairs/dmc-clear-investigation-20261019/restore.json`
under the user's MacDeck application-support directory.
