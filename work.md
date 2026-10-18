# MacDeck 누적 작업 기록

이 문서는 사용자의 요청에 따라 유지하는 작업·검증·인계 기록이다. 이후 작업도 날짜별로 뒤에 추가한다. 인증 정보는 기록하지 않는다.

## 현재 상태 — 2026-10-18

- 프로젝트: `/Users/sjhdeux/Documents/macdeck`
- 현재 앱: **MacDeck 0.5.3**, Apple Silicon macOS용 실험판, 로컬 ad-hoc 서명.
- 빌드 결과: `dist/MacDeck.app`
- 설치된 앱: `/Users/sjhdeux/Applications/MacDeck.app`
- 실제 호스트: Apple M5, 메모리 24 GiB, macOS 27.0.1. 최소 배포 대상 macOS 13은 빌드 설정이며 다른 기기에서 검증한 것은 아니다.
- 구현: 네이티브 라이브러리, Windows 게임 실행, **전역 DX11 Mode(DXMT → Metal, 기본값) / DX12 Mode(VKD3D + MoltenVK → Metal) 선택 및 실시간 전환**, **런타임 구성요소(MoltenVK · DXMT · Wine Engine) 공식 GitHub Releases 확인 및 자동 업데이트(`RuntimeUpdater`)**, **macOS Game Mode(`Game Mode: On`) 활성화 지원**, 실제 Windows Steam Big Picture, 설치 게임 가져오기, 외장 폴더의 Windows 드라이브 매핑 및 **앱 시작 시 자동 재연결**.
- 최종 자체 검사 **74개 통과**, 앱 빌드·서명 확인 성공.
- 실제 Windows Brogue CE 던전 렌더링 및 **M5 Metal HUD 확인 성공**.
- 실제 Windows Steam 로그인 완료 및 외장 NVMe 드라이브(`E:\SteamLibrary`)에 Steam 게임 4종(Resident Evil 3, Balatro, Halls of Torment, No Results Found) 다운로드·설치 확인 성공.
- **Direct3D 12 3D 게임(Resident Evil 3, `re3.exe`) 실행 및 Apple M5 Metal 3(VKD3D 1.14 → winevulkan → MoltenVK) 전체화면(`2704x1756`, `38.45 FPS`) 렌더링 확인 성공** (기본 전역 모드는 **DX11 Mode**이며 설정에서 전환 가능).
- Bluetooth DualShock 4를 Apple GameController 및 Wine과 같은 SDL2에서 인식하고 실제 버튼/축 변화 확인. Windows/Steam/게임 내부 조작은 아직 별도 검증 필요.
- v0.5.2: `런타임` 설정 탭에 **MoltenVK (`KhronosGroup/MoltenVK`) · DXMT (`3Shain/dxmt`) · Wine Engine (`Sikarugir-App/Engines`)** 최신 릴리스 확인 및 **자동 업데이트** 기능(`RuntimeUpdater.swift`) 추가. 앱 시작 시 자동 확인 및 SHA-256 무결성 검증·아키텍처(`x86_64`) 슬라이스 검증·백업 후 원자적 교체·ad-hoc 재서명 지원.
- v0.5.3: `steamwebhelper.exe` 시작 직후 `0x80000003` (`libcef.dll+0x59ef905`, Chromium `DelayLoadFailureHook`) 예외 및 `winedbg` 모달/콘솔 창이 반복 발생하던 문제를 근본 해결. Wine prefix 내부 `drive_c/windows/{system32,syswow64}/dxgi.dll` 동기화(`DirectX12Support.syncPrefix`), CEF Delay-Load 호환 `d3d12,d3d12core,vulkan-1,winevulkan=b` 오버라이드 유지, `winedbg.exe=d` 및 `AeDebug` 자동 복구, Steam 기동 중 런타임 덮어쓰기 경합 제거 적용 후 Steam Big Picture(`BrowserReady` 및 `SP BPM_uid0`) 무오류 정상 기동 검증 완료.
- 작업 폴더를 Git 저장소로 초기화하고 원격 저장소(`https://github.com/sjhdeux0114/macDeckAI.git`, branch `main`)로 커밋 및 푸시 완료.

## 사용자 목표 및 이미 받은 승인

1. DroidDeck 코드를 최대한 분석하고 실제 결과물을 만들기.
2. 우선 **Mac 전용**으로 진행. iPad 구현은 현재 범위에서 제외.
3. **Metal 가속과 실제 게임 구동 필수**.
4. DroidDeck처럼 실제 Steam 로그인 후 Steam 머신처럼 사용할 수 있어야 함.
5. 내장 용량을 아끼기 위해 외장 HDD/SSD의 게임 설치 폴더 연결 지원.
6. 작업 내역을 `work.md`에 계속 누적할 것.

- 사용자는 Rosetta 설치와 Apple 약관 동의를 승인했고 설치를 완료했다.
- 검증 게임은 우선 무료 게임으로 하기로 했다.
- 사용자는 ChatGPT의 데스크탑 접근을 허용했다고 답했다. ChatGPT와 MacDeck의 macOS 폴더 접근 권한은 별개다.
- Steam 비밀번호/Steam Guard는 사용자가 실제 Steam 창에서 직접 입력한다. 채팅으로 받거나 인증 설정 파일을 조사하지 않는다.

## 구조와 실행 경로

```text
MacDeck.app — SwiftUI/AppKit arm64 UI
  ├─ RuntimeUpdater — GitHub Releases (MoltenVK / DXMT / Wine) 확인 · SHA-256 검증 · 자동 업데이트
  → WineSikarugir 10.0 revision 8+ — x86_64, Rosetta
  → Windows Steam / Windows 게임
  ├─ Direct3D 10/11 → DXMT 0.80+ + IDENTITY rotation 수정 → Apple Metal
  └─ Direct3D 12    → Wine VKD3D 1.14 + Wine DXGI Bridge + MoltenVK 1.4.1/1.4.2+ → Apple Metal
```

- `Sources/MacDeck/App.swift`: 네이티브 UI, Steam 중심 시작 화면, 라이브러리, 실행 환경, 그래픽 백엔드 선택기, 런타임 자동 업데이트 패널, 외장 설치 폴더 패널.
- `Sources/MacDeck/RuntimeUpdater.swift`: MoltenVK / DXMT / Wine Engine 버전 감지, GitHub Releases API 조회, SHA-256 검증, `x86_64` 슬라이스 확인, 호환성 패치(`SetRotation`, `dxgi-dxmt`/`dxgi-d3d12`, `wine` Game Mode plist) 보존 설치.
- `Sources/MacDeck/Library.swift`: Codable 데이터, 게임 가져오기, prefix 준비, 전역 DX11/DX12 모드 및 `dxgi.dll` 브리지 전환(`DirectX12Support`), 셸을 거치지 않는 실행 계획과 환경.
- `Sources/MacDeck/Runtime.swift`: 프로세스·로그·라이브러리 관리, 런타임 업데이트 상태/자동 설치 관리, Steam 설치/실행/자동 시작/게임 동기화, 앱 시작 시 외장 폴더 자동 연결(`reconnectExternalLibraries`).
- `Sources/MacDeck/SteamClient.swift`: VDF 파서, Steam 전용 prefix, Big Picture 인수, 설치 게임 탐색, Windows 경로 변환, 설치 프로세스 대기.
- `Sources/MacDeck/ExternalLibrary.swift`: 선택 폴더 식별 파일, 고정 드라이브 문자, 비루트(`E:\SteamLibrary`) 매핑 정규화, 연결 여부와 남은 용량.
- `Sources/MacDeck/SteamStorage.swift`: Steam `libraryfolders.vdf` 등록/해제, 드라이브 심볼릭 링크 자동 복구(`autoConnectAll`), 인식 상태 확인.
- `Sources/MacDeck/SelfTests.swift`: 격리된 임시 폴더 기반 자체 검사 74개.
- `Sources/MacDeckProbe/main.swift`: 초기 Metal 계산·Linux VM 진단 도구.
- `scripts/prepare-metal-runtime.py`: 고정 SHA-256 배포물로 앱 런타임(DXMT + VKD3D/MoltenVK `libvulkan.1.dylib` + D3D12용 Wine `dxgi.dll`)과 게임 구성.
- `scripts/build-mac-app.sh`: Swift CLI 컴파일, Info.plist v0.5.0 생성, ad-hoc 서명.
- `scripts/package-mac-app.sh`: 런타임 준비 → 앱 빌드 → 자체 검사 → 서명 검증.
- `scripts/patch-dxmt-identity.py`, `patches/dxmt-0.80-identity-rotation.patch`: DXMT 배포 DLL 수정과 대응 소스 변경.
- `scripts/test-dxmt-patch.py`, `scripts/test-rotation.c`: 변경 바이트 범위·입력 거부·실제 x64 ABI 검사.
- `scripts/test-external-wine.py`: 별도 테스트 prefix에서 실제 Windows cmd.exe의 D: 파일 쓰기 검사.
- `scripts/game-windows.swift`: 게임/Steam/MacDeck 창 메타데이터 확인용 헬퍼. 화면 접근이 가능한 환경에서 사용.

데이터 위치:

- `~/Library/Application Support/MacDeck/library.json`: 앱 라이브러리·설정.
- `~/Library/Application Support/MacDeck/Bottles/Steam`: 영속 Windows Steam 환경.
- 위 prefix의 `drive_c/Program Files (x86)/Steam/steam.exe`: 실제 설치 Steam.
- `~/Library/Application Support/MacDeck/Bottles/<게임 UUID>`: 개별 게임 환경.
- `~/Library/Application Support/MacDeck/Games/BrogueCE-windows`: 실제 Windows 무료 게임.
- `~/Library/Application Support/MacDeck/Logs`: 실행 로그.
- `.cache/mac-runtime`: 다운로드·추출 캐시. `dist`, `.build`, `.cache`, upstream 체크아웃은 대용량이므로 목적을 확인한 뒤 정리할 것.

## 다음 작업 / 완료 조건

1. 사용자가 Steam 로그인과 Steam Guard를 완료했는지 확인. 완료를 추정하지 말 것.
2. 실제 Steam에서 무료 Windows 게임을 설치해 실행하고 Metal 경로를 증명. Brogue 단독 실행 증거를 Steam 게임 성공으로 간주하지 말 것.
3. 실제 외장 드라이브 연결 시 MacDeck 폴더 선택 → Steam 저장 공간 추가 → 기본 설치 위치 지정 → 다운로드 → 게임 실행 → 재연결을 검증.
4. 외장 볼륨/폴더 이름 변경 후 경로 복구·재연결 UX는 추가 개선 여지가 있다. 현재는 원래 경로 복원 필요.
5. **게임 호환성 검증 확장**:
   - **2D 게임**: Brogue CE(Windows x86_64, D3D11/DXMT/Metal)로 1차 검증 완료. 다양한 2D 엔진(DirectDraw, Direct3D 9, SDL 소프트웨어, 구형 OpenGL 등)을 사용하는 추가 2D 게임들에 대해 폭넓은 테스트 필요.
   - **3D 게임**: D3D10/11 -> DXMT -> Metal 파이프라인 및 정밀 진단 시스템(로그 수집, 셰이더 컴파일 오류 요약 등) 구축 완료. 셰이더 연산, D3D12/VKD3D 필요 여부, 안티치트 등 변수가 많으므로 **집중적인 추가 테스트와 호환성 확보 작업이 많이 필요함**.
6. 전체 플레이·저장/재개·오디오·Windows/게임 내부 패드 입력, AAA/D3D12/안티치트 호환성은 미검증. 포괄적인 지원을 주장하지 말 것.
7. 공개 배포 시 DXMT 전체 소스 재빌드, 전이 의존성 라이선스 점검, 공증·배포 절차 필요. 현재는 로컬 실험판.

## 빌드·검증 명령

```sh
bash scripts/package-mac-app.sh
# 런타임을 이미 준비한 경우 앱만 빌드:
bash scripts/build-mac-app.sh
dist/MacDeck.app/Contents/MacOS/MacDeck --self-test
codesign --verify --strict dist/MacDeck.app
python3 scripts/test-dxmt-patch.py .cache/mac-runtime/dxmt/v0.80/x86_64-windows/d3d11.dll
python3 scripts/test-external-wine.py
open /Users/sjhdeux/Applications/MacDeck.app
```

Wine 실행·다운로드·GUI 검사는 실행 환경에 따라 샌드박스 밖 실행 권한이 필요하다. SwiftUI의 `@State`를 CLI 도구로 직접 컴파일할 때 매크로 플러그인 문제가 있어 `DeckState` 별칭을 사용한다. 새 앱을 Documents 밖의 `~/Applications`에 설치해 앱 자신의 Documents 접근 대기로 막히는 문제를 피했다.

## 누적 이력

### 2026-10-17 — DroidDeck 분석과 Linux VM 실험

- 원본: https://github.com/Droid-Deck/DroidDeck
- 조사한 upstream 커밋: `64d78aa812305d707700e2ad460f3b94d03ed50c`, 원본 수정하지 않음.
- Android 결합부와 ELF 라이브러리 의존성을 조사하고 iPad SDK 가용성을 확인했다.
- 실제 Metal 계산 및 ARM64 Linux 부팅 성공.
- 테스트한 Apple Virtualization virtio GPU가 3D capset을 제공하지 않아 Linux VM 경로로 게임 Metal 가속을 입증하지 못했다.
- macOS용 Wine/DXMT 경로로 전환. Android 앱을 그대로 실행하거나 Valve가 Mac용으로 포팅했다고 주장하지 않는다.
- 근거: `docs/PORTING-REPORT.ko.md`, `evidence/host.json`, `evidence/linux-boot.log`, `evidence/source-audit.json`, `evidence/ipados-sdk.json`.

### 2026-10-17 — macOS 앱 및 실제 Metal 게임

- SwiftUI/AppKit 네이티브 게임 라이브러리, 검색, 전체 화면, 파일 등록, 실행 인수, 게임별 prefix, 로그, 런타임 선택 구현.
- 실제 무료 Windows Brogue CE 1.15.1 x86_64를 사용. macOS 네이티브판을 대신 실행하지 않음.
- 일반 Gcenx Wine Stable 11 엔진은 DXMT가 요구하는 Metal view API를 노출하지 않아 실패했다. `_macdrv_functions`를 노출하는 Sikarugir 엔진으로 교체했다.
- DXMT 0.80 `SetRotation(IDENTITY)`가 E_NOTIMPL을 반환해 SDL2가 OpenGL로 대체하는 문제를 확인했다.
- IDENTITY에만 S_OK를 반환하도록 두 x64 템플릿 메서드를 수정. 다른 회전은 계속 E_NOTIMPL. 원본 해시·위치·prologue 확인 후 적용하고 변경 범위 및 실제 Windows x64 호출 규약으로 검사했다.
- 현재는 배포 DLL에 최소 수정한 실험판이며 DXMT 전체 소스 재빌드는 하지 않았다. 대응 소스 패치를 함께 제공한다. x64만 수정했다.
- DXMT 소스 기준 `589adb780354b461645b29999cefaf533594ee99`.
- x64 d3d11.dll 원본 SHA-256: `7ca382af0eb32d8a432f6efb14d594fefb45673663be1f7e6682254bff885c47`.
- 수정본 SHA-256: `cafb32ba2b58e2e8decc1d6feabccdc131e1bf186713b34913a98974f94a3f02`.
- `SDL_RENDER_DRIVER=direct3d11`로 조용한 OpenGL 대체를 방지. DXMT·Metal HUD 활성화.
- 실제 seed 42 던전과 M5 Metal HUD 확인. 마지막 Steam용 엔진 교체 후 v0.2 앱에서도 재확인했다.
- 근거: `evidence/macdeck-game-metal.png`, `evidence/macdeck-v02-game-metal.png`, `evidence/dxmt-patch-tests.log`.

### 2026-10-17 — 실제 Steam / v0.2

- 기존 WineCX 24 계열은 게임을 구동했지만 최신 Steam용으로 더 새 엔진을 조사했다.
- `WS12WineSikarugir11.0_1`은 Wine 초기화 실패. 실패 prefix `Bottles/Steam.failed-engine11`은 원인 추적용으로 보존.
- `WS12WineSikarugir10.0_8`에서 Valve 공식 SteamSetup.exe `/S` 설치 exit 0.
- 실제 Steam 클라이언트 336,229 KB 업데이트 완료 후 Big Picture QR·계정 로그인 화면을 확인했다.
- 설치된 최종 앱을 통한 Steam 새 실행으로 Big Picture 창 생성도 확인했다. 창 표시가 이후에도 유지되거나 현재 로그인됐다고 추정하면 안 된다.
- Steam 전용 영속 prefix, 자동 Big Picture 시작, 설치 게임 메타데이터 가져오기, 동일 prefix에서 `-applaunch <appid>` 실행 구현.
- VDF는 Steam `libraryfolders.vdf`와 `appmanifest_*.acf`만 대상으로 처리. 계정/인증 설정은 읽지 않는다.
- Steam CEF 브라우저는 호환성 때문에 GPU를 끈다. 게임 렌더러 DXMT/Metal과 별도 설정이다.
- 초기 검사 19개 통과, 앱 빌드·서명 성공. 사용자에게 실제 Steam 창에서 로그인/Steam Guard 진행을 요청했다. 인증 완료 응답은 아직 없음.
- 근거: `evidence/steam-setup/VALIDATION.md`, `evidence/steam-app-tests.log`, `evidence/steam-package.log`, `evidence/steam-setup/installer-engine10.log`.
- 로그인 UI 캡처에는 일시적인 인증 QR이 포함될 수 있으므로 문서나 최종 답변에 재노출하지 않는다.

### 2026-10-17 — 외장 게임 설치 폴더 / v0.3

- 사용자 요청: 내장 공간이 적은 Mac에서 게임을 외장 HDD/SSD에 설치할 수 있어야 함.
- `ExternalLibrary.swift` 추가. NSOpenPanel로 기존 폴더를 선택해 Wine `dosdevices/d:`부터 사용 가능한 문자를 할당한다. 기존 매핑을 덮어쓰지 않는다.
- 폴더에 UUID 식별 파일을 기록해 연결 상태를 확인하고 동일 경로의 다른 디스크를 오인하지 않게 했다. 연결 상태·남은 용량·macOS 경로·Windows 드라이브 표시.
- Steam과 Windows prefix는 내장에 두고 게임 폴더만 외장 연결. Steam 설정 → 저장 공간에서 사용자가 연결 드라이브를 추가하고 기본 위치로 지정한다. Steam 설정 파일 직접 수정이나 기존 게임 자동 이동은 하지 않는다.
- VDF에 등록된 외장 라이브러리도 탐색. Game에 선택적 `installedLocation`, LibraryData에 선택적 `externalLibraries` 추가해 이전 JSON 읽기 유지.
- MacDeck에서 해당 게임 실행 전 설치 위치와 드라이브 식별을 검사한다. Steam 내부 직접 실행까지 차단하는 기능은 아니다.
- 타이머를 통해 연결 상태를 주기적으로 화면에 반영한다.
- 테스트에서 Windows 루트 경로에 이중 슬래시가 생기는 문제를 발견해 `windowsPath` 반환을 정규화했다.
- 새 prefix에서 외장 연결을 먼저 만들면 기본 C: 매핑이 누락되어 Wine 초기화가 지연되는 문제를 실제 검사로 발견했다. 초기 prefix에 C:/Z: 기본 매핑도 준비하도록 수정했다.
- 실제 Windows cmd.exe가 D:를 통해 한글·공백 폴더에 파일 쓰기 성공. 첫 검사 타임아웃과 중복 정리 호출의 실패 로그는 원인 추적용으로 보존하고 스크립트를 수정했다. 마지막 실행은 exit 0.
- 최종 자체 검사 **27개 통과**. 빌드 및 설치된 앱 서명 검증 성공. v0.3.0을 `~/Applications/MacDeck.app`에 반영했다.
- 최종 증거: `evidence/external-storage-tests.log`, `evidence/external-storage-wine-final.log`, `evidence/external-storage-build.log`.
- 미검증: 실제 물리 외장 디스크에서 Steam 다운로드·게임 실행. 테스트 폴더 이동/복원으로 분리·재연결을 모의 검증한 결과와 구별한다.

### 2026-10-17 — 작업 기록 영속화

- 사용자 요청: 토큰/컨텍스트가 소진되기 전 지금까지 작업을 `work.md`에 남기고 앞으로 계속 누적하기.
- 현재 소스·빌드 버전·Steam 검증 기록·최종 외장 검사 로그를 읽어 이 문서를 작성했다.
- 루트 `AGENTS.md`를 추가해 작업 시작 시 읽기, 중간·종료 시 누적 기록, 인증 정보 제외, 미검증 구분을 명시했다.
- 이번 변경은 문서와 작업 지침뿐이므로 게임/앱 재빌드를 수행하지 않았다. 기존 검증 결과를 다시 실행한 것처럼 기록하지 않았다.

## 고정 런타임 출처

다운로드 URL·SHA-256의 실행 가능한 기준은 `scripts/prepare-metal-runtime.py`와 앱의 `Contents/Resources/runtime-manifest.json`이다.

- 엔진: Sikarugir Engines `WS12WineSikarugir10.0_8.tar.xz`, SHA-256 `2a6bcf2a3bf13cddf825599b6bc1e3659cbf71e1282c6d77141a92f6ac8d4c68`.
- 지원 공유 라이브러리: Gcenx Wine Stable `11.0_1` 패키지. 일반 Wine Stable 자체를 게임 엔진으로 사용하는 것이 아니다.
- DXMT: 0.80 builtin 패키지 + 위 IDENTITY 수정.
- 검증 게임: Brogue CE 1.15.1 Windows x86_64.
- Steam 설치 프로그램: Valve 공식 `https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe`. 클라이언트는 Steam 자체 업데이트 사용.
- 라이선스·변경 내역: 루트 `LICENSE`, `licenses/`, `patches/`, 앱 `Contents/Resources/Licenses/`.

관련 설명: `README.md`, `docs/MACOS-APP.ko.md`, 초기 분석 `docs/PORTING-REPORT.ko.md`.

### 2026-10-17 — 게임패드 지원 작업 시작 (진행 중)

- 사용자 요청: 게임패드를 연결해 Steam 머신과 게임이 잘 동작해야 함.
- GameController SDK, 내장 Wine의 winebus/SDL 및 XInput 구성 확인을 시작했다. 실제 패드 연결/모델명을 사용자에게 요청했고 구현은 계속 진행한다.
- Sikarugir 공식 이슈 #165에서 Wine 10 계열 Bluetooth 매핑 수정과 native XInput 설치 시 충돌 보고를 확인했다. 현재 10.0_8 사용을 유지하고 Wine builtin XInput 경로를 명시할 예정이다.
- 범위: 연결/분리 및 실시간 입력 진단, MacDeck 전경 패드 내비게이션, Windows joy.cpl 진단 연결. OS 인식과 실제 Windows/Steam/게임 입력 성공은 별도로 검증한다.
- 출처: https://github.com/Sikarugir-App/Sikarugir/issues/165 및 로컬 Apple GameController SDK 헤더.

### 2026-10-17 — 실제 외장 NVMe 적용 문제 조사 (진행 중)

- 사용자: 패드는 DualShock 4, 실제 외장 드라이브를 연결했으나 적용되지 않는 것으로 보인다고 보고.
- 실제 `/Volumes/NVME_1T`와 MacDeck의 D: 매핑 및 식별 파일 존재 확인.
- Steam `steamapps/libraryfolders.vdf`에는 C: 라이브러리만 있음. 기존 구현의 폴더 연결은 Wine 드라이브 매핑까지만 수행하므로 Steam 라이브러리 등록은 완료되지 않은 상태임을 확인.
- OS GameController 진단에서는 현재 연결된 컨트롤러 0개. DualShock 4 실기 입력 성공으로 간주하지 않음.
- 다음: Wine의 실제 D: 접근 검사, Steam 등록 상태의 명시적 표시 및 안전한 적용 경로 구현. 사용자가 이미 설치한 Underveil Demo의 appmanifest 메타데이터가 있으나 실제 게임 실행/Metal 성공은 미확인.

### 2026-10-17 — DS4 실기 인식 / 외장 적용 수정 / 진단 시스템 (진행 중)

- 사용자가 DS4 연결 완료를 알림. HID에서 Sony Bluetooth DUALSHOCK 4 확인. AppKit 초기화를 포함한 GameController 진단에서 확장 프로필 인식 성공. 초기 CLI 0개는 AppKit 없는 검사 방식의 한계였음.
- Wine과 동일한 x86_64 SDL2로 PS4 Controller 매핑 및 실제 버튼/스틱/트리거 값 변화를 확인 (`evidence/dualshock4-native-app.json`, `evidence/dualshock4-sdl.log`). Windows XInput 및 실제 게임 안 조작 성공과는 구분.
- 기존 NVME_1T 매핑을 실제 Steam 라이브러리 파일 두 곳에 백업 후 등록. D:\SteamLibrary → /Volumes/NVME_1T/SteamLibrary. 종료 상태를 실제 tasklist로 확인한 뒤 적용. 기존 내장 게임 파일은 이동하지 않음 (`evidence/external-nvme-applied.log`).
- 새 UI: Steam 등록 여부 표시, 적용/시작, 연결 해제(파일 유지). 적용·해제 전에 정상 종료/종료 상태 확인. Steam 설정은 원본 백업, 다른 메타데이터 보존, 부분 쓰기 실패 복원.
- 사용자 추가 요청: 3D 게임 버그를 로그로 분석·수정할 수 있는 시스템. 실행별 독립 디렉터리와 구조화된 메타데이터, DXMT 로그 분리, 종료/시그널 기록, ZIP 내보내기 구현 중.
- Steam 실행 인수와 stdout/stderr는 인증 보호를 위해 새 진단 수집에서 제외. Steam 게임 실행 요청의 프로세스 종료를 게임 종료로 오인하지 않게 별도 상태 기록.
- 중간 검증: 외장 등록/해제·재연결·원본 보존·패드 입력 정책 포함 44개 검사 통과. 이후 진단 기능을 추가하여 최종 검사 진행 중.


### 2026-10-17 — v0.4 통합 완료 및 설치본 교체

- 추가 요청: 설치 폴더 항목 삭제/해제, 3D 게임 버그 분석용 로그 시스템. 첨부 화면에서 D: 외장 루트와 E: SteamLibrary 중복 연결 확인.
- `ExternalLibrary.swift`: 기존 nil 설정의 설치 폴더를 steamapps 존재 여부로 해석, 새 설정에 libraryFolder 유지, 같은 실제 설치 폴더 중복 매핑 방지.
- `SteamStorage.swift` 추가: 실제 Windows tasklist로 Steam 실행 확인 → 필요시 정상 -shutdown → 종료 대기 → Steam `steamapps/libraryfolders.vdf`와 `config/libraryfolders.vdf`를 백업 후 반영. 기존 앱 메타데이터·설정 보존, 파일 쓰기 실패 시 복원.
- 외장 항목별 적용 상태/적용 버튼/연결 해제 버튼 제공. 해제는 해당 Steam 등록·Wine 드라이브·앱 연결을 제거하며 게임 파일을 삭제하지 않는다. 식별 파일은 복구용으로 유지.
- `Gamepads.swift` 추가: 실제 연결 프로필과 실시간 버튼·스틱·트리거 표시, 전경에서만 런처 조작, 드리프트 dead zone, 방향 반복 간격, 확인 버튼 중복 실행 방지. 텍스트/시트/경고창에서는 탐색 비활성. 패드 테스트 화면은 B/○로 나감.
- Windows builtin XInput override 추가, Windows joy.cpl 테스트 버튼 제공. DS4의 macOS/SDL 인식과 실제 값 변화까지 확인했으며 게임 안 조작 성공으로 확대 해석하지 않는다.
- `Diagnostics.swift` 추가: 실행별 UUID 폴더, JSON 메타데이터, GPU 이름, 허용 환경, 민감 인수 가림, 프로세스 PID·종료/시그널, DXMT 로그 경로 분리, 런타임 manifest 복사.
- Steam 프로세스 출력/인수는 새 진단에서 제외. Steam 게임 실행 요청은 실제 게임 종료와 구분하고, 관련 Steam 클라이언트 세션을 UUID로 연결해 ZIP에 그래픽 로그를 함께 포함.
- GPU 손실/정지·셰이더 컴파일·예외/DLL 관련 알려진 패턴의 단서 요약 제공. 확정 원인이나 정상 여부를 자동 단정하지 않음.
- 실행 기록 페이지, 게임 메뉴의 로그 폴더와 진단 ZIP 저장 제공. 계정 인증 파일·덤프·세이브·스크린샷을 자동 수집하거나 업로드하지 않음.
- 최종 자체 **54개 검사 통과**, 빌드·설치본 서명 검증 성공. 실제 실패 프로세스 종료 코드와 ZIP 내용 검사(관련 Steam Renderer 포함/무관한 인증 파일 제외)도 통과.
- 증거: `evidence/v04-build.log`, `evidence/v04-tests.log`, `evidence/diagnostics-smoke.log`, `evidence/dualshock4-native-app.json`, `evidence/dualshock4-sdl.log`, `evidence/external-nvme-applied.log`.
- 재현 소스: `scripts/diagnostics-smoke.swift`, `scripts/gamepad-probe.swift`, `scripts/sdl-gamepad-probe.c`.
- v0.4를 `/Users/sjhdeux/Applications/MacDeck.app`에 설치하고 `--no-steam`으로 열어 실제 UI 확인. 화면에서 연결 해제 성공 메시지, E: 단일 항목, 적용/해제 버튼, 새 게임패드/실행 기록 메뉴 확인 (`evidence/macdeck-v04-ui.png`). D: 항목은 그 시점 UI에서 제거되어 있었음. 사용자의 현재 선택을 임의로 복원하지 않음.
- E: 항목은 캡처 당시 '폴더만 연결됨 · Steam 적용 필요' 상태. 적용 버튼으로 등록해야 하며 사용자 조작 중 임의로 추가 설정 변경을 수행하지 않았다.
- `docs/MACOS-APP.ko.md`, README를 v0.4에 맞게 갱신.
- 남은 검증: 실제 외장 Steam 다운로드/실행, Windows XInput 및 게임 안 DS4 조작, 실제 3D 실패 재현과 진단을 통한 수정. 현재 진단 시스템은 검사에서 동작을 확인했으며 실제 3D 게임 호환성이 해결됐다는 의미가 아니다.

### 2026-10-17 — 외장 적용 재실패 조사 (진행 중)

- 사용자 재보고: 외장 드라이브가 설정되지 않음.
- 현재 E:만 연결. Steam 양쪽 libraryfolders.vdf에는 `path=E:` 항목이 있으나 content_log에 `Install folder E: not mounted.`가 반복됨. v0.4의 registered 판정은 설정 항목 존재만 확인해 실제 사용 가능 여부를 보장하지 못했음.
- E:가 선택한 SteamLibrary 디렉터리 자체를 매핑해 Steam이 루트 경로를 `E:`로 정규화하는 상황 확인. 볼륨 루트와 라이브러리 경로를 분리해 `E:\SteamLibrary` 같은 비루트 설치 경로로 바꾸는 수정 및 재시작 후 실제 Steam 재검증 예정.
- cscript/VBScript 용량 검사는 exit 1로 결과를 얻지 못함. WMI 검사로 전환. 인증 정보는 읽지 않음.

### 2026-10-17 — GitHub 저장소 초기화, README.md 전면 갱신 및 푸시 준비

- 사용자 요청: `work.md` 기반 프로젝트 현황 파악, 상세한 `README.md` 작성(2D 게임 1차 검증 완료 및 추가 테스트 필요, 3D 게임의 집중 테스트 필요성 명시), `https://github.com/sjhdeux0114/macDeckAI.git` 푸시.
- `README.md` 전면 개편:
  - Apple Silicon 네이티브 UI (SwiftUI/AppKit), Rosetta 2 + WineSikarugir 10.0-8, DXMT 0.80(SetRotation 패치) -> Apple Metal 가속 파이프라인 정리.
  - 외장 드라이브(SSD/HDD) 연동, 게임패드(DualShock 4 등) 지원, 세션별 정밀 진단(Diagnostics) 시스템 명시.
  - **2D/3D 게임 검증 현황 명확화**:
    * 2D 게임: Brogue CE(Windows x86_64, Direct3D 11/Metal)로 1차 검증 완료, 다양한 2D 엔진 대상 추가 테스트 확장 진행 중.
    * 3D 게임: D3D10/11 -> DXMT -> Metal 파이프라인 구축 완료, 셰이더/D3D12/안티치트 등 다양한 변수로 인해 집중적인 테스트가 많이 필요함을 명시.
  - 아키텍처 다이어그램, 디렉터리 구조, 빌드/실행 가이드, 보안 및 라이선스 고지 포함.
- 보안 및 저장소 정비:
  - `.gitignore`에 일시적 QR 스크린샷(`evidence/steam-setup/big-picture-login.png`) 및 인증 관련 파일 패턴 추가하여 민감 정보 유출 방지.
  - GitHub CLI 인증 연동 후 `main` 브랜치로 초기 커밋(114개 파일, 약 3.2MB) 및 원격 푸시 완료.

### 2026-10-18 — 3D 게임 (Resident Evil 3) D3D12CreateDeviceFailed 에러 로그 분석

- 사용자 보고: 3D 게임 실행 시 `D3D12CreateDeviceFailed` (renderdevicedx12.cpp line 11769) 에러 발생 및 원인 로그 요청.
- 확인된 실행 게임: **Resident Evil 3 (RE3, AppID: 952060)**, 외장 드라이브 `E:\SteamLibrary\steamapps\common\RE3\re3.exe`.
  - 외장 드라이브(NVMe_1T) 연동 및 실제 Steam을 통한 24.9 GB 대용량 게임 다운로드/설치는 정상 동작함을 확인.
- 관련 로그 확인:
  - `~/Library/Application Support/MacDeck/Logs/Sessions/2026-10-17T14-54-31Z-D60BEB33-7A54-45A5-9F23-D6DFD57D66B0/Renderer/re3_dxgi.log`: `warn: DXGIAdapter: Unknown interface query 17399d75-964e-4c03-99f8-9d4fd196dd62`
  - Steam `logs/gameprocess_log.txt`: `[23:54:58] AppID 952060 adding PID 1316 as a tracked process "E:\SteamLibrary\steamapps\common\RE3\re3.exe"`, `[23:55:14] exit code 1`
  - 게임 설정 파일 (`re3_config.ini`): `[Render] Capability=DirectX12`
  - 게임 폴더: `D3D12/D3D12Core.dll` (DirectX 12 Agility SDK 번들 확인)
- 실패 원인 분석:
  - RE3는 Capcom 차세대 패치(Next-Gen Update)로 인해 기본 렌더러가 DirectX 12(Agility SDK)로 강제 설정됨.
  - 현재 MacDeck의 그래픽 가속 레이어는 **DXMT 0.80 (Direct3D 10/11 -> Apple Metal)** 기반으로, D3D12를 Metal로 변환하는 레이어가 없어 `D3D12CreateDevice` 실패 발생.
- 해결 방안:
  - Steam 속성 → 베타(Betas) 탭에서 Capcom이 공식 제공하는 **`dx11_non-rt`** 브랜치로 전환하여 Direct3D 11 모드로 구동하거나, MacDeck 자체에 DirectX 12 가속 파이프라인(VKD3D + MoltenVK)을 통합.

### 2026-10-18 — DirectX 12(VKD3D + MoltenVK → Metal) 통합 및 외장 폴더 시작 시 자동 연결 (v0.5.0)

- 사용자 요청:
  1. "dx12도 가능하도록 작업해줘" / "여전히 오류"
  2. "게임 설치 폴더 설정된 내역이 있으면 앱 실행할때 자동으로 연결하도록 해"
- DirectX 12(`D3D12CreateDeviceFailed`) 근본 원인 규명:
  1. **Vulkan 로더 심볼릭 링크 누락**: Wine의 `win32u.so`(`vulkan_init_once`)는 `dlopen("libvulkan.1.dylib")`를 호출하나, `Runtime/lib/`에는 `libMoltenVK.dylib`만 존재하고 `libvulkan.1.dylib` / `libvulkan.dylib` 심볼릭 링크가 없었음.
  2. **DXMT `dxgi.dll`과 Wine `d3d12.dll` 간 어댑터/스왑체인 인터페이스 충돌**:
     - `prepare-metal-runtime.py`가 Wine 내장 `dxgi.dll`(237,568 bytes)을 DXMT `dxgi.dll`(1,890,058 bytes)로 덮어썼음.
     - DXMT는 D3D10/11 전용이므로 `DXGIAdapter`가 Wine D3D12의 내부 인터페이스 `IID_IWineDXGIAdapter`(`17399d75-964e-4c03-99f8-9d4fd196dd62`)와 `ID3D12CommandQueue` 스왑체인을 구현하지 않아 `E_NOINTERFACE` 반환 및 `D3D12CreateDeviceFailed` 발생.
  3. **중간 재시도 시 오류 원인**: `.cache/mac-runtime/wine-steam10/wswine.bundle/lib/wine/x86_64-windows/dxgi.dll`이 이전 테스트 중 DXMT `dxgi.dll`(1.89MB)로 덮어써져 있어 1차 패키징 시 DXMT `dxgi.dll`이 `dxgi-d3d12`로 복사되었고, 기존 실행 중이던 `steam.exe` 프로세스가 이전 환경변수를 유지하고 있었음. `prepare-metal-runtime.py`에서 원본 크기(x64 `237,568` bytes, x86 `225,294` bytes)를 검증·복원하도록 수정하여 해결.
- 변경 파일 및 구현 내용:
  - `scripts/prepare-metal-runtime.py`:
    - `Runtime/lib/libvulkan.1.dylib -> libMoltenVK.dylib`, `libvulkan.dylib -> libMoltenVK.dylib` 심볼릭 링크 생성.
    - Wine 원본 `dxgi.dll`(237,568 bytes)을 아카이브에서 검증·복원한 뒤 `Wine builtin DLL` 서명을 `Wine native  DLL`로 패치하여 `Runtime/lib/wine/dxgi-d3d12/{x86_64-windows,i386-windows}/dxgi.dll`에 보존.
    - 기본 `Runtime/lib/wine/{x86_64-windows,i386-windows}/dxgi.dll` 및 `d3d11.dll`은 DXMT(SetRotation 패치 포함) 유지.
  - `Sources/MacDeck/Library.swift`:
    - `GraphicsBackend`(`auto`, `dxmt`, `d3d12`) 및 `DirectX12Support` 구현.
    - 게임 폴더 내 `D3D12/D3D12Core.dll`, `d3d12.dll`, `.ini`의 `Capability=DirectX12`, 실행 파일의 `D3D12CreateDevice` 임포트 여부를 자동 감지.
    - D3D12 게임에는 `dxgi-d3d12`의 Wine `dxgi.dll`(237KB)을 실행 폴더에 자동 배치하고, DXMT 전환 시 관리 대상 `dxgi.dll`만 정리(서드파티 `dxgi.dll`은 보존).
    - `WINEDLLOVERRIDES`를 `dxgi=n,b;d3d11,d3d10core,d3d12,d3d12core,vulkan-1,winevulkan,winemetal=b`로 설정해 D3D10/11(DXMT)과 D3D12(VKD3D/MoltenVK) 동시 지원.
  - `Sources/MacDeck/SteamStorage.swift`, `Sources/MacDeck/ExternalLibrary.swift`, `Sources/MacDeck/Runtime.swift`:
    - `autoConnectAll` 및 `reconnectExternalLibraries` 추가: 앱 시작(`start()`) 및 게임 새로고침 시 `library.json`에 설정된 외장 게임 설치 폴더(`externalLibraries`)가 연결되어 있으면 Wine `dosdevices/<drive>:` 심볼릭 링크를 자동 생성/마이그레이션(`E:\SteamLibrary`)하고 Steam `libraryfolders.vdf` 등록 상태를 자동 복구.
    - `library.json`에 `driveFolder`가 없던 기존 항목도 `nonRootMapping` 기준으로 일관되게 인식 및 마이그레이션되도록 수정.
  - `Sources/MacDeck/App.swift`, `Sources/MacDeck/Diagnostics.swift`, `Sources/MacDeck/SelfTests.swift`:
    - 게임 실행 설정에 그래픽 백엔드 선택기 추가, 진단 요약에 D3D12/IWineDXGIAdapter 단서 추가, 자체 검사 **68개**로 확장.
- 실제 실행한 검증과 결과:
  - `bash scripts/package-mac-app.sh` 실행 → **68 checks passed** (`evidence/v05-d3d12-tests.log`), `codesign --verify --strict` 통과.
  - `re3.exe`(Resident Evil 3, DirectX 12) 실제 실행 검증: `vkd3d 1.14` → `winevulkan` → `MoltenVK 1.4.1` → `Apple M5 (Metal 3)` 장치 생성, `RESIDENT EVIL 3` 창(`1518x994`) 및 `d3d12_swapchain_Present` 정상 동작 확인 (`evidence/re3-d3d12-moltenvk.log`).
  - `/Users/sjhdeux/Applications/MacDeck.app` 설치본 교체 및 재시작 후 `library.json`에 `driveFolder: "/Volumes/NVME_1T"` 자동 반영, `RE3/dxgi.dll`(237,568 bytes) 배포, 새 Steam 세션(v0.5.0) 시작 확인.

### 2026-10-18 — `work.md` 및 `README.md` 누적 변경 내역 동기화 규칙 강화

- 사용자 요청: "수정할때마다 work.md파일에 수정내역 누적으로 추가하고 readme.md파일에도 변경내역등을 추가해줘"
- 변경 파일 및 내용:
  - `AGENTS.md`: 코드나 설정을 수정할 때마다 `work.md`에 누적 수정내역을 추가하고, `README.md`에도 변경내역(Changelog 및 기능/검증 현황)을 함께 누적 갱신하도록 작업 지침 명문화.
  - `README.md`: 하단에 `📋 변경 내역 (Changelog)` 섹션을 신설하여 `v0.1.0` ~ `v0.5.0`까지의 버전별 주요 변경·개선·검증 내역을 정리하고 이후 수정 시 계속 누적되도록 구성.
  - `work.md`: 본 작업 이력 누적 추가.

### 2026-10-18 — 전역 DX11 Mode / DX12 Mode 전환 설정 및 macOS Game Mode 활성화 (v0.5.1)

- 사용자 요청:
  1. "Game Mode 가 Off로 되어있는데 On으로 설정해줘"
  2. "오류발생해 그냥 dx11 로 해야할거같아"
  3. "설정에서 dx11 mode, dx12 mode 선택해서 플레이 할수 있게 하자. 일단 dx12 는 오류가 있는건 어쩔수없는거같아"
  4. "re3만 dx11 mode , dx12 mode 고르는게 아니게 모든 게임에 전역으로 설정 되어야 해"
- 분석 및 원인 확인:
  - **DX12 전체화면 진입 및 크래시 원인**: Resident Evil 3 (`re3.exe`)가 DX12 Mode(VKD3D 1.14 + MoltenVK 1.4.1)로 Apple M5 Metal 3 전체화면(`2704x1756`, Metal 메모리 `2.27GB`, `38.45 FPS`) 렌더링까지 진입했으나, Wine 10 내장 VKD3D 1.14 + MoltenVK의 RE Engine DX12 파이프라인 한계로 타이틀 진입 직후 크래시 발생.
  - **전역 DX11 Mode / DX12 Mode 분리 필요성**: `re3.exe` 바이너리 역어셈블(`0x142c9f302` ~ `0x142c9f670`) 결과 `LoadLibraryW(L"d3d12.dll")`가 실패(`NULL`)하면 `re3_config.ini`에 `Capability=DirectX11` 및 `TargetPlatform=DirectX11`을 기록하고 내장된 `RenderDeviceDX11`(`0x142f892c0`)을 생성하는 구조임을 확인. 따라서 **DX11 Mode**에서는 런타임 `dxgi.dll`을 DXMT로 전환하고 `WINEDLLOVERRIDES`에서 `d3d12,d3d12core=`를 비활성화하여 모든 멀티 API 게임이 DX11(DXMT → Metal) 경로로 동작하도록 구성.
  - **macOS Game Mode(`Game Mode: Off`) 원인**: macOS `/usr/libexec/gamepolicyd`는 전체화면 Metal 창을 소유한 프로세스(`Runtime/bin/wine` 및 `MacDeck.app`)의 `Info.plist`(`LSApplicationRecord`)에서 `LSApplicationCategoryType = public.app-category.games`, `LSSupportsGameMode = true`, `GCSupportsGameMode = true`를 확인함. 기존 `Runtime/bin/wine`의 내장 `__TEXT,__info_plist` 섹션에는 `<key>LSUIElement</key><string>1</string>`이 들어 있었고 게임 카테고리 키가 없었음.
- 변경 파일 및 내용:
  - `scripts/prepare-metal-runtime.py`:
    - `Runtime/lib/wine/dxgi-dxmt/{x86_64-windows,i386-windows}/dxgi.dll`(DXMT 1.89MB)과 `Runtime/lib/wine/dxgi-d3d12/{x86_64-windows,i386-windows}/dxgi.dll`(Wine 원본 237KB)을 각각 보존하여 전역 모드 전환 시 런타임 레벨에서 즉시 교체되도록 구성.
    - `Runtime/bin/wine` 실행 파일 내부 `__TEXT,__info_plist` 섹션(정확히 936바이트 길이 유지)에서 `LSUIElement=1`을 제거하고 `LSApplicationCategoryType=public.app-category.games`, `LSSupportsGameMode=true`, `GCSupportsGameMode=true`를 패치 후 ad-hoc 재서명.
  - `scripts/build-mac-app.sh`:
    - `MacDeck.app/Contents/Info.plist` 버전을 `0.5.1` (`CFBundleVersion = 7`)로 올리고 `LSApplicationCategoryType=public.app-category.games`, `LSSupportsGameMode=true`, `GCSupportsGameMode=true` 추가.
  - `Sources/MacDeck/Library.swift`:
    - `GraphicsBackend`를 전역 `dxmt` (**DX11 Mode**) / `d3d12` (**DX12 Mode**) 2가지 모드로 정리(기존 `"auto"` JSON 값은 기본값 `.dxmt`로 호환 디코딩).
    - `LibraryData`에 전역 `graphicsBackend: GraphicsBackend?` 추가(기본값 `.dxmt` = **DX11 Mode**).
    - `DirectX12Support.applyGlobal(mode:wine:games:)`: 전역 모드에 따라 `Runtime/lib/wine/{x86_64-windows,i386-windows}/dxgi.dll`을 `dxgi-dxmt`(DX11) 또는 `dxgi-d3d12`(DX12)로 전환하고, 게임 폴더 내 관리 대상 `dxgi.dll`을 정리하며, 게임 `.ini` 설정 파일의 `Capability`/`TargetPlatform`을 `DirectX11` 또는 `DirectX12`로 동기화.
    - `DirectX12Support.dllOverrides(for:)`:
      - **DX11 Mode (`.dxmt`)**: `d3d11,dxgi,d3d10core,winemetal=b;d3d12,d3d12core=` (`d3d12`/`d3d12core` 비활성화 → DX11 강제).
      - **DX12 Mode (`.d3d12`)**: `dxgi,d3d12,d3d12core,vulkan-1,winevulkan,d3d11,d3d10core,winemetal=b` + `MVK_CONFIG_RESUME_LOST_DEVICE=1`.
  - `Sources/MacDeck/Runtime.swift`:
    - `DeckModel.setGraphicsBackend(_:)`: 전역 그래픽 모드 변경 시 `library.json` 저장, 런타임 및 전체 게임 폴더 즉시 동기화, Steam이 실행 중이면 자동으로 정상 종료(`stopAndWait`) 후 새 전역 모드 환경변수로 Steam을 재시작(`launchSteam`).
  - `Sources/MacDeck/App.swift`:
    - 상단 툴바(모든 화면에서 즉시 전환 가능한 `DX11 Mode` / `DX12 Mode` 세그먼트 선택기), `런타임` 탭의 `전역 그래픽 모드 (모든 게임 공통)` 패널, `Steam` 탭의 `Steam 전용 환경 및 전역 그래픽 모드` 패널, 게임 실행 설정 시트에 전역 모드 선택기 배치.
  - `Sources/MacDeck/SelfTests.swift`:
    - 전역 DX11 Mode 기본 오버라이드(`d3d12,d3d12core=` 비활성화), 전역 DX11/DX12 모드 전환 시 런타임 `dxgi.dll` 교체 및 `.ini` 동기화, 서드파티 `dxgi.dll` 보존을 포함한 **69개 자체 검사**로 확장.
- 실제 실행한 검증과 결과:
  - `bash scripts/package-mac-app.sh` 실행 → **69 checks passed** (`evidence/v051-global-mode-tests.log`), `codesign --verify --strict dist/MacDeck.app` 통과.
  - `Runtime/bin/wine` 내장 `__TEXT,__info_plist` 및 `dist/MacDeck.app/Contents/Info.plist`에 `public.app-category.games`, `LSSupportsGameMode`, `GCSupportsGameMode` 반영 및 서명 검증 완료.

### 2026-10-18 — 런타임 구성요소(MoltenVK · DXMT · Wine Engine) 확인 및 자동 업데이트 구현 (v0.5.2)

- 사용자 요청: "MacDeck App설정에서 MoltenVK , wine 등의 업데이트 파일을 확인하고 자동 업데이트 할 수있는 기능이 필요해"
- 설계 및 상위 저장소 현황 분석:
  - **MoltenVK** (`https://api.github.com/repos/KhronosGroup/MoltenVK/releases/latest`): 현재 번들된 `WS12WineSikarugir10.0_8` 내장 버전은 `v1.4.1`이며, 공식 최신 릴리스는 **`v1.4.2`** (`MoltenVK-macos.tar`, `sha256:f95765a6229cb7b915990a2890ce12ebe36a730b021545d3d52ae69ce4c4024e`, Metal argument buffer device loss 및 imported `MTLBuffer` residency 개선 포함).
  - **DXMT** (`https://api.github.com/repos/3Shain/dxmt/releases/latest`): `dxmt-v*-builtin.tar.gz` 에셋 추적 (`v0.80`).
  - **Wine Engine** (`https://api.github.com/repos/Sikarugir-App/Engines/releases/latest`): `WS12WineSikarugir10.0_*.tar.xz` 에셋 중 `Battle.Net` 전용 빌드를 제외한 최신 버전 추적 (`v10.0_8`).
- 변경 파일 및 내용:
  - `Sources/MacDeck/RuntimeUpdater.swift` (신규):
    - `RuntimeComponentKind` (`.moltenvk`, `.dxmt`, `.wine`), `RuntimeReleaseAsset`, `RuntimeComponentStatus`, `RuntimeVersionStore`, `RuntimeUpdater` 구현.
    - 현재 설치된 런타임의 바이너리 문자열(`libMoltenVK.dylib` → `v1.4.1`, `d3d11.dll` → `v0.80`), `Runtime/version` 파일(`v10.0_8`), 및 `Runtime/runtime-versions.json`을 통해 설치 버전을 정확히 감지.
    - GitHub Releases API JSON 파싱(`tag_name`, 에셋 URL, `digest: sha256:...`), 다운로드 후 SHA-256 무결성 검증, 임시 디렉터리 압축 해제(`tar` / `unzip`).
    - **MoltenVK 업데이트**: 압축 해제된 패키지에서 `MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib`를 찾아 `x86_64` Mach-O 아키텍처 슬라이스 포함 여부(`hasX86_64Slice`)를 검증한 뒤 기존 파일을 백업하고 원자적으로 교체, `libvulkan.1.dylib` / `libvulkan.dylib` 심볼릭 링크 유지 및 ad-hoc 재서명.
    - **DXMT 업데이트**: `x86_64-unix`, `x86_64-windows`, `i386-windows`의 `winemetal.so`, `winemetal.dll`, `d3d11.dll`, `dxgi.dll`, `d3d10core.dll`을 업데이트하면서 `SetRotation(IDENTITY)` 인라인 패치 및 `dxgi-dxmt` 보존본과 현재 전역 그래픽 모드(`DX11 Mode` / `DX12 Mode`)를 유지.
    - **Wine Engine 업데이트**: `wswine.bundle` 동기화 시 기존 `libMoltenVK.dylib`와 DXMT DLL들을 보존하고, 새 Wine `dxgi.dll`을 `dxgi-d3d12`에 갱신하며, `bin/wine`의 내장 `__TEXT,__info_plist`에 macOS Game Mode 패치(`patchWineGameModePlist`) 적용 후 ad-hoc 재서명.
  - `Sources/MacDeck/Library.swift`:
    - `LibraryData`에 `autoUpdateRuntime: Bool?` 설정 추가 (기본값 `true`).
  - `Sources/MacDeck/Runtime.swift`:
    - `DeckModel`에 `runtimeComponents`, `checkingUpdates`, `updatingComponents`, `updateBannerMessage`, `checkRuntimeUpdates(autoInstall:)`, `updateComponent(_:)`, `updateAllAvailableComponents()` 추가.
    - 앱 시작(`start()`) 시 `autoUpdateRuntime`이 켜져 있으면 백그라운드에서 자동으로 최신 버전을 확인하고 새 버전(예: MoltenVK `v1.4.2`)을 자동 설치하며, 업데이트 시 실행 중인 Steam을 안전하게 재시작.
  - `Sources/MacDeck/App.swift`:
    - `런타임` 설정 화면에 **"런타임 구성요소 자동 업데이트 (MoltenVK · DXMT · Wine)"** 패널 추가 (자동 업데이트 토글, 구성요소별 현재 버전/최신 버전/상태 배지, 개별 업데이트 버튼, "업데이트 확인" 및 "지금 자동 업데이트 실행" 버튼, 사이드바 업데이트 가능 개수 배지).
  - `Sources/MacDeck/SelfTests.swift`, `scripts/build-mac-app.sh`:
    - 앱 버전을 `0.5.2` (`CFBundleVersion = 8`)로 갱신하고, `RuntimeUpdater` 버전 비교·GitHub Release JSON 파싱(MoltenVK/DXMT/Wine)·SHA-256 무결성 검증·Mach-O `x86_64` 검증 및 로컬 아카이브 설치 테스트 5종을 추가하여 총 **74개 자체 검사**로 확장.
- 실제 실행한 검증과 결과:
  - `bash scripts/build-mac-app.sh && dist/MacDeck.app/Contents/MacOS/MacDeck --self-test && codesign --verify --strict dist/MacDeck.app` 실행 → **74 checks passed** (`evidence/v052-runtime-updater-tests.log`), 서명 검증 통과.

### 2026-10-18 — `steamwebhelper.exe` `0x80000003` (`DelayLoadFailureHook`) 크래시 및 `winedbg` 모달/콘솔 반복 팝업 근본 수정 (v0.5.3)

- 사용자 요청: "오류가 계속 발생해" / "에러는 없어졌는데 터미널만 계속 켜졌다가 꺼지면서 스팀앱이 실행이 안돼" / "에러 나" (`Program Error: The program steamwebhelper.exe has encountered a serious problem and needs to close` 및 `Unhandled exception 0x80000003 ... at address 00006FFFF24CF905`)
- 원인 분석 (`WINEDEBUG=+seh,+loaddll,+module` 및 `libcef.dll` 디스어셈블리):
  1. **Chromium `DelayLoadFailureHook` (`libcef.dll+0x59ef905`, `0x80000003`) 발생 원인**:
     - `libcef.dll`의 RVA `0x59ef7d0`~`0x59ef905`를 역어셈블한 결과, 지연 로드(Delay-Load) 대상 DLL(`dxgi.dll`, `d3d12.dll` 등) 로드 실패 시 `"bthprops.cpl"`을 제외한 모든 모듈에 대해 `DelayLoad-ModuleName` 크래시 키를 기록하고 즉시 `int3` (`0x80000003`, `EXCEPTION_BREAKPOINT`)를 발생시키는 Chromium `DelayLoadFailureHook`임을 확인.
     - `WINEDEBUG=+module` 추적 결과, `Bottles/Steam/drive_c/windows/system32/dxgi.dll` 파일이 누락되어 `0274:warn:module:load_dll Failed to load module L"dxgi.dll"; status=c0000135` (`STATUS_DLL_NOT_FOUND`)가 발생했고, 또한 v0.5.1의 DX11 Mode `WINEDLLOVERRIDES`에서 `d3d12,d3d12core=`로 `d3d12.dll`을 비활성화하고 `vulkan-1,winevulkan=b`를 누락시켜 `steamwebhelper.exe`(`libcef.dll`)가 시작 직후 `0x80000003`으로 충돌했음.
  2. **`winedbg --auto` 모달 창 / 콘솔 창 반복 팝업 및 공유 메모리 잠금**:
     - 예외 발생 시 Wine `UnhandledExceptionFilter`가 `AeDebug` 레지스트리에 따라 `winedbg --auto <pid> <event>`를 실행하여, `ShowCrashDialog=1`이면 `Program Error` 모달 창으로 `steamwebhelper.exe` 프로세스를 일시정지 상태로 붙잡아 두고(`SteamChrome_MasterStream_spid32_mem` 공유 메모리 잠금 유발), `ShowCrashDialog=0`이면 10초마다 콘솔(`conhost.exe`) 창을 띄우며 죽이고, `AeDebug\Auto="0"`이면 `"Do you wish to debug it? [Yes] [No]"` 대화상자를 표시했음.
  3. **런타임 파일 교체와 Steam 기동 간 경합**:
     - 앱 시작(`start()`) 시 `checkRuntimeUpdates(autoInstall: true)`가 `launchSteam()`과 동시에 실행되거나, `setGraphicsBackend(_:)`에서 Steam 종료 전에 `dxgi.dll`을 먼저 덮어쓰는 경합 가능성 확인.
- 변경 파일 및 내용:
  - `Sources/MacDeck/Library.swift`:
    - `DirectX12Support.syncPrefix(_:mode:runtimeRoot:)`: 모든 Wine prefix(`Bottles/*` 및 게임별 prefix)의 `drive_c/windows/system32/dxgi.dll`과 `drive_c/windows/syswow64/dxgi.dll`을 현재 전역 그래픽 모드(`dxgi-dxmt` 또는 `dxgi-d3d12`)와 항상 동기화하고, 누락된 코어 그래픽 DLL(`d3d11.dll`, `d3d10core.dll`, `d3d12.dll`, `d3d12core.dll`, `winemetal.dll`) 및 `system.reg`의 `AeDebug` `"Auto"="1"` 설정을 자동 복구.
    - `DirectX12Support.dllOverrides(for:)`: DX11/DX12 양쪽 모드 모두 `winedbg.exe=d`를 포함해 디버거 모달/콘솔 팝업을 원천 차단하고, `d3d11,dxgi,d3d10core,d3d12,d3d12core,vulkan-1,winevulkan,winemetal=b`를 유지하여 `libcef.dll`의 Delay-Load가 절대 실패하지 않도록 수정 (DX11 Mode 강제는 DXMT `dxgi.dll` 브리지 및 게임 `.ini` 설정 동기화로 처리).
  - `Sources/MacDeck/SteamStorage.swift`:
    - `stopAndWait(wine:)` 완료 후 `killPrefixProcesses(wine:)`(`wineserver -k`)를 호출하여 잔존 `steamwebhelper.exe` / `winedevice.exe` 프로세스와 공유 메모리를 완전히 정리.
  - `Sources/MacDeck/Runtime.swift`:
    - `start()`에서 Steam 자동 기동 시에는 백그라운드 업데이트 확인만 수행(`autoInstall: false`)하여 Steam 기동 중 dylib/DLL 덮어쓰기를 방지하고, `updateComponent` / `updateAllAvailableComponents` / `setGraphicsBackend` 실행 시에는 Steam을 먼저 정상 종료(`stopAndWait`)한 뒤 파일을 교체하고 재시작하도록 순서 수정.
  - `Sources/MacDeck/SelfTests.swift`, `scripts/build-mac-app.sh`:
    - 버전을 `0.5.3` (`CFBundleVersion = 9`)으로 올리고, `winedbg.exe=d` 및 prefix 내부 `drive_c/windows/system32/dxgi.dll` 동기화 검증을 포함한 **74개 자체 검사** 갱신.
- 실제 실행한 검증과 결과:
  - `bash ./scripts/build-mac-app.sh && ./dist/MacDeck.app/Contents/MacOS/MacDeck --self-test | tee evidence/v053-webhelper-fix-tests.log` → **74 checks passed**.
  - `/Users/sjhdeux/Applications/MacDeck.app` 동기화 후 실제 실행(`open /Users/sjhdeux/Applications/MacDeck.app`) → `steamui_html.txt`에서 `BrowserReady: handle:65536` 및 `webhelper.txt`에서 `SP BPM_uid0`, `notificationtoasts_uid2`, `contextmenu_1_uid0` 정상 로드 확인 (`-startcount=0`, 재시작 0회, `winedbg` 프로세스 0개, 예외 0건).

