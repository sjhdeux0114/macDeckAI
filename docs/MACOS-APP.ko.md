# MacDeck macOS Preview 0.4

2026-10-17 기준: **실제 Windows 게임이 Apple M5에서 Metal 가속으로 실행됐습니다.**

결과 앱은 `dist/MacDeck.app`입니다. 게임은 무료 오픈 소스 로그라이크 **Brogue CE 1.15.1 Windows x86_64판**입니다. macOS판 게임을 대신 실행하지 않았습니다. MacDeck 앱이 포함된 WineSikarugir 엔진으로 `brogue.exe`를 실행하고, SDL의 Direct3D 11 렌더러를 DXMT로 연결했습니다.

![MacDeck](../evidence/macdeck-app.png)

![v0.2 앱에서 실행한 Windows 게임과 Metal HUD](../evidence/macdeck-v02-game-metal.png)

## 실행

1. 설치된 `~/Applications/MacDeck.app` 또는 `dist/MacDeck.app`을 엽니다. 이 장비에는 사용자 승인으로 Rosetta 설치를 완료했습니다.
2. 자동 등록된 **Brogue CE · Windows**를 선택하고 **플레이**를 누릅니다.
3. Brogue에서 New Game을 선택합니다. 방향키나 `h/j/k/l`로 움직이고 `?`로 도움말을 볼 수 있습니다.
4. 게임 창 오른쪽 위의 Apple Metal HUD에서 Metal/GPU 정보를 확인합니다. `⌘F9`로 HUD를 전환할 수 있습니다.

앱은 작업 폴더 밖으로 옮겨도 자체 런타임과 게임을 포함합니다. 처음 실행할 때 게임 데이터를 `~/Library/Application Support/MacDeck/Games/`로 복사하므로 앱 번들 안에 저장 파일을 쓰지 않습니다. 라이브러리·게임별 Windows 환경·로그도 같은 Application Support 폴더에 둡니다.

Documents 안에서 앱을 실행하면 macOS가 **MacDeck의 문서 폴더 접근**을 확인할 수 있습니다. Wine 초기화가 앱 자신의 실행 파일을 연결하는 단계에서도 이 확인을 기다릴 수 있습니다. ChatGPT에 부여한 권한과 새 MacDeck 앱의 권한은 별개입니다.

이것은 로컬 ad-hoc 서명한 Apple Silicon 개발 빌드입니다. 공증된 공개 배포판은 아닙니다.

## Steam 머신으로 사용

앱의 **Steam 머신 시작**을 누르면 실제 Windows용 Steam을 Big Picture로 엽니다. 최초 설치 시 Valve 공식 설치 파일을 내려받아 `~/Library/Application Support/MacDeck/Bottles/Steam`에 설치합니다. 이 장비에는 설치와 업데이트를 완료했고 QR 및 계정 로그인 화면을 확인했습니다. 비밀번호·Steam Guard는 Steam 창에서 직접 입력합니다. MacDeck은 로그인 정보를 수집하거나 로그인 여부를 추정하지 않습니다.

Steam의 라이브러리에서 게임을 설치하고 실행합니다. 설치된 게임은 appmanifest 메타데이터를 확인해 MacDeck 라이브러리에도 표시하고, 실행 요청은 동일한 Steam 환경의 `-applaunch`로 전달합니다. 앱 시작 시 Big Picture 자동 실행은 기본으로 켜져 있으며 설정에서 끌 수 있습니다. Steam 웹 UI는 호환성을 위해 CEF GPU를 끄지만 게임은 별도의 DXMT/Metal 경로를 사용합니다.

현재 완료한 것은 로그인 UI까지이며, 실제 계정 인증 후 Steam 게임이 실행된다는 검증은 남아 있습니다. 아래 Brogue Metal 증거를 Steam 게임 호환성으로 확대 해석하면 안 됩니다.

## 외장 SSD/HDD에 게임 설치 및 연결 해제

1. Steam 화면의 **외장 드라이브의 폴더 연결…**에서 저장할 폴더를 선택합니다.
2. 앱은 게임이 종료된 상태에서 Steam을 정상 종료하고 라이브러리를 적용한 뒤 Steam을 시작합니다. Steam 설정 두 곳은 수정 전 백업합니다.
3. 폴더 목록에서 **Steam 등록 완료** 및 Windows 설치 경로를 확인합니다. 예: `/Volumes/NVME_1T/SteamLibrary` → `D:\SteamLibrary`.
4. 새 게임 설치 위치와 기본 위치, 기존 게임 이동은 Steam 저장 공간에서 선택합니다. 기존 내장 게임을 자동 이동하지 않습니다.
5. 각 폴더의 **연결 해제 (게임 파일 유지)**를 누르면 Steam 등록 및 해당 Windows 드라이브 연결을 제거합니다. 게임 콘텐츠는 삭제하지 않습니다. 작은 식별 파일은 복구용으로 유지합니다.

기존 v0.3은 폴더를 Wine 드라이브에 연결하는 기능까지만 있어 Steam 저장 공간에 추가하는 과정이 빠질 수 있었습니다. 실제 NVME_1T 문제를 조사해 이 원인을 확인했고 v0.4에서 적용과 상태 표시를 추가했습니다. 같은 실제 게임 폴더의 중복 연결은 차단합니다. 기존 중복 항목은 사용자가 원하는 항목을 해제할 수 있습니다.

Steam/Windows 환경은 내장에 유지하고 게임 콘텐츠를 외장에 저장합니다. 분리된 드라이브는 연결 필요 상태로 표시합니다. 볼륨/폴더 이름 변경 시 원래 경로로 복원해야 합니다. 실행 중 분리하지 마세요. 외장 등록과 Windows 파일 접근은 확인했으나 실제 외장에 Steam 게임을 다운로드하고 실행하는 검증은 아직 남아 있습니다.

## DualShock 4와 게임패드

**게임패드** 화면은 연결 상태 및 버튼·양쪽 스틱·트리거를 표시합니다. MacDeck이 전면에 있을 때만 패드로 탐색합니다. 방향키/왼쪽 스틱은 게임 선택, A/✕는 실행, B/○는 Steam 화면, LB/RB는 페이지 이동, Menu는 Steam 시작입니다. 테스트 화면에서는 B/○로 나가며 다른 버튼은 입력 표시만 합니다. 텍스트 입력·대화상자·시트에는 탐색을 적용하지 않습니다.

사용자의 Bluetooth DualShock 4를 AppKit + Apple GameController에서 실제로 인식했고 Wine과 같은 Intel SDL2에서 PS4 Controller 매핑 및 실제 버튼/축 변화를 확인했습니다. Windows builtin XInput을 명시해 native XInput DLL 충돌 가능성을 줄였습니다. Windows 테스트는 **Windows 게임패드 테스트 열기**(joy.cpl), 이후 Steam 설정 → 컨트롤러, 실제 게임 순서로 확인합니다. 현재 Windows/Steam/게임 내부 조작과 진동·자이로·터치패드 성공은 아직 보장하지 않습니다.

근거: `evidence/dualshock4-native-app.json`, `evidence/dualshock4-sdl.log`. AppKit 없는 최초 CLI는 0개로 나왔고 AppKit 초기화를 포함한 검사에서 DS4를 확인했습니다.

## 3D 게임 문제의 진단 기록

업데이트된 앱으로 실행하면 `~/Library/Application Support/MacDeck/Logs/Sessions/<시각>-<UUID>/`에 실행별 기록을 만듭니다.

- `diagnostics.json`: 앱/OS/GPU/런타임 경로, 게임 ID, 허용한 환경 변수, 인수(민감한 값 가림), 프로세스 ID·마지막 상태·종료 코드/시그널.
- `runtime-manifest.json`: 포함된 런타임 배포물과 SHA-256.
- `process.log`: 직접 실행한 게임의 출력. Steam 프로세스 출력·인수는 인증 보호를 위해 제외합니다.
- `Renderer/`: 해당 실행의 DXMT 로그. 실행마다 경로를 나눠 다음 실행이 덮어쓰지 않습니다.
- `summary.txt`: GPU 장치 손실·셰이더 컴파일·예외/DLL 등 알려진 오류 패턴의 조사 단서. 패턴이 없다고 정상이라고 판정하지 않습니다.

**실행 기록** 화면과 게임 카드 메뉴에서 폴더를 열거나 **진단 ZIP 저장…**으로 내보냅니다. Steam 게임 요청은 실행 중인 Steam 클라이언트의 그래픽 로그 세션과 연결하고 ZIP에 `RelatedSteamRenderer/`로 복사합니다. 로그 수집을 시작하기 전에 이미 실행된 Steam에는 관련 세션이 없을 수 있으므로 MacDeck에서 Steam을 새로 시작한 뒤 재현하세요.

Steam의 `-applaunch` 프로세스 종료는 실제 게임 종료가 아니므로 `request-process-ended`로 기록합니다. 앱이 비정상 종료되면 종료 상태가 갱신되지 않을 수 있어 상태는 마지막 기록으로 해석합니다. 메모리 덤프·Steam 인증 파일·세이브·화면 캡처를 자동 수집하지 않습니다. ZIP에는 로컬 경로와 게임 출력이 있으므로 공유 전에 검토하세요.

버그 수정 흐름: 게임/재현 단계/예상 결과/실제 결과를 적고 해당 실행 ZIP을 보관 → 요약과 원본 로그에서 단서 확인 → 원인 가설을 좁혀 수정 → 같은 재현 및 관련 검사로 검증 → `work.md`에 누적 기록. 자동 분석이 원인을 확정하거나 모든 3D 게임의 호환성을 해결하는 기능은 아닙니다.

검증: 자체 54개 검사, 실제 실패 프로세스 종료 코드 수집, 관련 Steam 그래픽 로그 포함 ZIP 생성·내용 검사, 무관한 인증 파일 제외 통과 (`evidence/v04-tests.log`, `evidence/diagnostics-smoke.log`).

## 확인한 실행 경로

```text
MacDeck.app (arm64 네이티브 UI)
  → WineSikarugir 10.0 revision 8 (x86_64, Rosetta)
  → brogue.exe (Windows x86_64)
  → SDL2 Direct3D 11 renderer
  → DXMT 0.80 + identity rotation compatibility fix
  → Apple Metal / M5
```

검증 이미지는 실제 게임 창에서 촬영했습니다. Apple Metal HUD에 `M5`, `x86_64`, `Metal`, GPU 프레임 시간이 표시됩니다. 테스트는 `--seed 42`로 실제 던전을 생성해 플레이 화면까지 진입했습니다. 이 스냅샷의 FPS는 게임의 갱신 주기를 포함한 순간값이며 AAA 게임 성능을 의미하지 않습니다.

WineSikarugir 10으로 교체한 최종 v0.2 앱에서도 던전과 M5 Metal HUD를 다시 확인했습니다 (`evidence/macdeck-v02-game-metal.png`).

별도 실행뿐 아니라 **완성 앱의 `DeckModel.launch` → `LaunchPlan` 경로**로 같은 게임을 시작하는 통합 검증도 수행했습니다. `evidence/app-game-windows.json`에는 앱과 게임의 별도 창/PID가 기록돼 있습니다.

## 구현한 기능

- SwiftUI/AppKit 네이티브 게임 라이브러리, 검색, 전체 화면.
- Windows `.exe`, macOS `.app`, 실행 가능한 파일 등록.
- 게임별 Windows prefix, 이름·경로·실행 인수·공유 prefix 설정.
- 셸을 거치지 않는 프로세스 실행과 실행 로그.
- 포함된 Wine 엔진 자동 연결, 별도 Wine 경로 선택, 버전 검사.
- Metal HUD와 DXMT 로그 활성화.
- Mac용 Steam 등록, Windows Steam 설치 프로그램 다운로드·실행 및 설치 후 연결.

**실제 Windows Steam 설치·업데이트·Big Picture 로그인 화면까지 확인했습니다. 계정 인증과 Steam 게임 다운로드·실행은 아직 검증하지 않았습니다.** 검증한 게임은 Brogue Windows판 하나입니다. Direct3D 12·안티치트·모든 Steam 게임 지원을 주장하지 않습니다. `.exe` 등록 가능과 해당 게임의 실행 호환성은 다릅니다.

## 실제 해결한 호환성 문제

### Wine의 Metal 화면 API

일반 Wine Stable 11.0에는 DXMT가 요구하는 Metal view API가 노출되지 않아 swapchain 생성에 실패했습니다. 임의로 실행 성공으로 처리하지 않고, `_macdrv_functions`를 노출하는 공개 소스 WineSikarugir 엔진으로 교체했습니다. 엔진에 필요한 공유 라이브러리도 앱 내부에 포함했습니다.

### SDL2의 SetRotation(IDENTITY)

DXMT 0.80은 `SetRotation`에 무조건 `E_NOTIMPL`을 반환합니다. Brogue의 SDL2 렌더러는 회전 없는 `DXGI_MODE_ROTATION_IDENTITY`에서도 이 반환값을 검사하며, 실패하면 D3D11 렌더러를 포기합니다. 실제로 OpenGL 쪽으로 넘어가는 로그까지 확인했습니다.

MacDeck의 호환성 수정은 **IDENTITY만 S_OK로 처리**합니다. 다른 회전은 계속 `E_NOTIMPL`입니다.

- 원본 소스 기준: DXMT `589adb780354b461645b29999cefaf533594ee99`.
- 대응 소스 변경: `patches/dxmt-0.80-identity-rotation.patch`.
- 현재 실험 빌드는 고정 해시의 배포 DLL에서 두 x64 템플릿 메서드만 교체하는 `scripts/patch-dxmt-identity.py`를 사용합니다.
- 이는 DXMT 전체를 소스에서 재빌드한 결과가 아닙니다. 원본 파일 SHA-256·함수 위치·기존 prologue를 검사하고, 모르는 바이너리에는 적용하지 않습니다.
- 원본 x64 `d3d11.dll`: `7ca382af0eb32d8a432f6efb14d594fefb45673663be1f7e6682254bff885c47`.
- 수정본: `cafb32ba2b58e2e8decc1d6feabccdc131e1bf186713b34913a98974f94a3f02`.

변경 범위 밖의 바이트가 그대로인지 검사했고, Windows x64 호출 규약으로 IDENTITY와 다른 회전 값을 실제 실행해 반환값을 확인했습니다. `evidence/dxmt-patch-tests.log`에 결과가 있습니다. **수정한 대상은 x64뿐입니다.** 32비트 게임의 동일 문제를 해결했다고 보지 않습니다.

향후 정식 배포에서는 이 소스 수정을 적용한 DXMT 전체 빌드와 추가 게임 검증으로 대체하는 것이 적절합니다. 현재 결과물은 이 장비에서 동작을 입증한 실험판입니다.

## 빌드 재현

Swift 명령행 도구, Python 3, Apple Silicon Mac, Wine을 실행할 Intel 지원이 필요합니다. Rosetta 라이선스 동의는 빌드 스크립트가 자동 수행하지 않습니다.

```sh
bash scripts/package-mac-app.sh
open dist/MacDeck.app
```

이 명령은 고정된 WineSikarugir·Wine support libraries·DXMT·Brogue 배포물을 공식 프로젝트 GitHub에서 받아 SHA-256을 검사하고 앱을 구성합니다. 첫 다운로드는 약 400 MB입니다. 다운로드 캐시는 `.cache/mac-runtime/`에 있습니다.

앱 소스만 다시 빌드:

```sh
bash scripts/build-mac-app.sh
dist/MacDeck.app/Contents/MacOS/MacDeck --self-test
```

런타임 경로를 담은 `Contents/Resources/runtime-manifest.json`을 함께 보관합니다. 일반 Wine Stable 전체를 게임 엔진으로 사용하는 것이 아니라, WineSikarugir 엔진과 함께 배포되는 보조 공유 라이브러리에 Wine Stable 패키지를 사용합니다.

## 검증 및 범위

| 검사 | 결과 |
|---|---|
| 네이티브 앱 빌드·로컬 서명 | 성공 |
| 앱 자체 54개 검사 | 성공 |
| DXMT 변경 범위·잘못된 입력 거부 | 성공 |
| Windows x64 ABI의 회전 반환값 | 성공 |
| Windows Brogue 던전 렌더링 | 성공 |
| 게임 창의 Apple Metal HUD | 확인 |
| 최종 앱에서 게임 실행 | 성공 |
| 전체 게임 플레이·저장/재개·오디오·게임패드 | 별도 검증 안 함 |
| Steam 설치·업데이트·Big Picture 로그인 UI | 성공 |
| Steam 계정 인증·Steam 게임 | 사용자 로그인 후 추가 검증 필요 |
| 3D/AAA 게임 호환성·성능 | 별도 검증 안 함 |

로그와 이미지는 `evidence/`에 보관했습니다. 초기 실패 로그도 남겨 원인과 개선을 추적할 수 있습니다. 이전 Linux VM 분석은 `PORTING-REPORT.ko.md`에 보존했고, 이번 성공은 그 VM의 GPU 가속을 해결한 것이 아니라 **macOS용 실행 백엔드로 전환한 결과**입니다.

## 구성요소 출처

- [WineSikarugir 엔진 배포](https://github.com/Sikarugir-App/Engines/releases/tag/v1.0): `WS12WineSikarugir10.0_8`.
- [Wine Stable support package](https://github.com/Gcenx/macOS_Wine_builds/releases/tag/11.0_1).
- [DXMT 0.80](https://github.com/3Shain/dxmt/releases/tag/v0.80), [DXMT 설치 조건](https://github.com/3Shain/dxmt/wiki/DXMT-Installation-Guide-for-Geeks).
- [Brogue CE 1.15.1](https://github.com/tmewett/BrogueCE/releases/tag/v1.15.1).

DXMT 0.80은 MIT 배포판이며 로컬 호환성 변경을 포함했습니다. Brogue와 자산·Wine·지원 라이브러리의 라이선스는 각각 유지됩니다. 라이선스와 변경 내역은 앱의 `Contents/Resources/Licenses/`에도 포함합니다. 이 빌드를 공개 배포하기 전에는 전이 의존성까지 포함한 배포 패키지 점검이 추가로 필요합니다.
