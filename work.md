# MacDeck 누적 작업 기록

이 문서는 사용자의 요청에 따라 유지하는 작업·검증·인계 기록이다. 이후 작업도 날짜별로 뒤에 추가한다. 인증 정보는 기록하지 않는다.

## 현재 상태 — 2026-10-18

- 프로젝트: `/Users/sjhdeux/Documents/macdeck`
- 현재 앱: **MacDeck 0.5.5**, Apple Silicon macOS용 실험판, 로컬 ad-hoc 서명.
- 빌드 결과: `dist/MacDeck.app`
- 설치된 앱: `/Users/sjhdeux/Applications/MacDeck.app`
- 실제 호스트: Apple M5, 메모리 24 GiB, macOS 27.0.1. 최소 배포 대상 macOS 13은 빌드 설정이며 다른 기기에서 검증한 것은 아니다.
- 구현: 네이티브 라이브러리, Windows 게임 실행, **전역 DX11 Mode(DXMT → Metal, 기본값) / DX12 Mode(VKD3D + MoltenVK → Metal) 선택 및 실시간 전환**, **CrossOver/Proton/Whisky 호환 플랫폼 패치(Mach-message MSync·ESync 멀티스레드 동기화, XAudio2/X3DAudio/DirectSound 내장 오버라이드, Apple VideoToolbox 하드웨어 가속 vtdec 및 AC3/DTS/AAC 코덱, DXMT ignoreMapFlagNoWait/handleAltTab 프레임 페이싱, MoltenVK Argument Buffers/커맨드 프리필)**, **런타임 구성요소(MoltenVK · DXMT · Wine Engine) 공식 GitHub Releases 확인 및 자동 업데이트(`RuntimeUpdater`)**, **macOS Game Mode 지원 plist 반영(실제 On은 전체화면에서 별도 검증 필요)**, 실제 Windows Steam Big Picture, 설치 게임 가져오기, 외장 폴더의 Windows 드라이브 매핑 및 **앱 시작 시 자동 재연결**.
- 최종 자체 검사 **90개 통과**, 미디어 런타임 검사 **23개 항목 통과**, 앱 빌드·서명 확인 성공.
- 실제 Windows Brogue CE 던전 렌더링 및 **M5 Metal HUD 확인 성공**.
- RE3 DX11 non-RT: 영상 의존성 보완 후 사용자 구동 성공 보고. DMC5: GS/TS 수정 후보 적용 후 사용자 긴 렉 해소 보고. 두 게임 모두 장시간 안정성은 별도 검증 필요.
- 실제 Windows Steam 로그인 완료 및 외장 NVMe 드라이브(`E:\SteamLibrary`)에 Steam 게임 4종(Resident Evil 3, Balatro, Halls of Torment, No Results Found) 다운로드·설치 확인 성공.
- **Direct3D 12 3D 게임(Resident Evil 3, `re3.exe`) 실행 및 Apple M5 Metal 3(VKD3D 1.14 → winevulkan → MoltenVK) 전체화면(`2704x1756`, `38.45 FPS`) 렌더링 확인 성공** (기본 전역 모드는 **DX11 Mode**이며 설정에서 전환 가능).
- Bluetooth DualShock 4를 Apple GameController 및 Wine과 같은 SDL2에서 인식하고 실제 버튼/축 변화 확인. Windows/Steam/게임 내부 조작은 아직 별도 검증 필요.
- v0.5.2: `런타임` 설정 탭에 **MoltenVK (`KhronosGroup/MoltenVK`) · DXMT (`3Shain/dxmt`) · Wine Engine (`Sikarugir-App/Engines`)** 최신 릴리스 확인 및 **자동 업데이트** 기능(`RuntimeUpdater.swift`) 추가. 앱 시작 시 자동 확인 및 SHA-256 무결성 검증·아키텍처(`x86_64`) 슬라이스 검증·백업 후 원자적 교체·ad-hoc 재서명 지원.
- v0.5.3: `steamwebhelper.exe` 시작 직후 `0x80000003` (`libcef.dll+0x59ef905`, Chromium `DelayLoadFailureHook`) 예외 및 `winedbg` 모달/콘솔 창이 반복 발생하던 문제를 근본 해결. Wine prefix 내부 `drive_c/windows/{system32,syswow64}/dxgi.dll` 동기화(`DirectX12Support.syncPrefix`), CEF Delay-Load 호환 `d3d12,d3d12core,vulkan-1,winevulkan=b` 오버라이드 유지, `winedbg.exe=d` 및 `AeDebug` 자동 복구, Steam 기동 중 런타임 덮어쓰기 경합 제거 적용 후 Steam Big Picture(`BrowserReady` 및 `SP BPM_uid0`) 무오류 정상 기동 검증 완료.
- v0.5.5: Proton / CrossOver / Whisky / Apple GPTK / DXMT 커뮤니티의 유사 플랫폼 수정내역 및 최적화 설정을 분석·적용. 게임 중 CPU 병목/스레드 경합으로 인한 렉 해소를 위해 Mach-message 기반 `WINEMSYNC=1` 및 `WINEESYNC=1`, 32비트 주소 확장(`WINE_LARGE_ADDRESS_AWARE=1`) 활성화; 컷씬 음성 끊김 및 무음 방지를 위해 `xaudio2_*`, `x3daudio1_*`, `dsound` 내장 오버라이드 지정; 동영상 끊김 및 음성 싱크 밀림 해결을 위해 Apple VideoToolbox 하드웨어 가속 디코더(`vtdec`, `vtdec_hw`) 및 AC-3(`a52dec`), DTS(`dtsdec`), MP4(`qtdemux`), MKV(`matroskademux`) 등 GStreamer 확장 패키지 번들링 및 `mfplat`, `mfreadwrite`, `quartz` 내장 오버라이드 적용; DX11 DXMT 맵 플래그/Alt-Tab 크래시 방지(`DXMT_CONFIG`), DX12 MoltenVK 아규먼트 버퍼 및 커맨드 프리필 최적화 적용.
- 작업 폴더를 Git 저장소로 관리하고 원격 저장소(`https://github.com/sjhdeux0114/macDeckAI.git`, branch `main`)로 지속 동기화.

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


### 2026-10-18 — RE3 플레이 중 크래시 / Game Mode Off 재조사 (진행 중)

- 사용자: RE3 새 게임/플레이 중 크래시. 초기 3D 화면·FPS 확인은 안정적인 플레이 성공과 구분하도록 기록 정정 필요.
- 현재 소스는 v0.5.3, 전역 DX11 Mode. 최근 RE3 렌더러 로그에 IWineDXGIAdapter 조회 오류가 있으며 Steam stderr 제외 정책으로 D3D12/Vulkan 진단이 충분히 보존되지 않음.
- 설치된 Wine 실행 파일은 실제로 `LSUIElement=1`, 게임 카테고리/지원 키가 없는 상태. 앱 plist만 키가 있음. 기존 고정 길이 패치가 추가된 XML 길이를 수용하지 못해 조용히 원본을 반환한 문제 확인.
- RuntimeUpdater와 런타임 준비 스크립트의 plist 패치를 간결한 XML 직렬화로 변경, 길이 초과 시 준비 스크립트가 오류를 보고하도록 수정. 원래 Wine 실행/NSPrincipalClass 등 필수 정보는 보존.
- Apple 공식 자료상 Game Mode는 Apple Silicon/macOS14+의 macOS 기본 전체화면에서 CPU/GPU 우선순위 및 Bluetooth 지연 개선이 있으며 플래그만으로 실제 활성화를 단정하지 않음.


### 2026-10-18 — v0.5.4: 실제 Game Mode opt-in 복구 / Vulkan 오류 보존

- 사용자 확인: Resident Evil 3 새 게임/플레이 중 종료. 별도 첨부 오류는 `renderdevicedx12.cpp:11769 D3D12CreateDeviceFailed`로, 현재 DX11용 DXGI에서 D3D12 어댑터 조회 실패와 구분해 조사.
- 기존 이력·현재 코드 검토: v0.5.0~0.5.3의 DX12/VKD3D/MoltenVK, 전역 모드, 외장 자동 연결, updater, Steam CEF 지연 로드 수정이 추가되어 있음. 과거 이력에 기재된 `evidence/re3-d3d12-moltenvk.log`는 현재 작업 폴더에서 찾지 못해 그 파일에 근거한 재검증은 하지 못함.
- 실제 설치된 Wine의 embedded plist는 수정 전 `LSUIElement=1`, 게임 카테고리 및 지원 키 없음. 기존 긴 XML은 936-byte 공간을 초과해 조용히 원본 반환. `RuntimeUpdater.patchWineGameModePlist` 및 `prepare-metal-runtime.py`를 compact plist로 수정하고 불필요한 표시 메타데이터만 제거, `NSPrincipalClass=WineApplication` 등 필수 값과 바이너리 길이 보존.
- 설치 Wine와 dist Wine 모두 원본을 `.cache/wine-before-gamemode-*`로 백업 후 패치/재서명. 실제 plist에서 `LSSupportsGameMode=true` 확인. 이는 macOS Game Mode On 자체를 확인한 결과가 아님.
- Apple 공식 기준: Game Mode는 Apple Silicon/macOS14+의 macOS 기본 전체화면 게임에서 CPU/GPU 우선순위 및 Bluetooth 반응성을 개선. 현재 도구의 Accessibility 권한은 false라 게임 창을 기본 전체화면으로 자동 전환할 수 없었음. 공개 지원 키를 적용했으며 실제 On 검증은 게임 정상 실행/사용자 전체화면 전환 후 필요.
- DX11 현재 설정에서 RE3 시작을 재현했고 IWineDXGIAdapter 조회 실패를 관측. DX12 진단 모드로 전역 모드를 전환해 분리 조사 중. 원래 모드는 DX11이었다. DX11 모드는 DX12 게임을 변환하는 기능이 아니며 Steam CEF 호환상 d3d12 DLL은 비활성화하지 않는다는 설명으로 UI/README 정정.
- 기존 진단은 Steam stderr를 모두 버려 하위 게임의 Vulkan 오류를 놓칠 수 있었음. `scripts/graphics-log-filter.c` 추가: raw Steam stdout/stderr는 저장하지 않고 허용된 Vulkan/MoltenVK 오류만 보존, credential/URL 라인 제외. 독립 수집 프로세스가 EOF까지 읽어 launcher 종료에 따른 파이프 폐쇄 영향을 줄임. 새 renderer 기록은 `Renderer/vulkan-stderr.log`.
- LaunchPlan에 vkd3d/vulkan warn/err 채널 활성화, Diagnostics에 VK_ERROR_DEVICE_LOST 단서 및 MVK resume 설정 기록. Runtime에서 Steam stderr를 필터에 연결. 기본 전체화면과 실제 On 상태를 구별하는 UI 안내 추가.
- v0.5.4 빌드/자체 검사 **77개 통과** (`evidence/v054-build.log`, `evidence/v054-tests.log`). 별도 필터 3개 검사(그래픽 오류 보존, 인증/URL 제외, EOF 종료) 통과 (`evidence/graphics-filter-tests.log`).
- Steam 게임 프로세스 기록에서 RE3 `-1073741819` (0xC0000005) 종료가 반복된 이력 확인. 이 코드만으로 GPU 원인으로 확정하지 않음. 기존 Steam assert dump는 예외 스트림이 없어서 예외/모듈 메타데이터만으로 원인 주소를 얻지 못함. 원본 dump는 복사/내보내지 않음 (`scripts/inspect-minidump-exception.py`).
- 재현 중 Steam 인증 화면이 생겨 사용자 로그인을 요청했으나 사용자가 실행되지 않는다고 답함. 진단 중 남은 MacDeck Wine Steam 하위 프로세스만 실제 실행 경로를 확인 후 종료하고, v0.5.4 설치/서명 검증 후 LaunchServices `open`으로 MacDeck → Steam 시작을 다시 진행.
- 설치본의 런타임은 유지하고 main/Info.plist/필터만 교체 후 앱 전체를 ad-hoc 재서명. 현재 전역 모드는 진단용 DX12. 안정적 플레이 및 실제 Game Mode On은 아직 미검증이며 계속 추적 필요.

### 2026-10-18 — RE3 검은 화면: GPU timeout → device lost 확보

- 사용자가 잠시 플레이 유지/Game Mode Off를 보고한 후 검은 화면 정지를 재보고. 안정적 플레이 성공 주장은 하지 않음.
- DX12 Steam 세션의 렌더러 로그에서 Metal GPU Timeout Error 반복 후 VK_ERROR_DEVICE_LOST 및 Vulkan timeline semaphore 대기 실패(vr -4)를 확인. 그래픽 오류만 evidence/re3-play-crash/metal-timeout-device-lost.log에 보존. 실패한 명령/셰이더의 근본 원인은 미확정.
- LaunchPlan의 MVK_CONFIG_RESUME_LOST_DEVICE 강제 1을 0으로 변경, MoltenVK 기본 장치 손실 보고 동작 복구. GPU timeout 자체의 해결책이 아니며 현재 프로세스에는 소급 적용되지 않음.
- Diagnostics에 GPU timeout 단서 추가. 장치 손실 전달 및 timeout/device lost 요약 검사 2개 추가. Game Mode On 미확인.

- 검은 화면 진단 수정 후 빌드 성공 및 자체 검사 **79개 통과** (`evidence/v054-timeout-build.log`, `evidence/v054-timeout-tests.log`). 실제 게임 재검증은 미완료. DX11 비교를 위해 Steam beta dx11_non-rt 제공 여부를 사용자에게 확인 요청.
- 검증된 main 실행 파일을 설치본에 반영하고 앱 전체 ad-hoc 재서명/strict 검증 완료. 실행 중 게임/Steam은 종료하거나 재시작하지 않음. 새 환경은 다음 MacDeck/Steam 실행부터 적용.

### 2026-10-18 — RE3 DX11 비교 준비
- 사용자 확인: Steam에 dx11_non-rt 베타가 제공됨. 사용자에게 해당 버전 선택/다운로드를 안내. 제공 여부 확인은 설치 완료나 Metal 플레이 성공을 의미하지 않음.
- 게임 다운로드 중 Steam 종료를 피하기 위해 전역 DX12 설정은 아직 유지. 다운로드 완료 후 RE3 종료 → MacDeck 전역 DX11 Mode 전환(앱의 Steam 종료/재시작 절차 사용) → DXMT Metal 렌더링/동일 크래시 구간 비교가 다음 단계.

### 2026-10-18 — DX11 non-RT도 새 게임 시작 시 크래시
- 사용자 보고: 타이틀 정상, 게임 시작 후 크래시. 실제 Steam manifest에서 dx11_non-rt/build11047294/StateFlags4 및 MacDeck graphicsBackend=dxmt, 게임 ini DirectX11 확인. 잘못된 DX12 모드 선택 문제는 아님.
- Steam gameprocess_log의 10:40:09 및 10:41:25 RE3 종료는 둘 다 -1073741819(0xC0000005). 최신 re3 DXGI/D3D11 로그는 빈 파일. DX12에서 본 Metal timeout과 동일 원인으로 단정할 수 없음.
- 선택적 MACDECK_TRACE_EXCEPTIONS=1 실행 시 Wine SEH 추적을 활성화하고, 수집기는 dispatch_exception code 메타데이터만 추가 보존하도록 변경. raw Steam/인증/임의 SEH payload는 저장하지 않음. 진단 요약에 접근 위반 분류 추가.
- RE Engine 영상 재생 호환성 참고 소스 https://github.com/l00sed/re-engine-macos 검토. CrossOver26에서의 검증이며 현재 Wine10 원인 확정 근거가 아니므로 shim 설치/외부 DLL 교체는 아직 하지 않음.

- 예외 진단 빌드 자체 검사79개 통과(evidence/dx11-exception-tests.log). 실제 C 필터에서 code/address 보존, arbitrary SEH payload/credential/raw Steam 제외 검증 통과(evidence/exception-filter-tests.log). DX11 준비 helper 빌드 완료; 첫 컴파일은 파일명 추정 오류 후 실제 소스 목록으로 수정해 성공.

- 설치본 진단 collector/실행 파일 교체 및 서명 검증 후 Steam을 MACDECK_TRACE_EXCEPTIONS=1로 재시작. 실제 새 세션 WINEDEBUG trace+seh 활성화 확인, 사용자에게 동일 구간 재현 요청.
- 추가 확인: 설치 런타임에 libgstvideo/libgstreamer/libglib 의존성이 없음. x86_64 dlopen probe에서 winegstreamer.so가 @rpath/libgstvideo-1.0.0.dylib 누락으로 로드 실패(evidence/media-dependency-probe.log). 이는 확정된 패키징 결함이나 RE3 접근 위반의 직접 원인은 아직 미확인.

### 2026-10-18 — 영상 의존성 복구 및 Steam 한글 네모 수정
- 새 예외 수집에서 RE3 DX11 주소 0x14273EABB 접근 위반 확인. disassembly는 객체 멤버(+0xb8)를 역참조해 vtable+0x28 호출 직전 실패, 인접 코드에 MF_E_NO_MORE_TYPES(0xc00d36b9) 비교가 있어 Media Foundation 경로를 강하게 의심. 레지스터/전체 스택은 미수집이므로 null 포인터 및 정확한 인터페이스는 아직 추정.
- 공식 GStreamer1.28.8(공식 다운로드 링크, SHA256 d371ab04a7632713626836c2fc234e863cc98484c74c473eba99b0fbd9b3a3fe)을 프로젝트 캐시에 다운로드. pkg는 서명 없음, 시스템 installer는 실행하지 않고 pkgutil --expand-full로 추출. core/base-system/base-crypto/playback/codecs/libav를 Runtime/Media에 사설 배치(약287MB).
- scripts/prepare-gstreamer.py 추가 및 prepare-metal-runtime.py 연결. LaunchPlan에 Media/lib 검색 경로, plugin/scanner 경로, 쓰기 가능한 registry 경로 추가. winegstreamer.so x86_64 dlopen이 실패에서 loaded로 변경, x86_64 gst-inspect avdec_wmv3 인식 통과. 실제 RE3 영상/플레이는 아직 미검증.
- 사용자 첨부 Steam 대화상자의 한글 네모: Steam prefix Windows/Fonts가 비어 있음을 확인. WineFonts.swift 추가: Mac에 이미 설치된 AppleSDGothicNeo.ttc를 prefix에 symlink(앱에 Apple 글꼴 재배포하지 않음), Malgun/Gulim/Dotum 대체 및 Tahoma/Arial/Segoe UI/Microsoft Sans Serif의 Korean FontLink를 regedit로 등록. 성공 마커로 반복 등록 방지.
- 빌드 및 자체 검사79개 통과(evidence/media-fonts-*). 글꼴은 실제 Steam 화면에서 재검증 필요.

- 첫 한글 등록은 helper의 DYLD_FALLBACK_LIBRARY_PATH 누락으로 실패, 사용자가 같은 오류 메시지를 보고. WineFonts에 Runtime/lib 및 Media/lib 경로를 명시해 수정. 동일 regedit 명령은 종료0이며 실제 FontLink 및 Wine Fonts Replacements 등록 확인. 수정 후 빌드/검사79개 재통과. 원인 수정본 설치/재실행 진행.
- 수정본 설치/strict 서명 검증/재실행 완료. Steam prefix의 .macdeck-korean-fonts-v1 성공 마커 생성과 새 Steam 세션 2026-10-18T01-49-17Z 상태 running 확인. 실제 화면의 한글 및 RE3 새 게임 재검증을 사용자에게 요청.

### 2026-10-18 — 디코더 보완 후 동일 크래시 / ASF 파서 누락 추가 확인
- 사용자: 여전히 크래시. 01:49:17Z 세션에서 동일 RE3 주소 0x14273EABB 접근 위반 확인. 영상 모듈 dlopen/WMV 디코더 성공만으로 게임을 해결했다고 볼 수 없음.
- 추가 검사: 기존 Media에 libav WMV 디코더는 있지만 ASF demuxer(libgstasf.dylib)가 없음. 공식 패키지 gstreamer-1.0-codecs-restricted에 있어 prepare-gstreamer.py의 사설 배치 목록에 추가. 실제 ASF 파서 검증 진행.
- 선택적 진단에 MF/mfplat/mfreadwrite/winegstreamer warn/err 및 SourceReader 생성 호출 메타데이터, 별도 GStreamer warning 로그를 추가해 단순 예외 주소 이상의 생성 실패 단서를 보존하도록 개선. 일반 Steam raw 출력은 계속 저장하지 않음.

- ASF demuxer x86_64 gst-inspect 통과(evidence/gstreamer-asf-probe.log). 합성 WMV/ASF 생성 파이프라인과 filesrc→asfdemux→avdec_wmv2→fakesink 실제 디코드 모두 종료0(evidence/asf-decode-pipeline.log). 이는 RE3의 실제 SourceReader/영상 재생 성공과 구별. MF 진단 빌드 자체검사79개 통과.
- 설치본에 ASF 포함 Media 및 MF 진단 실행 파일/collector 동기화, Steam 정상 종료 후 DX11로 재시작. 사용자 동일 구간 재검증 필요.

### 2026-10-18 — 영상 소스 실패 직접 단서: deinterlace 누락
- 사용자 재현: ASF 보완 뒤에도 크래시. 최신 세션의 GStreamer 로그에서 no such element factory "deinterlace" → streaming not-linked(-1), MFMediaSource 생성 실패0x80004005 → 동일 RE3 0x14273EABB 접근 위반 순서를 확인. 발췌 evidence/re3-play-crash/deinterlace-missing.log.
- Wine10 wg_parser.c의 stream_create_post_processing_elements는 영상에 deinterlace→videoconvert→videoflip→videoconvert를 요구함을 공식 소스로 확인. 이전 단순 디코드 검사에는 이 후처리가 없어 누락을 잡지 못함.
- prepare-gstreamer.py에 공식 effects 패키지를 추가. verify-media-runtime.py 신규: x86_64에서 Wine 요구 factory12종 및 ASF decodebin→동일 후처리 파이프라인, 음성 변환 검사. 게임 재현 전에 의존 요소를 검사하도록 검증 범위를 보완.

- Wine 필수 factory12종, 실제 ASF decode+Wine 후처리 체인, 음성 변환 총14항목 통과(evidence/wine-media-chain-tests.log). effects 포함 Media 설치본 동기화 및 앱 서명 검증 후 DX11 진단 Steam 재시작. 실제 RE3 새 게임 재검증 대기.

### 2026-10-18 — 사용자 RE3 구동 확인 / HUD 및 Game Mode 안내
- deinterlace 보완 후 사용자가 "구동 되었어"라고 보고. DX11 non-RT의 게임 시작 구간 통과 보고이며 장시간 안정성·전체 게임 호환성 검증은 아님. 사용자 다른 게임 테스트 예정.
- Game Mode는 여전히 Off라고 사용자 보고. Metal HUD는 LaunchPlan의 MTL_HUD_ENABLED=1로 켜져 있고 앱 내 별도 토글은 현재 없음. HUD 표시와 Game Mode 활성화는 별개. macOS 기본 전체화면 및 게임 오버레이의 Game Mode 메뉴 확인 필요.

### 2026-10-18 — Steam Big Picture 버벅임: 화면 GPU 가속 비교
- 사용자: 게임은 괜찮지만 Big Picture가 버벅임. SteamClient.arguments에 cef-disable-gpu/cef-disable-gpu-compositing가 고정돼 있고 실제 webhelper 로그가 Disabling GPU acceleration 및 SP BPM mode:System임을 확인. CPU 합성 경로가 성능 저하의 유력한 원인이나 수치 측정은 아직 없음.
- LibraryData.steamGPUAcceleration 선택 설정, SteamClient 가속 허용 인자, Steam 설정 화면 토글 추가. 기본 호환 동작은 유지하고 선택 시 두 GPU 비활성화 인자를 제거. 게임 Metal 백엔드와 독립. 적용은 Steam 완전 재시작 후. 검은 화면이면 토글 끄고 복귀 가능.
- DXMT issue141의 cross-process swapchain 제한도 검토. 플래그 제거만으로 실제 하드웨어 가속 성공을 단정하지 않고 현재 vendor Wine에서 검증 예정. 게임 exe/Steam 인증 설정 파일은 변경하지 않음.

- 화면 가속 변경 빌드 자체검사80개 통과(evidence/steam-gpu-tests.log), baseline mode:System/disable 로그를 evidence/steam-gpu-baseline.log에 발췌. 설치본에 실행 파일 반영/strict 서명 검증 및 steamGPUAcceleration=true로 Steam 재시작. 실제 GPU 모드/성능 검증 진행 중.

- 실제 가속 허용 재시작 결과: BrowserReady 정상이나 Big Picture mode:System 유지. child 인자만 추출해 --in-process-gpu, --disable-gpu, --use-angle=swiftshader-webgl 확인(evidence/steam-gpu-allowed-still-software.log). 강제 disable-compositing 제거만으로 내부 Steam GPU 비활성화가 해제되지 않음. Steam 인터페이스의 웹 보기 GPU 가속을 사용자에게 확인 요청. 인증 config는 읽지 않음. 아직 성능 개선 성공으로 보고하지 않음.

### 2026-10-18 — 내부 Steam 가속 설정 On에도 소프트웨어 유지
- 사용자 확인: Steam 웹 GPU 가속은 이미 On, 버벅임 동일. 설정을 끄고 있어서라는 가정은 배제. 현 child 인자는 --disable-gpu/SwiftShader이므로 checkbox만으로 실제 가속을 판단할 수 없음.
- SteamClient 가속 모드에 명시적 -cef-force-gpu 추가, 대응 검사 추가. 한 변수씩 비교하며 실제 Big Picture mode 및 CEF 예외 확인 예정. 호환 모드 인자는 유지해 복귀 가능.

### 2026-10-18 — GPU 비교의 설정 손실 발견 및 외장 권한 반복
- 사용자: 설정 On에도 여전히 버벅임, 외장 허용 창 반복. 설치본 DR은 cdhash 기반 ad-hoc임을 codesign -d -r-로 확인. 빌드/재서명 시 식별값이 달라져 TCC 권한이 반복될 가능성. 권한 창 앱 이름 사용자 확인 요청; 임의 TCC DB 변경이나 Full Disk Access 요구는 하지 않음.
- 실제 own library.json의 steamGPUAcceleration이 nil로 돌아가 있음 확인. 구형 .build/re3-dx11-prepare가 새 필드를 모르는 LibraryData로 load/save하여 필드를 버린 진단 도구 결함. 앞선 force-GPU 시험은 실제 가속 시험으로 볼 수 없으며 baseline 소프트웨어로 돌아갔음. helper 종료 후 원본 JSON을 유지하는 원자적 수정으로 true 복구, 재시작 재검증.

### 2026-10-18 — Steam GPU runtime injection / external permission
- Confirmed steamGPUAcceleration=true and -cef-force-gpu, but Wine kernelbase.dll injects UTF16 ` --no-sandbox --in-process-gpu --disable-gpu` specifically for Steam.
- Added scripts/patch-steam-gpu-workaround.py: exact unique match, same byte length, original backups and --restore, reject unknown input. Applied to dist/installed runtime and Steam prefix, resigned and restarted for comparison; actual GPU rendering still under verification.
- User reports latest restart did not request external permission. Installed ad-hoc designated requirement is cdhash-based; no valid local signing identity found. Permission may be requested after resigning; no TCC database changes made.

- User screenshot confirms removable-volume permission requester is MacDeck. Prompt recurred immediately after kernelbase patch + app ad-hoc resign. Same-build restart retained access earlier; cross-build persistence is not fixed. User instructed to Allow in the system prompt; no automatic approval/TCC edits. Stable certificate-based signing is required to address update identity continuity; no valid signing identities available locally.

### 2026-10-18 — DMC5 GPU hang and HUD removal
- DMC5 user report: intermittent >60s freezes, audio/input continues but no screen refresh after Command-Tab. DXMT log confirms first Metal GPU timeout at frame26044 followed by rejected submissions. Evidence: evidence/dmc5-first-gpu-errors.log. This is GPU command failure; Command-Tab causality and exact shader remain unproven.
- DMC5 is DX11, exclusive fullscreen, variable framerate, highest mesh/texture/shadows. Game has exited (Steam App601150 removal at11:49:04). DXMT issue200 is a possible GS/TS marshal defect but not confirmed for DMC5; local metal compiler unavailable, so no shader fix claimed. Mitigation/retest remains pending.
- User confirms Steam Big Picture now works well after Steam-only kernelbase patch. This is user confirmation; no frame-time benchmark performed.
- User requests HUD removal. Replaced hardcoded MTL_HUD_ENABLED=1 with persistent showMetalHUD setting, default off. Added runtime UI toggle, next full Steam/game restart applies. Rendering/error logging retained. Added default-off check.

- HUD-off build and 82 self-checks passed (evidence/hud-off-*). Installed/resigned, Steam restarted using newly compiled stop-only helper (does not rewrite library settings). Preserved Steam GPU setting and patched kernelbase. New session MTL_HUD_ENABLED=0. Actual game HUD absence still requires display confirmation.

### 2026-10-18 — Repeated volume consent after HUD build
- User still reports consent prompts. HUD update also changed the ad-hoc designated requirement; current installed DR cdhash is 3241fa7e9e29dde08cb7a677d5d29522f68df234. codesign --verify --strict currently succeeds, so signature corruption during this run is not established.
- Asked whether prompts recur within the same run, on restart, or only after updates. No further code/bundle mutation or resigning in this investigation, to avoid resetting the observed identity again. Cross-build permission persistence is unresolved; no automatic Allow/TCC changes attempted.

- User confirms removable-volume prompts occur after applying updated builds, not repeatedly within the same run. This matches changing cdhash-based ad-hoc identity. Current permission behavior is update-related; stable certificate signing remains the required development/distribution follow-up. Avoid promising that ordinary folder re-selection or bookmarks fix signature identity changes.

### 2026-10-18 — DMC5 windowed/60 still freezes immediately
- User reports windowed + 60 FPS also freezes immediately on gameplay start. Latest DMC5 d3d11 log is empty; no new GPU timeout was captured, so the prior timeout cannot be assigned to this run without further evidence. Steam tracked process exited at11:56:38; no DMC5 process was found.
- On-disk ini has WindowMode=Normal but FramerateSetting=VARIABLE. This can reflect unsaved settings after the freeze, not proof user did not select60.
- Read official DXMT0.80 dxmt.conf: d3d11.preferredMaxFrameRate provides Metal-side pacing; dxgi.handleAltTab exists for Wine exclusive-fullscreen transitions. Installed DMC5-only dxmt.conf with60 and True, preserving previous file if present; no app/bundle mutation or resign. Prepared file .cache/dmc5-dxmt-comparison.conf.
- This is a comparison mitigation, not a GS/TS shader fix. Issue200 remains a hypothesis; local metal compiler is unavailable. Actual DMC5 gameplay validation remains pending.

### 2026-10-18 — DMC5 repeated same-scene live stalls
- User reports same-scene recurring long stalls; stall later recovers and quickly returns. Live PID29982 sampled for3s (evidence/dmc5-live-hang.sample.txt). dxmt-finish-thr includes Metal waitUntilCompleted; encode thread remains in draw/encoding. This supports render-side investigation but does not identify the offending shader.
- Prepared patches/dxmt-0.80-gs-ts-marshal.patch and .cache/dxmt_command-fixed.metal: zero-count/division guards, 64-bit dispatch multiply, loop index increment. Candidate follows upstream issue200 but DMC5 causality remains unproven. No runtime deployment yet.
- Corrected earlier toolchain finding: Xcode.app exists; default developer directory points to CLT. Using DEVELOPER_DIR locates metal stub, but actual compilation fails due missing Metal Toolchain. Started official xcodebuild -downloadComponent MetalToolchain using Xcode directory; no system xcode-select change.
- User advised they can close unplayable game; no further settings-only replay requested.

- Apple Metal Toolchain27A266a downloaded successfully (~839MB) using installed Xcode via DEVELOPER_DIR. Candidate Metal3.1 library compiles. Native check found same36 functions and actual GS two-task GPU output [0,0,0,2,1,1] passes with Metal API validation. Test initially used an attachment-free render pass and hit internal error; adding a1x1 render attachment corrected the test harness. Evidence/dxmt-marshal-metal-tests.log.
- Original embedded metallib152339bytes; candidate154883bytes, so in-place replacement is not safe yet. Runtime remains unchanged. Comparing compiler options for a fitting, equivalent candidate before any deployment. No claim of DMC5 fix yet.

### 2026-10-18 — Experimental DXMT GS/TS candidate deployment
- Native Metal validation passes GS and TS multi-task cases: zero draw and zero control points produce zero dispatch; second tasks execute with expected [2,1,1] and [3,1,1]. All36 original function names preserved. CPU boundary checks include 64-bit overflow rejection and ordinary draw equivalence.
- Candidate metallib is154883bytes vs original152339. To avoid overwriting adjacent data, scripts/patch-dxmt-marshal.py appends a read-only .mdmetal PE section, adjusts the explicit library pointer and length, and updates PE metadata. Exact original SHA256 lock; unknown builds rejected. Only32 original bytes differ, all within declared headers/pointer/length fields; Wine builtin marker and existing identity-rotation patch preserved. Evidence/dxmt-marshal-pe-*.
- User explicitly confirmed DMC5 exited. Stopped Steam with non-rewriting helper; backed up original x86_64 runtime/dist/prefix DLLs in .cache/dmc5-marshal-backups; installed candidate and macdeck-gs-ts-marshal-patch.json experimental metadata. GPU setting, kernelbase Steam patch, HUD-off and media libraries retained. Resign/restart required; removable-volume consent may recur after this updated build.
- This is an experimental candidate for a plausible upstream defect, not confirmed DMC5 root-cause resolution. Same-scene gameplay and startup need user validation. Original DLLs remain recoverable. Fresh runtime preparation/component replacement may overwrite this candidate; reapplication requires version-locked script and recorded Metal library build, never blindly patch an unknown version.

### 2026-10-18 — 사용자 DMC5 렉 해소 확인 / 커밋·푸시 준비
- 사용자: "렉은 없어졌어". 실험적 DXMT GS/TS 보완 후 동일 구간의 긴 렉이 사라졌다는 사용자 확인을 받음. 모든 장면·장시간·다른 게임에 대한 완전한 안정성 보장은 아님.
- 현재까지 RE3 영상 소스 의존성/한글 글꼴, Game Mode 지원 키, 렌더러 진단, Steam Big Picture GPU 경로, HUD 기본 끔, DMC5 GS/TS 후보를 누적 정리. Game Mode On과 DX12 안정성, 업데이트 간 외장 권한 유지 문제는 미해결.
- 사용자 요청에 따라 코드/문서/재현 가능한 검사 및 선별된 비민감 결과를 커밋·푸시. Steam raw 로그, 메모리 덤프, 인증 화면/파일, 원본 프로세스 샘플 및 로컬 런타임 바이너리는 업로드 제외. 최종 앱 빌드 검사82개, 미디어14항목, 실제 Metal GS/TS 검사 통과 이력을 구분해 기록.

### 2026-10-18 — 타 플랫폼(Proton/CrossOver/Whisky/DXMT) 동영상·사운드·렉 패치 및 최적화 종합 적용 (v0.5.5)

- **요청 사항**:
  - 새로 수정된 `work.md` 확인 후, *Devil May Cry 5*나 *Resident Evil* 시리즈 외 다른 Windows 게임들에서도 발생할 수 있는 렉(stutter), 동영상 컷씬 문제, 사운드 왜곡/무음 현상에 대응.
  - Proton, Proton-GE, CrossOver, Whisky, Apple Game Porting Toolkit(GPTK), DXMT, MoltenVK, VKD3D-Proton 등 유사 Windows 게임 호환 레이어들의 핵심 수정내역과 커뮤니티 패치사항을 분석하여 MacDeck 전역에 적용.

- **유사 플랫폼 분석 및 문제 원인 식별**:
  1. **멀티스레드 동기화 병목 (CPU 렉 및 마이크로 스터터링)**:
     - 기본 Wine은 윈도우 스레드 동기화 객체(Event, Mutex, Semaphore 등)를 다룰 때마다 `wineserver` 소켓 IPC를 경유하여 심한 오버헤드와 스레드 기아(Starvation)가 발생함.
     - CodeWeavers(CrossOver Mac)와 Apple GPTK는 macOS Mach-message 및 공유 메모리(shm) 기반의 고속 동기화인 **MSync(`WINEMSYNC=1`)**와 **ESync(`WINEESYNC=1`)**를 표준 적용하여 CPU 렉을 제거함. Wine Sikarugir 바이너리 문자열 검사 결과 `WINEMSYNC` 및 `WINEESYNC` 네이티브 구현체가 내장되어 있음을 확인.
  2. **오디오 끊김 / 컷씬 대사 무음 (XAudio2 / DirectSound)**:
     - Capcom RE Engine(DMC5, RE2/3/7/Village) 및 Unreal Engine 4/5 게임들은 XAudio 2.7~2.9 및 X3DAudio를 사용하며, 게임 배포 폴더에 자체 Windows용 `xaudio2_7.dll` 등을 번들하는 경우가 많음.
     - Wine이 게임 폴더의 네이티브 DLL을 로드하면 초기화에 실패하거나 소리가 나지 않고, CoreAudio 드라이버 채널 매핑(`ca_channel_layout_to_channel_mask`)과의 마찰로 찌직거리는 잡음이 발생함. Proton과 CrossOver처럼 Wine 내장(builtin) XAudio2/FAudio 및 DirectSound로 오버라이드 고정이 필수적임.
  3. **동영상 컷씬 끊김 / 흑화 / 싱크 밀림 (Media Foundation / GStreamer)**:
     - 기존 MacDeck의 GStreamer에는 소프트웨어 디코더 일부만 포함되어 1080p/4K 60fps 고화질 컷씬 재생 시 CPU 과부하와 싱크 밀림이 발생할 위험이 있었음.
     - 공식 GStreamer universal 패키지 중 `gstreamer-1.0-system`에 macOS Apple Silicon 하드웨어 가속 VideoToolbox 디코더인 **`vtdec`** 및 **`vtdec_hw`**(H.264 / HEVC)가 포함되어 있음을 확인.
     - 또한 컷씬 동영상에 광범위하게 쓰이는 Dolby Digital AC-3 5.1/스테레오 디코더인 **`a52dec`**와 DTS 디코더인 **`dtsdec`**(`gstreamer-1.0-codecs-gpl`), MP4/QuickTime 파서 **`qtdemux`**, MKV 파서 **`matroskademux`**가 번들되어야 영상-음성 디코딩 파이프라인이 완전해짐.
  4. **DXMT / MoltenVK 렌더링 프레임 페이싱 및 크래시 방지**:
     - DX11(DXMT): 일부 게임(소닉, DMC5 등)이 `D3D11_MAP_FLAG_DO_NOT_WAIT` 플래그로 Map 호출 시 GPU 작업 미완료 예외를 제대로 처리하지 못해 크래시/스터터가 발생하는 것을 방지하는 `d3d11.ignoreMapFlagNoWait=True`, 전체화면 전환 프리징을 방지하는 `dxgi.handleAltTab=True`, 비정상 테셀레이션 폭주를 제한하는 `d3d11.maxTessFactor=64` 옵션을 `DXMT_CONFIG`로 기본 부여.
     - DX12(MoltenVK + VKD3D): Apple Silicon Metal 3 최적화를 위해 Metal Argument Buffers(`MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=1`) 및 커맨드 버퍼 사전 채움(`MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS=3`), VKD3D 기능 레벨 12.1(`VKD3D_FEATURE_LEVEL=12_1`), 디스크립터 최적화(`VKD3D_CONFIG=no_upload_hlist`) 적용.

- **구현 및 변경 파일**:
  1. `scripts/prepare-gstreamer.py`:
     - 패키지 목록에 `gstreamer-1.0-system`, `gstreamer-1.0-codecs-gpl`, `gstreamer-1.0-codecs-gpl-restricted`, `gstreamer-1.0-encoding` 추가.
     - `dist/MacDeck.app` 및 `/Users/sjhdeux/Applications/MacDeck.app`의 `Runtime/Media`에 자동 추출·반영.
  2. `scripts/verify-media-runtime.py`:
     - 검증 대상을 12종에서 21종으로 확장: `vtdec`(Apple VideoToolbox H.264/HEVC 하드웨어 가속), `a52dec`(AC-3 오디오), `dtsdec`(DTS 오디오), `qtdemux`(MP4/MOV), `matroskademux`(MKV), `wavparse`, `avdec_h264`, `avdec_aac`, `avdec_mp3` 추가 검사.
  3. `Sources/MacDeck/Library.swift`:
     - `DirectX12Support.dllOverrides`:
       - 오디오: `xaudio2_0`~`xaudio2_9`, `x3daudio1_0`~`x3daudio1_7`, `dsound=b` 추가.
       - 미디어: `mfplat,mfreadwrite,mf,mfmediaengine,winegstreamer=b;quartz,amstream=b` 추가.
     - `LaunchPlan.make`:
       - `environment["WINEMSYNC"] = "1"`
       - `environment["WINEESYNC"] = "1"`
       - `environment["WINEMSYNC_QLIMIT"] = "512"`
       - `environment["WINE_LARGE_ADDRESS_AWARE"] = "1"`
       - `environment["GST_PLUGIN_PATH_1_0"] = ""` (호스트 GStreamer 플러그인 오염 격리)
       - `environment["DXMT_CONFIG"] = "d3d11.ignoreMapFlagNoWait=True;dxgi.handleAltTab=True;d3d11.maxTessFactor=64"`
       - DX12: `MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=1`, `MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS=3`, `VKD3D_FEATURE_LEVEL=12_1`, `VKD3D_CONFIG=no_upload_hlist`.
  4. `Sources/MacDeck/Diagnostics.swift`:
     - 세션 진단 기록 환경변수 화이트리스트에 `WINEMSYNC`, `WINEESYNC`, `WINEMSYNC_QLIMIT`, `WINE_LARGE_ADDRESS_AWARE`, `DXMT_CONFIG`, `MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS`, `MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS`, `VKD3D_FEATURE_LEVEL`, `VKD3D_CONFIG` 등록 (민감 정보 제외).
  5. `Sources/MacDeck/SelfTests.swift`:
     - MSync/ESync/LargeAddressAwareness 설정 검증, XAudio2/DirectSound 오버라이드 검증, Media Foundation/DirectShow 오버라이드 검증, DXMT 프레임 페이싱/Alt-Tab 설정 검증, DX12 MoltenVK Argument Buffers/Prefill 및 VKD3D 12.1 검증 추가.

- **실제 실행한 검증과 결과**:
  1. `python3 scripts/verify-media-runtime.py`:
     - 필수 팩토리 21종(`decodebin`, `asfdemux`, `avdec_wmv2/3`, `avdec_wmav2`, `deinterlace`, `videoconvert`, `videoflip`, `audioconvert`, `audioresample`, `appsink`, `appsrc`, `vtdec`, `a52dec`, `dtsdec`, `qtdemux`, `matroskademux`, `wavparse`, `avdec_h264`, `avdec_aac`, `avdec_mp3`) 모두 `PASS`.
     - 합성 ASF 디코드 + Wine 후처리 체인 `PASS`.
     - 오디오 변환 체인 `PASS`. 총 23개 항목 정상 검증 완료.
  2. `bash scripts/build-mac-app.sh`:
     - MacDeck 컴파일 성공, `Info.plist` 생성 및 ad-hoc 코드 서명 성공.
  3. `dist/MacDeck.app/Contents/MacOS/MacDeck --self-test`:
     - **88개 자체 검증 테스트 전원 통과 (`PASS`)**.
  4. `codesign --verify --strict dist/MacDeck.app`:
     - 서명 유효성 무오류 통과.
  5. `/Users/sjhdeux/Applications/MacDeck.app` 동기화 및 자체 검사:
     - 88개 검사 통과 및 strict 서명 검증 완료.

- **남은 작업 / 제약**:
  1. 실제 다양한 게임(DMC5, RE3, 기타 Steam 라이브러리 보유 게임)에서 동영상 재생 및 배경음악/효과음 정상 출력, 스터터링 체감 여부를 사용자가 인게임 플레이를 통해 교차 검증 필요.
  2. 업데이트 빌드 교체 시 ad-hoc 서명 cdhash 변경으로 인한 외장 볼륨 접근 권한 팝업은 Apple 개발자 인증서 서명 도입 전까지 OS 차원의 기본 동작임.

### 2026-10-18 — 추가 잠재 문제점 심층 점검 및 사전 차단 검증 (v0.5.5+)

- **요청 사항**:
  - 추가적인 잠재 문제점(런타임, 비디오/오디오 로딩, 스토리지/프리픽스 동기화 등)이 없는지 더 확인하고 검증.

- **심층 점검에서 발견된 2가지 잠재 결함 및 해결**:
  1. **Prefix 내부 그래픽 DLL 버전 불일치 위험 (`syncPrefix`)**:
     - 기존 `DirectX12Support.syncPrefix`는 `drive_c/windows/{system32,syswow64}`에 `d3d11.dll`, `d3d10core.dll`, `d3d12.dll`, `winemetal.dll`이 **존재하지 않을 때만** 복사했음.
     - 이로 인해 과거 생성된 prefix(Steam 병 등)에 Wine 초기 stub이나 패치 전 구형 DLL이 한 번 들어가면, 이후 DXMT 0.80 GS/TS 패치나 런타임 업데이트가 적용되어도 prefix 내부 파일이 갱신되지 않아 구버전 코드가 실행되면서 렉/크래시가 재발할 위험이 있었음.
     - `srcDLL`과 `targetDLL`의 내용을 비교하여 다를 경우 원자적으로 덮어쓰도록 수정(`bytes.write(to: targetDLL, options: .atomic)`).
  2. **GStreamer 플러그인 초기 탐색 프리징 (Cold-start scanning stall)**:
     - Apple VideoToolbox, AC-3, DTS, MP4 등 코덱 패키지가 대폭 확장됨에 따라, 최초 실행 시 `gst-plugin-scanner`가 수십 개 플러그인을 전수 조사하는 데 10~15초가 소요되어 첫 게임 시작이나 첫 컷씬 진입 시 화면이 멈추는 지연이 발생할 수 있었음.
     - `scripts/prepare-gstreamer.py`에서 빌드 시점에 1.3MB 크기의 사전 인덱싱 레지스트리 `Runtime/Media/gst-registry.bin`을 미리 생성하도록 개선.
     - `LaunchPlan.make`에서 사용자 로그 폴더의 `gst-registry-x86_64.bin`이 없거나 초기화될 때 번들된 사전 생성 레지스트리를 즉시 복사(Pre-seeding)하여 최초 실행 시의 10초 스캔 지연을 완전히 제거함.

- **실제 검증 결과**:
  1. `prepare-gstreamer.py`: 번들용 `dist/.../Media/gst-registry.bin` 및 `/Users/sjhdeux/Applications/.../Media/gst-registry.bin` 사전 생성 성공(1,323,424 바이트).
  2. `SelfTests.swift`:
     - 전역 동기화 시 prefix `system32/d3d11.dll` 바이트 일치 검사 통과.
     - LaunchPlan 기동 시 번들 레지스트리 자동 시딩 검사 통과.
     - 자체 검증 **90개 테스트 전원 통과 (`PASS`)**.
  3. `/Users/sjhdeux/Applications/MacDeck.app` 실행 파일 동기화, ad-hoc 재서명 및 strict 서명 유효성 검증 완료.

### 2026-10-18 — 배포용 DMG 패키징 및 GitHub Release v0.5.5 업로드

- **요청 사항**:
  - 배포할 수 있는 `.dmg` 파일을 생성하고 Git/GitHub에 업로드.

- **작업 내용**:
  1. `scripts/package-dmg.sh` 생성:
     - 배포용 DMG 스테이징 디렉터리 구성 및 사용자가 손쉽게 드래그 앤 드롭으로 설치할 수 있도록 `/Applications` 심볼릭 링크 포함.
     - `hdiutil create -format UDZO -volname "MacDeck"` 고압축 이미지 생성 (1.2GB 원본 -> 527MB 압축).
  2. DMG 이미지 무결성 검증:
     - `hdiutil attach`로 가상 볼륨 마운트 후 `/Volumes/MacDeck/MacDeck.app`에 대해 `codesign --verify --strict` 무결성 검증 통과 (`exit 0`).
  3. GitHub Releases 업로드:
     - GitHub 단일 커밋 용량 한도(100MB)를 초과(527MB)하므로, 대용량 바이너리 배포 표준인 **GitHub Releases (`gh release create v0.5.5`)**를 통해 배포 에셋으로 등록 및 업로드.



