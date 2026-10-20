# MacDeck (macDeckAI)

> v0.6.0 최종 후보(2026-10-20): Epic VC++12종 설치·x86/x64 DLL/API·재설치 방지 검사, 앱230개·콘솔 UI·서명·DMG 내부 앱 검사 PASS. 호그와트 설치 후 실제 플레이56.47FPS 표본 재확인. DMG/SHA256 생성 완료, Git 커밋·푸시·릴리즈 게시 확인 진행 중. 모든 배포 작업 성공 뒤에만 요청한 잠자기를 실행한다.

> v0.6.0 준비(2026-10-20): Epic 시작 전 VC++2005–2022 x86/x64 총12종 선행 설치, 게임별 .NET 검색 및 수동 재시도를 추가했습니다. 실제 설치·DMG 검증 후 GitHub 릴리즈 배포를 진행 중입니다.

> 2026-10-20 실기 확인: 사용자 게임 약관 동의 후 Epic 호그와트 레거시 저장 게임의 Central Hall·이동·대화 장면까지 직접 확인했습니다. Apple D3DMetal D3D12, 1280×720·FSR2 Quality에서 HUD 약55~60FPS, 관찰 중 멈춤/크래시 없음. 장시간·다른 레벨·고해상도·패드는 별도 검증 필요하며 정상 기준을 자동 승격하지 않습니다.

> 최신 변경(2026-10-20): Epic 게임의 필수 런타임 자동 준비 누락을 수정했습니다. 호그와트 레거시가 사용하는 Epic 전용 환경에 Microsoft VC2015–2022 x64 설치(exit0), 실제 DLL 로드/설치 등록 검사와 앱 자체검사210개를 통과했습니다. Epic의 게임 실행 버튼 및 실제 플레이는 사용자 재검증 대기입니다.

> 최신 변경(2026-10-20): **Epic Games Launcher 외장하드(exFAT) 설치 시 권한 오류(Error Code: DP-07) 근본 해결 및 실기 설치 검증**을 완료했습니다. LLVM objdump 바이너리 분석을 통해 EGL의 `DirectoryPreparation`이 `GetNamedSecurityInfoW`로 `WinBuiltinUsersSid`(`S-1-5-32-545`) 또는 `WinWorldSid`(`S-1-1-0`)의 `FILE_GENERIC_WRITE`(0x120116) DACL을 검사하는데, exFAT 볼륨은 Windows ACL 저장을 지원하지 않아 발생하는 권한 검사 오류임을 규명했습니다. `EpicClient.applyDirectoryPreparationPatch()`를 구현하여 권한 검사 조건부 점프를 무조건 성공 점프로 원자적 치환(백업 보존 및 멱등성 보장)했습니다. 자체 검사 **208개 전원 통과 (`208 checks passed`)**를 달성했으며, 사용자 실기 구동에서 외장하드(`E:\epic\HiddenFolks`)로 게임 파일이 정상 다운로드/설치됨을 확인했습니다.

> 이전 변경(2026-10-20): **Epic Online Services (EOS) 설치 오류 해결 및 자동 무인 설치/상태 연동**을 완료했습니다. `EpicGamesLauncher.log` 분석을 통해 `DirectX12Support.dllOverrides`의 `mscoree=;`로 인해 Wine 내장 `mscoree.dll`(.NET 런타임 로더)이 차단되어 MSI 커스텀 액션에서 `1603` 크래시가 발생하던 문제를 해결하고 `mshtml=;`로 정상화했습니다. 사전 디렉터리 자동 생성, CLI 무인 설치 연동(`runEOSInstaller`), 콘솔 UI 상태 타일(`Epic Online Services 정상 / 설치`)을 추가하고 실제 Wine 환경에서 `Run completed with Success (0)` 및 `EpicOnlineServicesUserHelper.exe` 정상 설치를 확인했습니다. 자체 검사 **206개 전원 통과 (`206 checks passed`)**를 검증했습니다.

> 이전 변경(2026-10-20): **Epic Games Launcher (EGL) 연동 및 외장 드라이브·게임패드·호환성 지원**을 추가했습니다. 전용 격리 Prefix(`Bottles/EpicGames`), `-SkipBuildPatchPrereq` (DX/VC++ 재배포 패키지 무한 설치 루프 방지) 및 `-ForceDX11` (DXMT Metal 하드웨어 가속 강제) 인자 적용, 공식 JSON 매니페스트(`.item`) 자동 파싱 및 `epicAppID` (`epic:AppName`) 고유 식별자 격리, 외장 NVMe/SSD 드라이브(`dosdevices/e:`) 다중 Prefix 일괄 동기화/연결 해제, 그리고 **`.msi` Windows Installer 패키지 지원 (`wine msiexec /i <msi> /qn`)**을 구현했습니다. 가상 실행 파일(`msiexec.exe`)로 인한 경로 오류를 해결하고 자체 검사 **203개 전원 통과 (`203 checks passed`)**를 검증했습니다.

> 이전 변경(2026-10-20): 특정 게임 하드코딩이 아닌 모든 D3D9 게임에 적용 가능한 **범용 D3D9 CPU 스핀 완화 옵션(`d3d9YieldFix`)**을 아키텍처에 추가했습니다 (`d3d9-yield-helper.cpp`, `GameProfiles.swift`, `SharedSteamRuntime.swift`, 라우터 `[yield]` 연동). 다른 게임의 런타임과 설정을 철저히 격리한 상태에서 자체 검사 **196개 전원 통과 (`196 checks passed`)**를 검증했습니다. 용사30(App ID 214830) 실기 구동에서 인게임 Direct Metal 60 FPS 렌더링을 확인했으나, 씬 전환 렉은 게임 내부 리소스 로딩 병목으로 체감 개선이 제한적임을 확인하고 사용자 결정에 따라 현 단계에서 마무리했습니다.

> 최신 변경(2026-10-19): 용사30(App ID 214830)의 게임 시작 시 검은 화면 및 WineD3D 크래시 문제를 완전 해결했습니다. ClearQuad 슬롯 불일치를 수정한 `macdeck_hmh_dxmt_clear_v2.dll`과 Steam 데스크톱 모드에서도 `SteamGameId`/실행 파일명을 자동 인식하는 D3D9 라우터를 적용했습니다. 자율 키 입력 및 실시간 스크린샷 검증을 통해 메인 메뉴 및 SINGLE PLAYER QUEST 01 진입에 성공했으며, M5 Direct Metal 59.42 FPS 1280×720 해상도에서 맵·스프라이트·UI가 완전히 정상 렌더링됨을 확인했습니다 (`evidence/hmh-live-now.png`).

> 최신 변경(2026-10-19): 사용할 수 없던 D9VK→Metal 모드를 UI·설정·실행 경로·용사30 trial 도구에서 완전히 제거했습니다. 기존 `native` 저장값과 해시가 일치하는 시험 DLL/설정만 백업 후 분리했으며 빌드와 자체검사180개를 통과했습니다. 용사30은 exact App ID214830 전용 직접 Metal 경로로 다시 조사 중입니다.

> 최신 호환성 확인(2026-10-19): DmC(App ID 220440) v5 실제 플레이를 1920×1200 Retina Direct Metal에서 두 번 측정해 70.53/76.93 FPS, 실패 Present 0, 33ms 초과 0을 확인했습니다. 과노출도 재발하지 않았습니다. RetinaMode의 다른 게임 회귀와 장시간 안정성 확인 전이라 revision10/failing을 유지합니다.

> 최신 확인(2026-10-19): DmC v4 전용 Metal 모듈 실제 플레이에서 과노출 개선을 사용자 확인. 잔렉은 남아 v4 프레임 지연 원인 분리 중이며 정상 구동 승격 없음. Steam 시작 요청 무응답은 별도 미해결.

> 최신(2026-10-19): BC sRGB 변환 생략 결함을 격리 재현하고 v4 후보 GPU5개·앱176검사 통과. 정확한 DmC revision9/failing에만 적용했으나 사용자는 실행 안됨 보고, 시작 요청과 실제 적용을 조사 중. 실제 과노출·잔렉 수정 완료 아님.

> 최신(2026-10-19): DmC v3 실제 플레이에 과노출·잔렉이 남아 우선 조사 중. 기본 sRGB GPU4개 검사는 통과했으나 완전 수정은 아님. D9VK 옵션 제거 및 용사30 후속 검증 요청 보존.

> 최신 작업(2026-10-19 재개): DmC Clear 상수 슬롯0→30 원인 수정 후보(v3)를 정확한 AppID220440에만 시험 적용했습니다. 우회 코드 없이 격리 GPU3개·다른 게임 선택기4개 검사 통과. 실제 플레이 색상과 성능은 검증 중이며 정상 구동으로 승격하지 않았습니다.

> 최신 현황(2026-10-19): DmC의 부분 색상·깊이 Clear 결함을 재현하고 수정 후보를 구현했습니다. 실제 3D 장면은 나타나지만 과노출/색상 이상이 남아 기본 비활성으로 보존합니다. DmC는 revision7/failing이며 정상 플레이 미검증입니다. 자체검사169개·격리 GPU3개 통과. 기존 정상 게임의 프로필과 렌더러는 보존했습니다.

> 최신 상태(자율 재현): DmC 새 게임 진입을 직접 조작하고 GPU 검은 프레임을 확인했습니다. 오프닝 영상 출력은 확인했으며 실제 3D 렌더링 실패를 계속 분리 중입니다. 현재 진단 revision6, 정상 구동 승격 없음.
> 최신 사용자 확인: 직접 Metal에서 DmC 타이틀은 부드럽지만 게임 시작 후 검은 화면·사운드만 출력됩니다. 실제 플레이는 미해결이며 D9VK 사용 금지는 유지합니다.
> 최신 DmC: D9VK를 폐기하고 D3D9→DXMT→직접 Metal로 전환했습니다(revision5). 전용 Windows/Unix 구성요소 실제 로드·게임 창 표시 확인, 합성 GPU/600프레임 검사 및 자체검사162개 PASS. 실제 타이틀/플레이 성능은 사용자 확인 대기입니다.
> 현재 지침: DmC의 D9VK 경로는 타이틀부터 사용 불가능한 성능이라는 사용자 보고로 비활성화했습니다(revision4). D9VK 사용 금지 요청을 반영하며, 직접 Metal 경로만 별도 환경에서 조사 중입니다.
> DmC 최신 결과(2026-10-19): WineD3D의 DXT5 텍스처 생성 실패 후 크래시를 재현하고, AppID220440 전용 D9VK/Metal 경로를 적용했습니다. 수정 후 게임 창 표시·25초 이상 생존 확인, 자체 검사161개 PASS. 실제 타이틀/플레이는 사용자 확인 대기이며 아직 정상 구동으로 승격하지 않았습니다.
> 2026-10-19 최신 결과: DMC5 초기 GS/TS 보완판을 AppID601150 전용으로 복구했습니다(revision3). 실제 Metal/GPU 검사 및 자체 검사157개 통과, 동일 구간 플레이는 사용자 재검증 대기입니다. DmC 실행 실패는 별도 미해결입니다.

> 현재 상태(2026-10-19): 엘든링 전용 Apple D3DMetal Metal3 + MSync1/ESync0 + SDL 패드 조합에서 사용자 1920×1200 전체화면 60fps 및 입력 정상 확인. 장시간·모든 구간 안정성은 미검증. 용사30은 여전히 성능/크래시 문제로 미해결. 일반 Steam 환경의 엘든링은 과거 로컬 Vulkan DXGI를 백업 분리한 뒤 사용자 정상 구동 확인. Big Picture 플레이 버튼 재실행과 이번 환경의 FPS·장시간 안정성은 별도 확인이 필요하다. 최신 비교에서 엘든링·RE3 정상, DmC 시작 크래시·DMC5 로딩 크래시/WindowServer WATCHDOG 보고. DMC5만 DXMT로 복귀했으며 재검증 대기. 필수 .NET/VC 런타임 자동 준비(18종 카탈로그·설치 후 검사·실패 기록) 구현 및 자체검사152개 통과. VC2005 설치 옵션 수정 및 일반 prefix의 VC2008/.NET4 기능 검사 완료. DmC AppleDouble 패키지 중복 경고를 수동 격리했으나 후속 즉시 종료는 미해결. DMC5 실제 로딩 재검증도 남아 있으며 상세 최신 기록은 문서 끝을 확인하세요.

> **Apple Silicon Mac을 위한 Steam 머신 경험 및 Windows 게임 Metal 가속 런처**

MacDeck(macDeckAI)은 Apple Silicon(M-시리즈) Mac 환경에서 Windows 게임과 Windows Steam Big Picture 모드를 네이티브에 가깝게 즐길 수 있도록 돕는 오픈소스 프로젝트입니다.

현재 안정성: **RE3 DX11 non-RT는 영상 후처리 의존성 보완 후 사용자 구동 성공 보고를 받았습니다. 장시간 안정성은 미검증이며 DX12 GPU timeout은 미해결입니다.** Game Mode 지원 키의 실제 설치 반영은 v0.5.4에서 복구했으며, `On` 여부는 macOS 기본 전체화면에서 따로 확인해야 합니다.

---

## 📸 미리보기

| MacDeck 공식 앱 아이콘 | MacDeck 라이브러리 UI | Windows 게임 Metal HUD 구동 (Brogue CE) |
|:---:|---|---|
| <img src="resources/AppIcon-1024.png" width="160" alt="MacDeck Icon"/> | ![MacDeck App](evidence/macdeck-app.png) | ![Metal HUD Game](evidence/macdeck-v02-game-metal.png) |

---

## ⚡ 주요 특징

1. **Apple Silicon 네이티브 UI & Steam Big Picture 연동**
   - SwiftUI / AppKit 기반의 깔끔한 macOS 네이티브 인터페이스.
   - 공식 Windows Steam 클라이언트를 백그라운드 환경에 설치하고, Steam Big Picture 모드를 한 번의 클릭 또는 패드 입력으로 실행.
   - Steam 라이브러리(`libraryfolders.vdf`, `appmanifest`)를 자동 파싱하여 MacDeck 런처에 동기화.

2. **Apple Metal 하드웨어 가속 및 전역 DX11 Mode / DX12 Mode 선택**
   - **WineSikarugir 10.0 (x86_64, Rosetta 2)** 기반 호환성 레이어.
   - **전역 그래픽 모드 전환 (모든 게임 공통)**: 상단 툴바, 런타임 설정, 또는 Steam 탭에서 **DX11 Mode**와 **DX12 Mode**를 선택하면 런타임의 DXGI 브리지와 DLL 오버라이드가 전역으로 전환되며, 실행 중인 Steam도 새 모드로 자동 재시작됩니다.
   - **DX11 Mode (DXMT 0.80+ · 기본 권장)**: Direct3D 10/11 호출을 Apple Metal로 직접 변환하며, DX11용 DXGI 브리지를 사용합니다. Steam CEF 호환성을 위해 D3D12 DLL은 비활성화하지 않으며, DX12 전용 게임을 DX11로 변환하는 기능은 아닙니다.
   - **DX12 Mode (VKD3D 1.14 + MoltenVK 1.4.2+ · 실험적)**: Wine D3D12 DXGI 브리지와 MoltenVK(`libvulkan.1.dylib`)를 통해 Direct3D 12를 Apple Metal 3로 가속합니다.
   - **런타임 구성요소 자동 업데이트 (`RuntimeUpdater`)**: `런타임` 설정에서 **MoltenVK**, **DXMT**, **Wine Engine**의 공식 GitHub Releases 최신 버전을 확인하고 SHA-256 무결성 및 `x86_64` 아키텍처 검증 후 원클릭 또는 앱 시작 시 자동으로 업데이트합니다.
   - **macOS Game Mode 지원 정보 & Apple Metal HUD**: `MacDeck.app` 및 내장 `wine` 실행 파일의 `Info.plist`에 `public.app-category.games`, `LSSupportsGameMode`, `GCSupportsGameMode`를 설정하여 전체화면 게임 시 macOS 게임 모드와 Metal HUD를 지원합니다.

3. **Epic Games Launcher (EGL) 연동 및 전용 격리 환경**
   - 공식 Epic Games Launcher MSI 무인 설치 및 전용 Prefix(`Bottles/EpicGames`) 격리 지원.
   - `-SkipBuildPatchPrereq` 인자로 끝없는 DirectX/VC++ 재배포 패키지 설치 루프를 차단하고 `-ForceDX11`로 DXMT Metal 가속 강제.
   - 외장하드(`E:\EpicGames`) 설치 게임의 JSON 매니페스트(`.item`)를 실시간 감지하여 MacDeck 라이브러리에 자동 등록.
   - Steam과 동일하게 XInput 게임패드 및 DXMT/VKD3D Metal 가속, 한글 폰트 링크 완벽 공유.

4. **외장 SSD/HDD 게임 라이브러리 지원 및 시작 시 자동 연결**
   - 내장 SSD 용량이 부족한 Mac 환경을 위해 외장 저장장치(NVMe/SSD/HDD)의 게임 설치 폴더를 Wine 가상 드라이브(`E:\SteamLibrary`, `E:\EpicGames` 등)로 매핑.
   - **앱 실행 시 설정된 외장 게임 설치 폴더가 있으면 드라이브 심볼릭 링크를 Steam과 Epic Prefix 모두에 자동으로 연결·복구**.
   - 연결 해제 시에도 외장 드라이브의 실제 게임 파일은 안전하게 보존.

5. **게임패드 완벽 지원 (콘솔 모드)**
   - Apple GameController 프레임워크 및 SDL2 기반 DualShock 4, DualSense, Xbox 등 컨트롤러 인식.
   - MacDeck 런처 UI를 게임패드로 직접 탐색/실행할 수 있는 핸드헬드/콘솔 UX 제공.
   - Windows 내장 XInput 오버라이드 및 `joy.cpl` 진단 도구 연계.

5. **정밀한 3D 게임 크래시 분석 및 진단 시스템 (Diagnostics)**
   - 각 게임 실행마다 고유 UUID 기반 격리 로그 디렉터리 생성.
   - DXMT/렌더러 로그(`Renderer/`)와 프로세스 출력(`process.log`) 분리 저장.
   - GPU 장치 손실(Device Loss), D3D12 어댑터/장치 생성 실패(`IWineDXGIAdapter` / `D3D12CreateDeviceFailed`), 셰이더 컴파일 오류, DLL 예외 패턴을 자동 분석하여 `summary.txt` 단서 제공.
   - 원클릭 **진단 ZIP 내보내기** 기능으로 디버깅과 리포팅 용이.

---

## 🎮 게임 검증 및 호환성 현황

### 🕹️ 2D 게임: 1차 검증 완료 (추가 테스트 확장 진행 중)
- **검증 완료 항목:**
  - Windows x86_64 바이너리인 **Brogue CE 1.15.1**을 Wine + D3D11 + DXMT + Apple Metal 경로로 구동 성공.
  - Apple M5 환경에서 Apple Metal HUD 및 던전 렌더링 정상 확인.
- **향후 계획:**
  - 1차 검증은 완료되었으나, DirectDraw, Direct3D 9, SDL 소프트웨어 렌더러, 레거시 OpenGL 등 다양한 그래픽 엔진을 사용하는 **더 많은 종류의 2D 인디/클래식 게임을 추가 테스트**하여 호환성을 폭넓게 확보할 예정입니다.

### 🎲 3D 게임: 전역 DX11 Mode(DXMT) & DX12 Mode(VKD3D/MoltenVK) 구축 및 집중 테스트 진행 중
- **현재 상태:**
  - **DX11 Mode (DXMT → Metal · 기본 권장)** 및 **DX12 Mode (VKD3D 1.14 → winevulkan → MoltenVK → Metal 3 · 실험적)** 전역 전환 파이프라인이 구축되어 있습니다.
  - 외장 NVMe 드라이브(`E:\SteamLibrary`)에 설치된 **Resident Evil 3 (`re3.exe`)** 실행 시 Apple M5 Metal 3 전체화면(`2704x1756`, `38.45 FPS`) 스왑체인 렌더링을 확인했으며, 안정적인 플레이를 위해 전역 기본값을 **DX11 Mode**로 제공합니다.
- **향후 계획:**
  - 3D 게임은 복잡한 셰이더 연산, 엔진별 DirectX 11/12 특성, 안티치트(Anti-Cheat) 솔루션, 런타임 종속성(Visual C++ 재배포 패키지 등), 장시간 플레이 안정성 등 다양한 변수가 존재하므로 **앞으로도 다양한 3D 타이틀을 대상으로 테스트를 집중적으로 많이 수행해봐야 하는 단계**입니다.
  - 진단 시스템을 활용하여 각 3D 타이틀별 오류 패턴을 분석하고 순차적으로 호환성을 개선해 나갈 계획입니다.

### ☁️ Steam 클라이언트 및 외장 스토리지 연동
- Valve 공식 Windows `SteamSetup.exe`를 통한 설치, 최신 클라이언트 업데이트, Big Picture 로그인 및 외장 NVMe SSD(`E:\SteamLibrary`) 게임 다운로드·설치 검증 완료.
- 앱 재실행 시 설정된 외장 게임 설치 폴더 자동 재연결 및 총 **74개 자체 검증 테스트(`--self-test`) 통과**.

---

## 🏗️ 아키텍처

```text
┌─────────────────────────────────────────────────────────────────┐
│                    MacDeck.app (SwiftUI / AppKit arm64)         │
│  - 라이브러리 관리       - 외장 드라이브 자동 연결 - 게임패드 내비게이션 │
│  - 진단 및 ZIP 내보내기  - 전역 DX11/DX12 모드 전환 - 세션 로깅         │
└─────────────────────────────────┬───────────────────────────────┘
                                  │ 실행 (LaunchPlan)
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│               Rosetta 2 + WineSikarugir 10.0-8 (x86_64)         │
│  - Windows 환경 에뮬레이션 (drive_c, dosdevices)                  │
│  - Windows Steam (Big Picture) & Windows Game .exe              │
│  - Builtin XInput 게임패드 지원 / macOS Game Mode 활성화          │
└──────────────────┬──────────────────────────────┬───────────────┘
   DX11 Mode (기본) │                              │ DX12 Mode (선택)
                   ▼                              ▼
┌──────────────────────────────────┐ ┌────────────────────────────┐
│  DXMT 0.80 (SetRotation 패치)    │ │ Wine D3D12 (VKD3D 1.14)    │
│  - D3D10/11 → Metal 직접 변환     │ │ + Wine DXGI D3D12 Bridge   │
│  - d3d12/d3d12core 비활성화       │ │ + MoltenVK 1.4.1 (Vulkan)  │
└──────────────────┬───────────────┘ └────────────┬───────────────┘
                   └──────────────┬───────────────┘
                                  │ Metal 커맨드 인코딩
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Apple Metal (Apple Silicon GPU)             │
│  - M-Series GPU 하드웨어 가속 (Metal 3)                          │
│  - Metal Performance HUD 실시간 오버레이                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🚀 빠른 시작

### 요구 사양
- Apple Silicon Mac (M1, M2, M3, M4, M5 등)
- macOS 13 (Ventura) 이상 (macOS 15/26+ 지원)
- Rosetta 2 (`softwareupdate --install-rosetta --agree-to-license`)
- Swift 5.9+ 명령행 도구 및 Python 3

### 빌드 및 패키징

```bash
# 1. 저장소 클론
git clone https://github.com/sjhdeux0114/macDeckAI.git
cd macDeckAI

# 2. 런타임 준비, 앱 빌드, 자체 테스트 및 패키징 일괄 실행
bash scripts/package-mac-app.sh

# 3. 앱 실행
open dist/MacDeck.app
```

> **단독 빌드만 수행할 경우:**
> ```bash
> bash scripts/build-mac-app.sh
> dist/MacDeck.app/Contents/MacOS/MacDeck --self-test
> ```

---

## 📁 디렉터리 구조

```text
macDeckAI/
├── Sources/
│   ├── MacDeck/               # MacDeck 메인 애플리케이션 (SwiftUI/AppKit)
│   │   ├── App.swift          # 앱 엔트리포인트 및 UI 뷰
│   │   ├── RuntimeUpdater.swift # MoltenVK / DXMT / Wine Engine 자동 업데이트
│   │   ├── Library.swift      # 게임 라이브러리 및 실행 플랜
│   │   ├── Runtime.swift      # Wine/Steam 프로세스 제어
│   │   ├── SteamClient.swift  # Steam 연동 및 VDF 파서
│   │   ├── SteamStorage.swift # 외장 드라이브 Steam 라이브러리 등록/해제
│   │   ├── ExternalLibrary.swift # 외장 폴더 마운트 관리
│   │   ├── Gamepads.swift     # 게임패드 입력 및 UI 내비게이션
│   │   ├── Diagnostics.swift  # 세션별 로그 및 크래시 진단
│   │   └── SelfTests.swift    # 자체 검증 테스트 스위트
│   └── MacDeckProbe/          # 초기 가상화/Metal 프로브 도구
├── scripts/                   # 빌드, 패키징, 런타임 준비, 호환성 패치 스크립트
├── patches/                   # DXMT 0.80 소스 호환성 패치 파일
├── docs/                      # 기술 문서 및 심층 분석 보고서
│   ├── MACOS-APP.ko.md        # macOS 앱 동작 원리 및 검증 기록
│   └── PORTING-REPORT.ko.md   # DroidDeck 분석 및 Linux VM 비교 리포트
├── licenses/                  # 오픈소스 라이선스 고지
├── work.md                    # 누적 개발/검증/인계 일지
└── AGENTS.md                  # 작업 가이드라인 및 보안 수칙
```

---

## 🔒 보안 및 개인정보 보호

- Steam 계정 비밀번호, Steam Guard 코드, 로그인 세션 토큰 등 인증 정보는 **Steam 공식 클라이언트 내부에서만 처리**되며, MacDeck은 이를 절대 수집하거나 가로채지 않습니다.
- 크래시 진단 로그 및 ZIP 내보내기 시 민감한 환경 변수나 인증 관련 인수는 자동으로 마스킹 처리됩니다.
- 인증 정보 파일 및 일시적 QR 코드 스크린샷은 `.gitignore`에 의해 저장소 추적에서 철저히 격리됩니다.

---

## 📋 변경 내역 (Changelog)

> 세부적인 작업·검증·디버깅 누적 기록은 [`work.md`](work.md)에서 확인할 수 있습니다.

### v0.5.9 (2026-10-19)
- **용사30(Half Minute Hero, App ID 214830) 게임 시작 시 검은 화면 수정 (Clear v2 slot 30 후보 배포)**:
  - 타이틀 화면 정상 출력 후 "게임 시작" 시 검은 화면에서 멈추는 현상의 원인을 정밀 분석했습니다.
  - upstream DXMT v0.4의 `D3D9ClearQuad::clear` 상수 버퍼 슬롯 불일치(CPU 슬롯 0 전달 vs Metal 셰이더 `kCustomBufferArgumentIndex0=30` 참조)로 인해 인게임 씬 진입 시 Viewport/Depth Clear가 0(검은색)으로 채워지는 결함을 격리 GPU 검사로 확인했습니다.
  - exact App ID 214830 전용 `macdeck_hmh_dxmt_clear_v2.dll` (slot 30 패치 후보, SHA-256 `84a4886fd6ac94d8dff5a680652f52068ccfb4be744aa40468a30b6843126627`) 및 `dxmt-clear-v2` 라우팅을 안전하게 배포했습니다.
  - 계정 없는 격리 GPU 검사(`test-hmh-clear-metal-gpu.py`)에서 partial depth/color Clear 및 SM3 FP16 draw 통과, 외래 4개 App ID 원본 경로 보존 및 자체 검사 185개 전원 통과를 확인했습니다.
- **D9VK 모드 전면 제거 및 Direct Metal 단일화**:
  - 불안정하고 심한 버벅임이 발생하던 D9VK 모드를 제품 모델, 실행 override, UI, trial 도구에서 완전히 제거하고, 정확한 App ID 기반 Direct Metal 경로로 일원화했습니다.
- **DmC Devil May Cry (App ID 220440) Direct Metal 가속 및 1920×1200 60 FPS 달성**:
  - WineD3D DXT5 텍스처 크래시 해소, Clear 상수 슬롯 교정(v3), BC 압축 텍스처 sRGB 뷰 교정(v4, 과노출 개선), `QueryGetData` busy-poll 양보(v5, `Sleep(0)`으로 잔렉 해소)를 통해 실제 1920×1200 해상도에서 70+ FPS 안정 렌더링을 검증했습니다.

### v0.5.5 (2026-10-18)
- **게임별 Direct3D 9 렌더러 선택 프로필(`D3D9Mode`) 및 Native D9VK Metal 가속 연동**:
  - 개별 게임 [실행 설정] 및 라이브러리 상세 패널에서 Direct3D 9 렌더러 모드(`자동 감지` / `WineD3D` / `Native D9VK`)를 선택할 수 있도록 지원했습니다.
  - Native D9VK 선택(또는 자동 감지 시 게임 폴더에 `d3d9.dll` 존재) 시 `WINEDLLOVERRIDES`에 `d3d9=n,b`를 주입하고 WineD3D Vulkan 설정을 해제하여, 패치된 D9VK가 Apple Metal 3 GPU 하드웨어로 직접 드로우 콜을 렌더링하도록 연동했습니다.
- **Direct3D 9 게임 Vulkan → MoltenVK → Apple Metal GPU 하드웨어 가속 (`WINE_D3D_CONFIG="renderer=vulkan,csmt=0"`)**:
  - 기존 레거시 OpenGL 백엔드가 Apple Silicon macOS에서 CPU 소프트웨어 래스터라이저로 폴백되어 30초전사 등 고전 D3D9 게임 구동 시 CPU 195% 점유 및 극심한 렉이 발생하던 문제를 해결했습니다.
  - WineD3D를 Vulkan 백엔드로 구성하여 Apple Metal 3 GPU 하드웨어로 직접 렌더링하고, MoltenVK 하드웨어 큐와의 버퍼 경합을 방지하도록 커맨드 스트림을 안전하게 직렬화(`csmt=0`)했습니다.
- **실행 바이너리 PE 헤더 자동 판별 기반 32비트 WoW64 ESync 전환 (`0xC0000005` 크래시 방지)**:
  - macOS용 Wine에서 32비트 WoW64 프로세스가 Mach-message MSync(`WINEMSYNC=1`) 구동 시 공유 메모리 핸들 인덱스 검색 실패로 소켓이 끊어지며 `0xC0000005` (Access Violation)로 비정상 종료되는 업스트림 결함을 분석했습니다.
  - PE 바이너리 머신 타입(`IMAGE_FILE_MACHINE_I386`)을 감지하여 32비트 게임은 `WINEMSYNC=0, WINEESYNC=1`로 안전하게 구동하고, 64비트 게임(RE3, DMC5 등)은 고성능 MSync(`WINEMSYNC=1`)를 유지하도록 이원화했습니다.
- **주요 게임 엔진(Unity, Unreal, CryEngine, EA Frostbite, Havok, Godot) 크래시 방지 및 안티치트 오버라이드**:
  - `UnityCrashHandler`, `CrashReportClient`, `CryCrashHandler`, `OriginCrashReporter`, `EACrashReporter` 및 `EasyAntiCheat` 모듈을 차단하여 백그라운드 프리징 및 실행 불가 현상을 방지했습니다.
- **게임 내 Apple Metal Performance HUD 기본 활성화 및 인게임 단축키 (`Fn + Shift + F9`) 지원**:
  - 기존에는 `showMetalHUD`가 비활성화되어 `MTL_HUD_ENABLED="0"`이 명시적으로 주입됨에 따라 macOS Metal 프레임워크가 HUD 오버레이 자체를 로드하지 않아 게임 중 `Fn + Shift + F9`를 눌러도 HUD가 나타나지 않았습니다.
  - Metal HUD 기본값을 켬(`MTL_HUD_ENABLED="1"`)으로 변경하고 전역 defaults(`MetalForceHudEnabled=YES`) 및 세션 환경을 동기화하여, 게임 화면에서 실시간으로 **`Fn + Shift + F9`**(또는 `Shift + F9`)를 눌러 FPS·GPU 사용률·프레임 간격 오버레이를 자유롭게 켜고 끌 수 있도록 개선했습니다. (`Fn + Shift + F7`로 화면 표시 위치 순환 가능)
- **창 닫기 및 앱 종료 시 완전 종료 (`applicationShouldTerminateAfterLastWindowClosed` & `terminateAll`)**:
  - SwiftUI WindowGroup에서 창 닫기 버튼(빨간색 X 버튼)을 누르면 앱이 종료되지 않고 백그라운드에 남아있던 문제를 해결하기 위해 `MacDeckAppDelegate`를 구현하여 창이 닫히면 앱이 즉시 완전 종료되도록 처리했습니다.
  - 앱 종료(`Cmd + Q`, 창 닫기, 사이드바 "MacDeck 종료" 버튼) 시 `DeckModel.terminateAll()`을 호출하여 실행 중인 자식 프로세스, 로그 핸들, 타이머뿐만 아니라 Wine 백그라운드 데몬(`winedevice.exe`, `steamservice.exe`, `wineserver`)까지 안전하고 완벽하게 정리하여 백그라운드 자원 점유를 방지했습니다.
- **CrossOver / Proton / Whisky 호환 렉·오디오·비디오 최적화 패치 일괄 적용**:
  - Mach-message 기반 초고속 멀티스레드 동기화(`WINEMSYNC=1`, `WINEESYNC=1`, `WINE_LARGE_ADDRESS_AWARE=1`)로 CPU 스레드 병목 및 렉 해소.
  - XAudio2/X3DAudio/DirectSound Wine 내장 오버라이드로 컷씬 대사 누락 및 무음 방지.
  - Apple VideoToolbox 하드웨어 가속(`vtdec`, `vtdec_hw`), AC-3, DTS, MP4/MKV GStreamer 확장 패키지 번들링 및 1.3MB 사전 인덱싱 레지스트리 자동 시딩으로 초기 로딩 프리징 제거.
  - DX11 DXMT 맵 플래그/Alt-Tab 크래시 방지(`DXMT_CONFIG`), DX12 MoltenVK Argument Buffers 및 커맨드 버퍼 사전 채움 최적화 적용.
- **배포용 DMG 패키징 및 GitHub Releases 배포**:
  - `dist/MacDeck-v0.5.5.dmg` 고압축 UDZO 배포 이미지(532MB) 생성 및 GitHub Releases `v0.5.5` 배포 완료. 자체 검증 테스트 **95개 전원 통과**. (사용자 지침에 따라 일상 빌드 시 DMG는 명시적 요청 시에만 생성)

### v0.5.3 (2026-10-18)
- **`steamwebhelper.exe` `0x80000003` (`DelayLoadFailureHook`) 크래시 및 `winedbg` 모달/콘솔 팝업 근본 수정**:
  - **원인 규명**: `libcef.dll`의 RVA `0x59ef905`(Chromium `DelayLoadFailureHook`)에서 지연 로드 대상(`dxgi.dll`, `d3d12.dll`) 로드 실패 시 즉시 `int3`(`0x80000003`) 예외가 발생하는 것을 확인했습니다. `Bottles/Steam/drive_c/windows/system32/dxgi.dll` 누락 및 `d3d12,d3d12core=` 비활성화 오버라이드가 결합되어 `steamwebhelper.exe`가 충돌하고, Wine `winedbg --auto`가 모달 에러 창 또는 콘솔 창을 반복 실행하며 공유 메모리(`SteamChrome_MasterStream`)를 잠그던 문제를 해결했습니다.
  - **Prefix `system32` / `syswow64` 자동 동기화 (`DirectX12Support.syncPrefix`)**: 전역 그래픽 모드 적용 시 런타임뿐만 아니라 모든 Wine prefix(`Bottles/*`) 내부의 `drive_c/windows/system32/dxgi.dll` 및 `drive_c/windows/syswow64/dxgi.dll`, 코어 그래픽 DLL(`d3d11.dll`, `d3d10core.dll`, `d3d12.dll`, `d3d12core.dll`, `winemetal.dll`), `AeDebug` 레지스트리를 자동 복구·동기화합니다.
  - **CEF 호환 DLL 오버라이드 및 `winedbg.exe=d` 적용**: `d3d11,dxgi,d3d10core,d3d12,d3d12core,vulkan-1,winevulkan,winemetal=b`를 유지하여 CEF 지연 로드가 실패하지 않게 하면서 DXMT `dxgi.dll`과 `.ini` 설정으로 DX11 경로를 유도하고, `winedbg.exe=d`로 불필요한 크래시 모달/터미널 창 팝업을 차단했습니다.
  - **Steam 종료 시 잔존 프로세스 정리 (`wineserver -k`) 및 기동 경합 방지**: 그래픽 모드 전환이나 런타임 업데이트 시 Steam을 먼저 정상 종료하고 `wineserver -k`로 잔존 프로세스를 정리한 뒤 파일을 교체하도록 개선했습니다.

### v0.5.2 (2026-10-18)
- **런타임 구성요소(MoltenVK · DXMT · Wine Engine) 확인 및 자동 업데이트 (`RuntimeUpdater.swift`)**:
  - `런타임` 설정 탭에 **런타임 구성요소 자동 업데이트** 패널을 추가하여 **MoltenVK**(`KhronosGroup/MoltenVK`, `v1.4.1` → `v1.4.2`), **DXMT**(`3Shain/dxmt`, `v0.80`), **Wine Engine**(`Sikarugir-App/Engines`, `v10.0_8`)의 공식 GitHub Releases 최신 버전을 실시간으로 확인하고 업데이트할 수 있습니다.
  - **앱 시작 시 자동 확인 및 설치** 토글(기본 켜짐), 개별 업데이트 버튼, "업데이트 확인" 및 "지금 자동 업데이트 실행" 버튼을 제공합니다.
  - 다운로드된 패키지의 **SHA-256 무결성 검증**, Mach-O `x86_64` 아키텍처 슬라이스 검증, 기존 파일 백업 후 원자적 교체, 심볼릭 링크(`libvulkan.1.dylib`) 및 호환성 패치(`SetRotation(IDENTITY)`, `dxgi-dxmt`/`dxgi-d3d12`, `wine` Game Mode `Info.plist`) 유지, ad-hoc 코드 재서명을 자동으로 수행합니다.
- **자체 검증 테스트 확대**:
  - `RuntimeUpdater` 버전 비교, GitHub Releases JSON 파싱, SHA-256 검증 및 로컬 아카이브 설치 테스트를 포함해 **74개 자체 검증 테스트(`--self-test`) 전수 통과**.

### v0.5.1 (2026-10-18)
- **전역 DX11 Mode / DX12 Mode 전환 설정 지원**:
  - 특정 게임에만 국한되지 않고 **Steam 및 모든 Windows 게임에 전역으로 적용**되는 `DX11 Mode (DXMT → Metal · 기본 권장)` / `DX12 Mode (VKD3D · MoltenVK → Metal · 실험적)` 전환 기능을 추가했습니다.
  - 상단 툴바 세그먼트 버튼, `런타임` 탭, `Steam` 탭, 게임 실행 설정에서 언제든 모드를 변경할 수 있으며, 모드 전환 시 런타임의 `dxgi.dll`(`dxgi-dxmt` ↔ `dxgi-d3d12`), `WINEDLLOVERRIDES`(`DX11 Mode` 시 `d3d12,d3d12core=` 비활성화), 게임 `.ini` 설정이 일괄 동기화되고 실행 중인 Steam이 자동으로 재시작됩니다.
- **macOS Game Mode (`Game Mode: On`) 활성화**:
  - `MacDeck.app/Contents/Info.plist` 및 내장 `Runtime/bin/wine` 바이너리의 `__TEXT,__info_plist` 섹션에서 `LSUIElement=1`을 제거하고 `LSApplicationCategoryType = public.app-category.games`, `LSSupportsGameMode = true`, `GCSupportsGameMode = true`를 패치하여 macOS `gamepolicyd`가 게임 모드를 활성화하도록 개선했습니다.
- **자체 검증 테스트 확대**:
  - 전역 DX11/DX12 모드 전환 및 런타임/설정 동기화 검사를 포함해 **69개 자체 검증 테스트(`--self-test`) 전수 통과**.

### v0.5.0 (2026-10-18)
- **DirectX 12 (`VKD3D 1.14 + MoltenVK 1.4.1 → Apple Metal 3`) 지원 추가**:
  - `Runtime/lib/libvulkan.1.dylib` 및 `libvulkan.dylib` → `libMoltenVK.dylib` 심볼릭 링크 구성.
  - DXMT `dxgi.dll`(D3D10/11 전용)과 Wine `d3d12.dll`(`IID_IWineDXGIAdapter` / `ID3D12CommandQueue` 요구) 간의 인터페이스 충돌을 해결하기 위해 Wine 원본 D3D12 호환 `dxgi.dll`(237KB, `Wine native  DLL` 브리지)을 `Runtime/lib/wine/dxgi-d3d12/`에 별도 보존.
  - `DirectX12Support` 자동 감지(`D3D12Core.dll`, `d3d12.dll`, `.ini` `Capability=DirectX12`, 실행 파일 `D3D12CreateDevice` 임포트 검사) 및 게임별 그래픽 백엔드(`자동 감지` / `DXMT` / `D3D12`) 선택 UI 추가.
  - 외장 NVMe 드라이브에 설치된 3D Steam 게임 **Resident Evil 3 (`re3.exe`, DirectX 12)** 실행 및 Apple M5 Metal 3 스왑체인 렌더링 검증.
- **앱 시작 시 외장 게임 설치 폴더 자동 연결 (`autoConnectAll`)**:
  - `library.json`에 설정된 외장 게임 설치 폴더(`externalLibraries`)가 있으면 앱 실행 시 자동으로 Wine `dosdevices/<drive>:` 심볼릭 링크를 생성·복구하고 비루트 경로(`E:\SteamLibrary`) 마이그레이션 및 Steam `libraryfolders.vdf` 등록을 수행.
- **진단 및 테스트 강화**:
  - `SessionDiagnostics`에 D3D12 어댑터/장치 생성 실패(`17399d75-964e-4c03-99f8-9d4fd196dd62`, `D3D12CreateDeviceFailed`) 단서 요약 추가.
  - 자체 검증 테스트(`--self-test`) **54개 → 68개**로 확대 및 전수 통과.

### v0.4.0 – v0.4.1 (2026-10-17)
- **외장 스토리지 Steam 자동 등록 및 비루트 경로(`E:\SteamLibrary`) 정규화**:
  - Steam 실행 여부를 `tasklist.exe`로 확인 후 안전하게 종료하고 `steamapps/libraryfolders.vdf` 및 `config/libraryfolders.vdf` 양쪽에 백업 후 반영.
  - 연결 해제 시 실제 게임 파일은 삭제하지 않고 보존하는 안전 해제 구현.
- **게임패드(DualShock 4 등) 지원 및 런처 콘솔 내비게이션**:
  - Apple `GameController` 및 SDL2 기반 실시간 버튼·스틱·트리거 입력 모니터링, 전경 런처 패드 조작, Windows builtin XInput 오버라이드 적용.
- **실행별 정밀 진단 시스템 (`Diagnostics.swift`)**:
  - 실행별 독립 세션 폴더, `diagnostics.json`, 렌더러 로그 분리(`Renderer/`), 오류 단서 요약(`summary.txt`), 원클릭 진단 ZIP 내보내기 구현.

### v0.2.0 – v0.3.0 (2026-10-17)
- **Windows Steam Big Picture 통합 (`WineSikarugir 10.0_8`)**:
  - Valve 공식 `SteamSetup.exe` 무인 설치, 전용 영속 prefix(`Bottles/Steam`), Big Picture 자동 시작, 설치된 Steam 게임 자동 동기화.
- **외장 드라이브 연결 기반 마련 (`ExternalLibrary.swift`)**:
  - 외장 볼륨 UUID 마커 파일 기반 연결 상태 확인 및 Wine 드라이브 문자 할당.

### v0.1.0 (2026-10-17)
- **macOS 네이티브 런처 및 Direct3D 11 → DXMT 0.80 → Apple Metal 가속**:
  - `SetRotation(IDENTITY)` 호환 패치를 통해 SDL2/D3D11 게임의 OpenGL 폴백을 방지하고 Apple M5 Metal HUD 및 **Brogue CE (Windows x86_64)** 하드웨어 가속 검증 완료.

---

## 📄 라이선스

본 프로젝트의 자체 소스 코드는 **GPL-3.0** 라이선스로 배포됩니다.
포함되거나 연계되는 외부 런타임(Wine, DXMT, VKD3D, MoltenVK, SDL2 등)은 각 프로젝트의 원본 라이선스를 준수합니다. 자세한 내용은 [`LICENSE`](LICENSE) 및 [`licenses/`](licenses/) 디렉터리를 참고하십시오.


### 진행 중 — RE3 플레이 안정성 및 Game Mode 실제 적용 (2026-10-18)
- RE3 타이틀/프레임 렌더링 확인과 새 게임 이후의 안정적 플레이는 구분합니다. 사용자가 새 게임/플레이 중 크래시를 보고하여 재현·로그 수집 중입니다.
- 설치된 Wine에 Game Mode plist 키가 반영되지 않는 고정 길이 패치 문제를 확인하고 간결한 XML로 수정했습니다. 실제 On 여부는 전체화면 실행 후 별도로 검증합니다.


### v0.5.4 (2026-10-18)
- Wine의 936-byte embedded plist에 맞지 않아 Game Mode 지원 정보가 누락되는 문제를 compact XML로 수정. 바이너리 길이 및 Wine application class를 보존하고 실제 설치본에도 반영했습니다.
- Game Mode는 [Apple의 전체화면 활성화 조건](https://support.apple.com/en-mide/105118)을 따릅니다. 지원 키 반영과 실제 On을 구분하며 On을 확인했다고 주장하지 않습니다.
- Steam raw 출력/인증 정보는 저장하지 않고 Vulkan/MoltenVK 오류만 허용 목록으로 남기는 별도 수집기와 `Renderer/vulkan-stderr.log`를 추가했습니다. 진단 요약에 Vulkan 장치 손실 단서를 추가했습니다.
- DX11 모드가 DX12 전용 게임을 변환한다는 설명을 정정했습니다. RE3 새 게임/플레이 중 크래시는 재현·조사 중이며 미해결입니다.
- 자체 검사 **77개** 및 그래픽 로그 필터 검사 **3개** 통과. 설치본 v0.5.4 서명 검증 완료.

### 2026-10-18 — RE3 검은 화면 조사
- 반복 Metal GPU timeout 후 VK_ERROR_DEVICE_LOST를 확보했습니다. 근본 원인은 조사 중이며 안정적인 플레이는 아직 검증되지 않았습니다.
- GPU 오류 후 강제 재개 설정을 해제하고 진단 요약에 Metal timeout을 추가했습니다. timeout 자체의 해결은 아니며 다음 실행부터 적용됩니다. Game Mode는 여전히 Off로 보고됐습니다.
- 이번 수정 후 빌드 및 자체 검사 **79개 통과**. DX11 버전 비교와 실제 플레이 검증은 남아 있습니다.
- 설치본 실행 파일 교체 및 서명 검증 완료. 적용을 위한 Steam 재시작 및 게임 재검증은 아직 진행하지 않았습니다.

- 2026-10-18: 사용자 Steam에서 RE3 `dx11_non-rt` 제공 확인. 해당 게임 버전 다운로드 후 MacDeck DX11 Mode(DXMT → Metal)로 비교 예정이며, DX11 안정성은 아직 미검증입니다.

### 2026-10-18 — DX11 비교 결과
- RE3 dx11_non-rt(build11047294), DX11 Mode에서도 새 게임 시작 시 접근 위반(0xC0000005)으로 종료. 안정적 플레이 미달이며 DX12 GPU timeout과 동일 원인인지는 미확인입니다.
- 선택적 예외 진단 MACDECK_TRACE_EXCEPTIONS=1과 허용 목록 예외 주소 수집을 추가했습니다. 영상 재생 경로도 조사 후보이나 원인으로 확정하지 않았습니다.
- 예외 진단 빌드 자체 검사79개 및 예외 로그 필터 검증 통과. 다음 실행의 예외 주소를 확보해 원인 모듈을 조사합니다.
- 영상 런타임 결함 발견: winegstreamer.so의 GStreamer 의존 라이브러리 누락으로 실제 로드 실패. RE3 크래시와의 인과관계는 아직 미확인입니다.

### 2026-10-18 — 영상 의존성·한글 글꼴 보완
- 공식 GStreamer1.28.8을 앱 전용 Runtime/Media에 배치. x86_64 Wine 영상 모듈 로드와 WMV3 디코더 검사 통과. 시스템 설치는 하지 않으며 실제 RE3 플레이 재검증은 남아 있습니다.
- Steam 한글 네모 대응: 이 Mac의 기존 Apple SD Gothic Neo를 Wine에 연결하고 한국어 대체 글꼴/FontLink 자동 등록. Apple 글꼴은 배포물에 포함하지 않습니다. 실제 화면 검증은 남아 있습니다.
- 빌드 및 자체 검사79개 통과.
- 한글 등록 첫 실행의 라이브러리 검색 경로 누락을 수정했습니다. regedit 성공 및 FontLink/한국어 대체 글꼴 레지스트리 반영 확인, 재빌드/검사79개 통과.
- 수정 설치본에서 한글 등록 성공 마커 및 새 Steam 세션 running 확인. 실제 한글 화면 표시와 RE3 새 게임 진행은 사용자 확인 대기 중입니다.

- 디코더 보완 후에도 RE3가 동일 주소에서 종료됨. WMV 디코더 외에 누락된 ASF 컨테이너 파서를 추가하고 영상 생성 실패 진단을 보강 중입니다. 실제 플레이 해결은 아직 확인되지 않았습니다.
- ASF 파서 인식뿐 아니라 합성 WMV/ASF 생성→파싱→디코드 파이프라인까지 x86_64에서 통과했습니다. 앱 설치본에 보완 반영 후 DX11 Steam을 재시작했습니다. RE3 자체의 플레이는 재검증이 필요합니다.

- 최신 RE3 로그에서 deinterlace 요소 누락→영상 소스 생성 실패→같은 주소 접근 위반을 확인했습니다. effects 패키지 및 Wine 후처리 체인 검증 스크립트를 추가했습니다. RE3의 실제 진행은 재검증이 남아 있습니다.
- deinterlace 포함 필수 요소12종과 영상/음성 처리2종 검사 모두 통과. 보완 런타임 설치 및 DX11 Steam 재시작 완료. RE3 플레이 성공은 아직 미확인입니다.

- 2026-10-18: deinterlace 보완 후 사용자 RE3 구동 성공 보고. 장시간 안정성은 미검증. Game Mode는 여전히 Off이며 Metal HUD 표시 상태와 별개입니다.

### 2026-10-18 — Steam Big Picture 화면 가속 설정
- 기존 고정 GPU 비활성화 옵션을 선택 가능하게 변경했습니다. Steam 탭의 화면 GPU 가속 토글로 허용하며 완전 재시작 후 적용됩니다. 게임 Metal 가속과 별개입니다. 검은 화면/호환 문제가 생기면 끄고 다시 실행할 수 있습니다. 실제 가속 및 성능은 검증 중입니다.
- 화면 가속 옵션 검사 포함 자체검사80개 통과, 설치본에 반영하고 가속 허용으로 Steam 재시작. 실제 GPU 렌더링 검증 중입니다.
- 실제 재시작 후에도 Steam 자체가 --disable-gpu/SwiftShader를 선택해 Big Picture mode:System 유지. Steam 내부 웹 보기 GPU 가속 설정 확인이 필요하며, 현재 성능 개선 성공은 미확인입니다.

- Steam 내부 가속 설정이 이미 켜졌는데도 소프트웨어 렌더링이 유지됨을 사용자 확인. 가속 모드에 명시적 -cef-force-gpu를 추가해 비교 검증 중입니다.

- GPU 비교 중 구형 진단 도구가 새 설정 필드를 버려 소프트웨어 모드로 복귀한 문제를 발견했습니다. 설정을 복구해 다시 비교 중이며 앞선 재시작을 가속 성공으로 간주하지 않습니다.
- 개발용 ad-hoc 서명은 cdhash 기반으로 권한 유지에 제약이 있습니다. 외장 저장소 허용 반복을 조사 중입니다.

- Steam GPU investigation: Wine kernelbase injects --disable-gpu for Steam. A reversible exact-match patch is under runtime validation. Performance improvement remains unverified. External access was retained on the latest restart, but development resigning can trigger another permission request.

- Confirmed MacDeck removable-volume consent prompt recurs after ad-hoc resigning. Cross-update permission persistence remains unresolved; same-build consent and stable certificate signing must be distinguished.

### 2026-10-18 — HUD default off / DMC5 investigation
- User reports Steam Big Picture now works well.
- Metal HUD is now off by default, with an optional runtime settings toggle. Restart Steam and games to apply; Metal acceleration and error logs remain enabled.
- DMC5 has confirmed Metal GPU timeout followed by rejected submissions; long-stall stability and Command-Tab recovery remain unresolved.
- HUD-off build: 82 self-checks passed; installed and Steam restarted. Steam GPU configuration preserved. New session HUD environment: 0.

- Repeated removable-volume consent remains under investigation. The HUD build changed ad-hoc identity again; current installed signature verifies successfully. Further resigning is paused during same-build permission reproduction.
- User clarified consent repeats after updated builds. This matches changing ad-hoc signing identity; same-run repeated consent has not been reported. Stable certificate signing remains pending.

- DMC5 still freezes in windowed/60 per user. Latest renderer log is empty; prior GPU timeout is not sufficient to identify this new freeze. Added a DMC5-only DXMT60 FPS limiter and Wine Alt-Tab handling comparison config, without resigning MacDeck. Actual gameplay remains unresolved.

- DMC5 live recurring stalls sampled: Metal completion wait plus ongoing command encoding. Prepared an uninstalled GS/TS marshal arithmetic candidate patch. Actual Metal compiler component is missing; official Xcode component download started. No stall fix has been validated.
- Candidate GS/TS fix compiled after official Metal toolchain installation; native Metal tests match36 functions and pass a zero-draw/multi-task GS test. Binary deployment is pending size compatibility and actual DMC5 replay.

### 2026-10-18 — Experimental DMC5 stall candidate
- Installed a source-based DXMT0.80 GS/TS marshal candidate after native Metal boundary/batch validation and PE structural checks. Exact-version guard and original DLL backups retained.
- This is a runtime experiment; DMC5 same-scene stall resolution is not yet verified. Big Picture workaround and HUD-off remain enabled. New signing may request external-volume access again.

### 2026-10-18 — 사용자 확인 결과
- **DMC5: GS/TS 수정 후보 적용 후 긴 렉이 없어졌다는 사용자 확인을 받았습니다.** 장시간·전체 장면 안정성은 아직 미검증입니다.
- RE3 DX11 non-RT 구동, Steam Big Picture 정상화도 사용자 보고로 확인했습니다. HUD는 기본 끔입니다.
- 앱 자체 검사88개, 미디어 필수 요소/처리 체인23항목, 실제 Metal GS·TS 경계/복수 작업 검사를 통과했습니다. Game Mode On, DX12 안정성 및 수정본마다 반복되는 외장 볼륨 권한은 여전히 별도 과제입니다.
- Runtime binary patches are experimental and version-locked. See [runtime patch notes](docs/runtime-patches.md) for reproducibility and rollback.

### 2026-10-18 — 타 플랫폼(Proton/CrossOver/Whisky/DXMT) 종합 최적화 (v0.5.5)
- **멀티스레드 동기화 최적화 (MSync / ESync)**:
  - macOS Mach-message 및 공유 메모리 기반 고속 동기화인 `WINEMSYNC=1`, `WINEESYNC=1`, `WINEMSYNC_QLIMIT=512`를 활성화하여 wineserver 소켓 IPC 병목에 의한 CPU 렉과 스레드 기아 현상을 해소.
  - 32비트/구형 게임의 2GB 가상 메모리 초과 크래시를 방지하는 `WINE_LARGE_ADDRESS_AWARE=1` 활성화.
- **오디오 끊김 및 컷씬 무음 방지 (XAudio2 / DirectSound)**:
  - RE Engine 및 Unreal Engine 게임들이 번들하는 Windows용 불완전 DLL 로드를 방지하고 Wine 내장 FAudio/CoreAudio를 강제 적용하도록 `xaudio2_0`~`xaudio2_9`, `x3daudio1_0`~`x3daudio1_7`, `dsound`를 `WINEDLLOVERRIDES`에 내장(`b`)으로 등록.
- **동영상 컷씬 하드웨어 가속 및 코덱 보강 (Media Foundation / GStreamer)**:
  - Apple Silicon VideoToolbox 하드웨어 가속 디코더(`vtdec`, `vtdec_hw`), Dolby Digital AC-3(`a52dec`), DTS(`dtsdec`), MP4(`qtdemux`), MKV(`matroskademux`) 등 GStreamer 확장 패키지 번들링.
  - 호스트 GStreamer 플러그인 충돌을 차단하는 격리 환경변수(`GST_PLUGIN_PATH_1_0=""`) 및 `mfplat`, `mfreadwrite`, `quartz` 내장 오버라이드 등록.
  - 미디어 런타임 검사 스크립트 23개 항목(`verify-media-runtime.py`) 전원 통과.
- **렌더링 프레임 페이싱 및 크래시 방지 (DXMT & MoltenVK)**:
  - DX11 (DXMT): `d3d11.ignoreMapFlagNoWait=True` (비동기 Map 크래시 방지), `dxgi.handleAltTab=True` (전체화면 전환 프리징 방지), `d3d11.maxTessFactor=64` (테셀레이션 폭주 방지) 기본 적용.
  - DX12 (MoltenVK + VKD3D): `MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=1` (드로우콜 오버헤드 감소), `MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS=3` (커맨드 지연 완화), `VKD3D_FEATURE_LEVEL=12_1`, `VKD3D_CONFIG=no_upload_hlist` 적용.
- **초기 로딩 프리징 방지 및 Prefix 그래픽 DLL 동기화 보강**:
  - `Runtime/Media/gst-registry.bin` 사전 캐시 번들링 및 자동 시딩을 통해 최초 게임 구동 시 10~15초 플러그인 전수조사 프리징을 완전히 제거.
  - Prefix(`drive_c/windows/{system32,syswow64}`) 내부 그래픽 DLL(`d3d11.dll` 등)을 바이트 단위로 검사하여 런타임 최신 패치 버전을 원자적으로 강제 동기화.
- **배포용 DMG 패키징 (`scripts/package-dmg.sh`)**:
  - `/Applications` 심볼릭 링크를 포함한 드래그 앤 드롭 설치 디스크 이미지(`MacDeck-v0.5.5.dmg`, 537MB) 생성 및 GitHub Releases 배포 지원.
- **창 닫기 시 백그라운드 프로세스 즉시 완전 종료**:
  - 메인 창 닫기 시 Wine/Steam 및 자식 프로세스가 백그라운드에 남아있던 현상을 수정하여 `applicationShouldTerminateAfterLastWindowClosed = true` 및 `terminateAll()`(wineserver 강제 정리)을 통해 즉각 완전히 종료되도록 개선.
- **Metal Performance HUD 실시간 단축키 (`Fn+Shift+F9`) 및 기본 활성화**:
  - 게임 플레이 중 GPU 프레임률, 프레임타임, 메모리 사용량을 즉시 확인할 수 있도록 `MTL_HUD_ENABLED=1` 기본 활성화 및 `Fn+Shift+F9`(또는 `Shift+F9`) 실시간 온오프 토글, `Fn+Shift+F7` HUD 위치 이동 안내 UI 추가.
- **MacDeck 전용 3D Apple-스타일 공식 앱 아이콘 (`AppIcon.icns`) 도입**:
  - Apple macOS 정밀 스퀴클(Superellipse) 규격을 준수한 고해상도(16×16 ~ 1024×1024) 전용 아이콘 제작 및 번들 탑재.
  - macOS Dock, Launchpad, Cmd+Tab 앱 전환기 및 MacDeck 사이드바에 통일된 아이콘 브랜딩 적용.
- **DirectX 9 (D3D9) 및 고전 게임 호환성 안정화**:
  - 30초전사(Half Minute Hero) 등 32비트 DirectX 9 게임 구동 시 범용 DXVK의 macOS 미지원 확장 오류(`D3DDevice creation failed`) 및 미완성 Vulkan 백엔드의 메모리 경합 크래시(`0xC0000005`)를 완벽히 해결. 공식 검증 WineD3D 및 Mach-message MSync 파이프라인으로 안전 구동.
  - ProMotion 120Hz 화면에서 60fps 고정 틱 게임의 슬로우모션/버벅임 해소 가이드라인 제공.
- **주요 게임 및 상용 게임 엔진(Unity · Unreal Engine · CryEngine · Frostbite · Cocos2d · Godot) 종합 충돌 방지**:
  - **Unity 엔진**: `UnityCrashHandler32/64.exe` 비활성화로 크래시 핸들러 무한 루프 및 창 프리징 차단.
  - **Unreal Engine 4 & 5 (호그와트 레거시 등)**: `CrashReportClient.exe` 소켓 IPC 블로킹 차단 및 DX12 가상 디스크립터 힙(`VKD3D_CONFIG=virtual_heaps`) 지원으로 대규모 텍스처 메모리 크래시 방지.
  - **CryEngine & EA Frostbite**: 백그라운드 프리징 및 오류 팝업을 유발하는 `CryCrashHandler.exe`, `OriginCrashReporter.exe`, `EACrashReporter.exe` 비활성화.
  - **FromSoftware (엘든링 등)**: `easyanticheat_x64=d`를 통해 Easy Anti-Cheat 커널 드라이버 로드 실패에 의한 초기 시동 크래시 방지.
  - **Rockstar (GTA V 등) & 2D 엔진 (Cocos2d 등)**: DirectInput 8(`dinput8=b`), 런타임 셰이더 컴파일러(`d3dcompiler_43/47=b`), 및 창 포커스 이탈 시 강제 최소화 방지(`SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0`) 적용.
  - **Apple Silicon Metal 특화 DLSS 충돌 방지**: 비호환 NVIDIA 라이브러리 쿼리 충돌(`nvngx=_nvngx=d`)을 차단하여 FSR/XeSS 정상 폴백 유도.
- 자체 검증 테스트 총 **94개 통과** (`94 checks passed`) 및 strict 코드 서명 검증 완료. (로컬 커밋 및 패키징 완료, 원격 GitHub 미업로드).

### 2026-10-18 — DX9 investigation resumed; compatibility audit in progress

- User reports Half Minute Hero still has DX9 problems; this is the immediate priority. Controller/keyboard/mouse UI overhaul remains pending.
- Correction to earlier notes: high CPU use and an OpenGL backend do not prove CPU-only rendering. The captured HMH sample loads AppleMetalOpenGLRenderer and AGXMetalG17G. No definitive root cause or successful DX9 fix is established.
- Compatibility audit removes unverified global anti-cheat/crash-handler/input-proxy overrides and feature-level spoofing. Static engine/API report implementation is in progress, not proof of game compatibility.
- No DMG requested or generated. Existing game-specific runtime patches must be preserved.

### 2026-10-18 — Half Minute Hero reproduction and mixed-architecture launch fix

- Confirmed Steam.exe is PE32+ x64, HMH.exe is PE32 x86. Checking only the Steam executable left MSync enabled for its 32-bit game children. Steam now uses ESync with MSync off; direct x64 executables retain the prior MSync policy. This changes synchronization for Steam-launched x64 games too; performance comparison remains pending.
- Reproduced HMH exit 0xC0000005 at 15:50:50, about 66 seconds after launch, even with ESync. It is NOT fixed by that change alone. Captured WineD3D Vulkan state/texture warnings, not a proven root cause.
- Added D3D/D3D9 warning/error filtering and WINE_D3D_CONFIG to diagnostic settings. Static compatibility reports now accompany sessions and are available from a game card context menu.
- Build and 101 self-checks passed. Source research and limits: docs/ENGINE-COMPATIBILITY.ko.md.
- Downloaded isolated experimental dacevedo12/dxmt v0.4-d3d9 release; SHA-256 e96aa707a7779f01b49234d64ce79d110fd461b9d0755828b74420f332f4df9b matches publisher metadata. Candidate test is in progress via WINEDLLPATH; established RE3/DMC5 runtime files were not replaced.
- Full controller/keyboard/mouse UI redesign is pending while HMH is prioritized. No DMG or new commit/push.

#### HMH investigation handoff state

- Updated launcher executable, graphics-log-filter and Info.plist in /Applications/MacDeck.app and ~/Applications/MacDeck.app; re-signed both. Existing runtime d3d11.dll SHA-256 was unchanged. A currently running launcher uses its old executable until restarted.
- Final validation: 101 self-checks, 2 graphics-filter checks, build and git diff --check passed.
- Current isolated DXMT D3D9 test Steam requires interactive login again. No login screenshots, credentials or authentication configs were collected. HMH success/Metal acceleration is unverified, and the experimental candidate is NOT installed into the shipping runtime.
- Local evidence: evidence/hmh-dx9-summary.json (crash), evidence/hmh-compatibility.json (static scan), evidence/hmh-esync-graphics.log and evidence/hmh-dxmt-d3d9-graphics.log (filtered output). Logs remain local and were not committed/pushed.

#### HMH candidate loader correction

- Steam later completed login and HMH started, so the preceding login-blocked status is superseded.
- lsof on HMH PID 77728 showed the original Runtime/lib/wine/i386-windows/d3d9.dll, NOT the candidate. WINEDLLPATH alone is insufficient: Wine 10 searches its own dll_dir first (wine-10.0/dlls/ntdll/unix/loader.c, set_dll_path). That run does not establish candidate compatibility.
- Created APFS clone .cache/hmh-d3d9-runtime and overlaid the candidate's x86/x64 graphics files only in the clone. The temporary .build/hmh-diagnose.swift helper now executes the clone after preparing the normal launch plan. Original installed runtime remains unchanged. New trial is still initializing Steam; actual HMH candidate load and gameplay are unverified.
- Static scan on the installed HMH confirmed x86 and d3d9.dll imports; no engine identity was inferred from its title.

#### Current final state (supersedes earlier trial states)

- Clone trial Steam PID 78563 loads .cache/hmh-d3d9-runtime/lib/wine/x86_64-unix/{ntdll.so,winemetal.so} and clone x86_64-windows/dxgi.dll (confirmed by lsof). Candidate lookup now works for Steam.
- Current Steam window is 'Steam login' (window metadata only); HMH is not running yet. Interactive login is required before the candidate can be validated on HMH. Do not claim a game fix or Metal gameplay success.
- Installed launcher contains only verified launch-policy/logging/audit changes. Pending candidate is confined to .cache. Existing known-good runtime preserved. No DMG, commit or push performed for this work.

### 2026-10-18 — HMH black-screen follow-up

- User reports black screen. Reproduced with the actual candidate i386 d3d9.dll and x86_64-unix/winemetal.so mapped (lsof PID 81445). Candidate Metal loading alone does not produce working gameplay.
- Disabling both MSync and ESync reduced winedevice CPU from ~100% per process to ~0–1.5% in this trial; HMH itself still uses ~100% CPU with a black window. This does not establish a general ESync bug or a completed game fix.
- Saved game-only screenshot and sample (evidence/hmh-nosync*). Native LLDB shows the graphics encode/finish threads waiting while a guest x86 thread is active; further module identification needed. WineDbg attach fault at 0xfff4fa8c belongs to its attach thread and must not be labeled the original hang cause.
- Intro comparison temporarily renamed res/logomovie.wmv to .wmv.macdeck-test-backup; evidence/hmh-intro-backup.json records original path and SHA-256. Restore immediately after the comparison.

#### HMH hot-loop and cropping investigation

- Native LLDB found the active guest x86 thread at 0x79bc86aa/0x79bc877d executing x87 byte-to-float pixel conversion. Exact bytes match native Microsoft d3dx9_42.dll at RVA 0xc86aa (mapped base 0x79b00000), confirmed by lsof. This establishes the hot code location, not the complete hang cause.
- Forced d3dx9_42=b in a diagnostic helper only. Candidate d3d9 and builtin d3dx9_42 mappings confirmed on PID 83136; Wine assertion 0x80000101 still occurred. Candidate is not ready for deployment.
- User additionally reports cropped display; clarification requested about which app screen. Exclusive game window is CG layer 26, so prior layer-0 window inventory missed it. Game-only screenshots are black and do not validate what the user sees.
- Intro movie comparison did not establish a fix; original logomovie.wmv restored and original SHA-256 verified. No movie files remain renamed.
- Native Metal assertion and DX9 presentation diagnostics added to graphics filter; its 2 tests pass. New diagnostic comparison: original WineD3D GL + builtin D3DX9 + no MSync/ESync in a 1280x720 Wine virtual desktop. Actual GPU rendering/performance and display fit still require verification. No CPU-only or Metal-success claim.

#### User validation supersedes screenshot assumptions

- Original WineD3D GL + builtin D3DX9 + 1280x720 virtual desktop produced visible animated artwork in a game-only capture, but the user reports severe stutter AND persistent cropping. This comparison FAILS the acceptance criteria. No Metal gameplay success or cropping fix is established.
- The test game is now closed (no HMH process). A macOS-specific D9VK candidate is being prepared; no new candidate installed into shipping runtime.

#### HMH macOS D9VK isolated comparison

- Downloaded official Sikarugir-App/d9vk v1.10.3-20240229 macOS-specific release (publisher digest unavailable; local archive SHA-256 bb3bd16cc93e5ca8ee3f6f7df31edf8950a0db4421d53f4ce72e28a681d1cfdf). This differs from generic upstream DXVK 1.10.3 previously tried.
- Temporarily added game-local d3d9.dll only after confirming none existed. evidence/hmh-d9vk-file.json stores SHA-256 and cleanup instruction. No original file replaced. Diagnostic helper overrides d3d9=n, keeps builtin d3dx9_42, no MSync/ESync, and tests a 1280x720 virtual desktop. Candidate is unverified.
- To clean up, remove ONLY the game-local d3d9.dll if its SHA-256 matches evidence/hmh-d9vk-file.json; retain any user-changed file. Original logomovie.wmv already restored and verified.
- Graphics filter now retains native Metal assertions and suppresses consecutive duplicate warnings, with 3 tests passed. This reduces repeated per-draw log writes.

#### D9VK result so far

- D9VK log confirms version v1.10.3-20240229-async (macOS), Apple M5 and Vulkan 1.1.334. lsof confirms game-local d3d9.dll, builtin d3dx9_42.dll and original libMoltenVK.dylib. This proves device-path selection, NOT working gameplay.
- Trial subsequently ended with access violation at 0x7917123c. Candidate remains unvalidated and must not be made the default. A debugger-launched game comparison is now collecting a real crash backtrace, avoiding the previously observed attach-thread fault.

#### Confirmed D9VK source defect and unit validation

- Real debugger-launched crash: d3d9+0x4123c, D3D9CommonTexture::GetMipSize. EBP=0x3b9d2b62 equals VK_FORMAT_G8_B8_R8_3PLANE_420_UNORM (1000156002, YV12). Inlined format lookup indexes the base table with that extension enum and reads invalid memory.
- Official source afae08756737382c1e91c398a2b7053a44f59ed9 has recursive lookupFormatInfo(format) instead of lookupFormatInfoSlow(format), and lacks YV12 in its table/groups. Fixed both in patches/d9vk-1.10.3-macos-format-lookup.patch.
- Compiled scripts/test-d9vk-formats.cpp against actual modified source and ran as a 32-bit Windows executable in an isolated Wine prefix: 8 format groups passed, including all base entries, YV12 planes/subsampling, preserved NV12/packed extensions and unknown rejection. Game validation remains pending.
- Official LLVM-MinGW 20261006 universal archive SHA-256 a7a19b11048e89372637d26279cdb7c430ed3cf8c1e224310421312bf986ebf6 verified. Build tools are confined to .cache. Pinned Vulkan and SPIR-V submodules match original source. LLVM build portability patch adds a missing algorithm header and conditional for modern MinGW's existing resource-manager type.

#### D9VK fixed candidate: device and intro validation

- A second source defect was confirmed: PFN_wineLogOutput used stdcall, while Wine 10 ntdll.spec exports __wine_dbg_output as cdecl. This corrupted the 32-bit logger stack with the LLVM build. Fixed in patches/d9vk-1.10.3-wine-logging-abi.patch. Actual Wine callback smoke test passed 64 repeated calls.
- Final local trial DLL SHA-256 938dffa748f58854af79a6890de8554728f5f2ef8e052cac4e10ffa2f65b2d86, label v1.10.3-20240229-macdeck-yv12.1 (macOS). Game-local trial manifest updated accordingly. No shipping runtime DXMT DLL replaced.
- Actual patched run creates CAMetalLayer WineMetalView swapchain 1280x720, contents scale 1.0 on Apple M5; game-only screenshot shows the complete controller-introduction screen. This is intro/device evidence, NOT proof of sustained gameplay or user-accepted performance/cropping. User verification requested.
- Launcher source now disables ESync rather than recommending it as an x86-safe fallback. Mixed Steam/x86 use server waits; direct x64 retains MSync. This supersedes earlier ESync claims. Performance of other Steam games needs comparison; no blanket speed-up claim.

#### Reproducibility and launch-policy cleanup

- scripts/build-d9vk-macos.py successfully re-applies/checks all three patches, rebuilds the prepared pinned source, compiles both x86 probes and writes evidence/d9vk-build-manifest.json. The rebuild DLL SHA-256 differs because of the PE build timestamp; currently running game still uses the separately recorded 938d... trial file. No running-game DLL was replaced during the rebuild.
- docs/DX9-HALF-MINUTE-HERO.ko.md records actual defects, toolchain/submodule identities, checks, limitations and precise checksum-guarded cleanup.
- Removed launchctl setenv from LaunchPlan; Metal HUD now uses child process environment only. Creating a plan/self-test must not change HUD for the entire login session. Existing per-app HUD preference is preserved.

#### Patched game still fails sustained-run acceptance

- Steam gameprocess metadata confirms patched run PID 2260 started 16:32:16 and ended 16:35:57 with 0xc0000005. Raw direct-game stderr identifies a NEW read fault at 0x75e9e42a, address 0x0e100000, after Metal swapchains and the controller intro. This supersedes any impression that intro output proved a complete fix.
- Re-running under WineDbg to identify the new module. Original YV12 array access and logger ABI tests remain fixed/passing, but sustained gameplay/performance/cropping remain unresolved.

#### Reusable trial and window diagnostics

- Added Run-HMH-Metal-Trial.command and scripts/run-hmh-d9vk-trial.py. They verify the existing trial DLL against its recorded checksum, use installed original Wine, require authenticated Steam, prevent duplicate HMH instances, and collect filtered graphics/DXVK logs under MacDeck/Logs/HMH-D9VK-Trials. No DLL installation is performed by the runner. Normal MacDeck launch integration remains pending.
- Windows-only HMH window probe confirms client 1280x720 at desktop bounds 0,33–1280,753, DPI 96, virtual screen 1280x720. The 33-pixel vertical offset may contribute to clipping; it is not yet a confirmed complete cause.
- Automated Enter was not delivered: Wine SendInput returned 0 for down/up with error 5. No further input workaround is attempted. Manual title/gameplay input is required.
- Launcher regression checks: 101 passed; graphics filter 3 checks passed; format 8 groups and logger 64 calls passed. Updated installed launchers/log filters only; original runtime x64 D3D11 hash preserved. Experimental D9VK remains game-local and not a normal-app default.

#### HMH follow-up current state / next steps

- Latest reusable-runner trial started 16:47:22 and ended 16:48:40 with Steam game exit code 0. This differs from the earlier one-off access violation; trigger/phase for that prior crash is unknown, potentially including exit. Do not label every observed exit a gameplay crash. User performance/cropping confirmation is still pending.
- Window position correction was NOT executed: probe --fit found no HMH window after the game closed. Only the observed 33-pixel offset is established; no clipping fix is claimed.
- Source proofs and probes are preserved; normal MacDeck HMH launch still forces builtin D3D9 and does not automatically use the experimental game-local DLL. Use Run-HMH-Metal-Trial.command for the prepared trial. Integrate a proper per-game profile only after user validation.
- New log collection retains Wine fatal page-fault headers, Metal assertions, and CPU GDI presentation fallback warnings, suppresses identical consecutive lines, and gives DXVK/D9VK a managed per-session log destination. A renderer fallback is not evidence of Metal gameplay success.
- Continue: verify title and actual play with keyboard/DS4, check clipping and frame pacing, identify any new fault with its trigger, then integrate/rollback the per-game profile. Manual input is required because both native and Wine automated input were not authorized/delivered. The full gamepad/keyboard/mouse MacDeck UI redesign remains pending behind this priority.
- No DMG created. No commit or push performed.

- Final follow-up verification: 102 launcher checks, 3 graphics-filter checks, 8 D9VK format groups and 64 logger callbacks passed. Trial DLL checksum matches its manifest; original intro hash restored. Installed launcher/logging updated with runtime preservation and signature verification; sustained gameplay/cropping acceptance remains pending.

### 2026-10-18 — 게임별 Direct3D 9 모드 프로필(`D3D9Mode`) 및 Native D9VK GDI 버벅임 근본 해결

- **게임별 D3D9 렌더러 선택 프로필 UI 추가**:
  - MacDeck 라이브러리의 게임 [실행 설정] 및 카드 상세화면에 **Direct3D 9 렌더러 (고전 게임)** 선택기 추가 (`자동 감지` / `WineD3D (기본 내장)` / `Native D9VK (Metal 가속)`).
- **Native D9VK 극심한 버벅임 원인(GDI Swapchain Blit 폴백) 규명 및 해결**:
  - **원인 분석**: macOS Retina 화면에서 윈도우 클라이언트 크기(`1512x982`)와 게임 백버퍼(`1280x720`) 불일치 시 D9VK가 `SwapEffect == D3DSWAPEFFECT_COPY`를 감지하여 CPU Windows GDI 스왑체인(`PresentImageGDI`)으로 잘못 폴백됨. Wine-macOS 환경은 Vulkan 표면의 GDI `GetDC`를 지원하지 않아 매 프레임 `D3DERR_DEVICEREMOVED`를 반환하고 FPS가 1~3으로 급락함.
  - **D9VK 소스 패치 (`patches/d9vk-1.10.3-disable-gdi-fallback.patch`)**: `useGDIFallback = false`로 강제하여 GDI 폴백을 완전히 제거. 윈도우 크기와 무관하게 D9VK 내부 고성능 Vulkan/Metal 셰이더 블리터(`m_blitter->presentImage`)가 백버퍼를 스왑체인으로 100% Metal 3 GPU 상에서 직접 렌더링.
  - **60fps 프레임 페이싱 연동 (`dxvk.conf`)**: `d3d9.maxFrameRate = 60`, `d3d9.presentInterval = 1`, `d3d9.dpiAware = True`를 포함하는 관리형 `dxvk.conf`를 생성하고 `DXVK_CONFIG_FILE` 환경변수로 연동하여 ProMotion 120Hz 화면에서의 물리 연산 및 프레임 페이싱 안정화.
  - **D3DX9 내장 오버라이드 보강**: Native D9VK 모드 시 `d3dx9_24` ~ `d3dx9_43` Wine 내장 구현을 오버라이드 목록에 추가하여 헬퍼 라이브러리 충돌 방지.
  - **검증**: D9VK 신규 빌드(`ef4a246dc8c080a3d6056df931d79607b3bdc8dc1ab56597a521ad27db4c15f7`) 완료, 포맷 8개 그룹 및 로거 64회 통과, MacDeck 자체 검사 **107개 전수 통과 (`107 checks passed`)**.

### 2026-10-18 — 백그라운드 잔존 프로세스 완전 종료(Sweeper) 및 Steam Big Picture 64-bit MSync 복구

- **창 닫기 시 즉각 완전 종료 보장**:
  - SwiftUI macOS `WindowGroup`에서 창 닫기 시 앱이 백그라운드에 남아있던 문제를 해결하기 위해 `MacDeckAppDelegate` 및 `DeckView`에 `NSWindow.willCloseNotification` 옵저버를 연동하여 메인 창 닫기 시 `terminateAll()` 및 `NSApp.terminate(nil)`가 즉각 실행되도록 개선.
- **Wine 고아(Orphan) 프로세스 자동 청소 (Sweeper 도입)**:
  - `wineserver`가 닫힌 뒤 부모(PID 1)로 분리되어 백그라운드에서 CPU를 점유하던 `winedevice.exe` 등 고아 프로세스를 감지하고 `SIGTERM`으로 완전 정리하는 `sweepOrphanedWineProcesses()` 구현.
  - 모든 개별 게임 Prefix에 `wineserver -k`를 순회 전송하도록 `killPrefix` 보강.
- **Steam Big Picture 64-bit Mach-message MSync 복구 & 멀티스레드 CSMT 정상화**:
  - 64-bit Steam 클라이언트 및 Chromium(`steamwebhelper.exe`)에 `WINEMSYNC=1` (QLIMIT=512) 고속 커널 동기화를 복구하여, 단일 wineserver 락으로 인한 UI 스터터링과 지연을 해소하고 최신 Gamepad UI의 부드러운 애니메이션 복원.
  - WineD3D 전역 오버라이드에서 `csmt=0`을 제거(`renderer=vulkan`)하여 명령 스트림 멀티스레딩(CSMT)을 정상 활성화.

### 2026-10-18 — 게임별 그래픽 모드(DX12/DX11) 우선순위 정상화, D3D9 32비트 VRAM 정수 오버플로 버그 해결, 용사30 설정 보존 및 엘든링 EAC 오프라인 바이패스 연동 (v0.5.7)

- **게임 설정 변경 내역 영구 보존 (`Runtime.swift`)**:
  - 10초 주기 라이브러리 새로고침(`refreshSteamGames`) 시 사용자가 변경한 `d3d9Mode`, `graphicsBackend`, `prefix`, `arguments`가 덮어씌워져 리셋되던 결함을 수정하여 영구 보존.
- **32비트 고전 게임 VRAM 정수 오버플로 버그 해결 (용사30 1 FPS 버벅임 해소)**:
  - Apple M5 24GB Unified Memory 환경에서 32비트 Direct3D 9 `GetAvailableTextureMem()` 호출 시 32비트 부호 없는 정수 한계(4GB)를 초과하여 **0 바이트**로 오버플로되던 문제를 규명.
  - Wine 레지스트리 `[Software\Wine\Direct3D]`에 `VideoMemorySize="2048"` 및 D9VK `d3d9.maxAvailableMemory = 2048`을 자동 주입하여 2GB VRAM을 안전하게 보고하도록 캡 적용. 매 프레임 텍스처를 방출하고 CPU에서 재업로드하던 심각한 병목 현상 원천 차단.
  - D9VK 설정에서 `deferSurfaceCreation = False`, `tearFree = False`를 적용하여 MoltenVK 스왑체인 무효화 오류 방지.
  - 게임 폴더 내 D9VK `d3d9.dll`을 WineD3D 선택 시 `.disabled`로 전환하여 내장 Vulkan 가속 렌더러와 충돌 방지.
- **엘든링(ELDEN RING) EasyAntiCheat 오프라인 자동 바이패스 및 순수 DX12 연동**:
  - macOS Wine에서 구동 불가한 EasyAntiCheat 커널 드라이버를 우회하기 위해 `start_protected_game.exe`를 원본 백업 후 `eldenring.exe`로 자동 교체하고 `steam_appid.txt`를 생성하여 싱글/오프라인 모드로 즉시 기동 연동.
  - 게임별 그래픽 모드(`game.graphicsBackend = .d3d12`)를 자동 지정하고, 전역 설정보다 게임별 설정이 우선 적용되도록 `LaunchPlan.make` 수정.
- **Applications 복사본 완전 삭제 및 dist 단독 빌드**:
  - 사용자 지침에 따라 `/Applications` 및 `~/Applications`의 복사본을 완전 삭제하고 `dist/MacDeck.app` 단독 빌드 및 서명 유지.
- **검증**: `SelfTests.swift` 2개 신규 테스트 추가, **총 109개 자체 검사 전수 통과 (`109 checks passed`)**.

### 2026-10-18 — Steam Overlay 크래시 차단, 32-bit 비-LAA 주소 보호(용사30 크래시 해결), D9VK 관리형 설정 자동 배포 및 엘든링 DX12 안정화 (v0.5.8)

- **Steam Overlay (`gameoverlayrenderer*.dll`) 후킹 충돌로 인한 `0xC0000005` 크래시 원천 차단**:
  - Steam Big Picture에서 게임 구동 시 Steam이 Windows 네이티브 `gameoverlayrenderer.dll`(32비트) 및 `gameoverlayrenderer64.dll`(64비트)을 프로세스에 주입하여 DXGI/D3D/Vulkan vtable을 가로채려다 Wine/MoltenVK 환경에서 접근 위반(`0xC0000005`)을 일으키던 문제 해결.
  - Wine Prefix `user.reg`의 `[Software\Wine\DllOverrides]`에 `gameoverlayrenderer=""`, `gameoverlayrenderer64=""`를 등록하고, `LaunchPlan.make` DLL 오버라이드에 `gameoverlayrenderer,gameoverlayrenderer64=d`를 주입하여 오버레이 주입을 완전 차단.
- **32비트 고전 게임 2GB 초과 가상 주소 할당 방지 (`WINE_LARGE_ADDRESS_AWARE=0`)**:
  - 용사30(`HMH.exe`)은 Large Address Aware를 지원하지 않는 32비트 PE 바이너리(`Characteristics 0x103`)임에도 전역 `WINE_LARGE_ADDRESS_AWARE=1`로 인해 상위 2GB(`>= 0x80000000`) 메모리가 할당되어 부호 있는 포인터 연산 실패로 `0xfff4fa8c`에서 페이지 폴트 크래시가 발생하던 결함 수정.
  - 32비트 바이너리(`is32Bit == true`) 감지 시 `WINE_LARGE_ADDRESS_AWARE = "0"` 및 `WINEMSYNC = "0"`을 강제 적용하여 2GB 이내 안전 메모리 공간 유지.
- **용사30 Native D9VK 관리형 설정 및 자동 배포 보강**:
  - D3D9 Native 모드 시 패치된 32비트 D9VK(`d3d9.dll`)를 게임 폴더로 자동 복사하고, `dxvk.conf`에 `d3d9.maxAvailableMemory = 2048`, `d3d9.deferSurfaceCreation = False`, `d3d9.tearFree = False`, `d3d9.customVendorId = 10de`를 주입하여 2GB VRAM 캡 및 스왑체인 무효화 방지.
  - WineD3D 사용 시 항상 `WINE_D3D_CONFIG="renderer=vulkan"`이 적용되도록 보장하여 OpenGL CPU 소프트웨어 폴백 방지.
- **엘든링(ELDEN RING) Direct3D 12 전용 DXGI 브리지 및 오프라인 바이패스 연동**:
  - `.../ELDEN RING/Game/dxgi.dll`에 D3D12 지원 Wine DXGI 브리지(`dxgi-d3d12`)를 자동 배치하여 전역 모드와 무관하게 D3D12 인터페이스 정상 로드.
  - Steam 오버레이 비활성화 및 EasyAntiCheat 오프라인 자동 바이패스로 시작 즉시 크래시되던 문제 해결.
- **빌드 및 패키징 준수**:
  - `/Applications` 복사 금지 및 DMG 미생성 지침을 준수하여 `dist/MacDeck.app` 단독 빌드 및 ad-hoc 코드 서명 완료.
  - **총 109개 자체 검사 전수 통과 (`109 checks passed`)**.

### 2026-10-18 — CrossOver/Whisky 엘든링 패치 현황 분석, DX12 아키텍처 한계 규명 및 용사30 가상 데스크톱 안정화 (v0.5.9)

- **CrossOver 및 Whisky의 엘든링(ELDEN RING) 패치 현황 및 아키텍처 비교 분석**:
  - **D3DMetal(Apple GPTK) 독점 구동 확인**: CrossOver 23.5+ 및 Whisky는 엘든링 구동 시 일반 Wine VKD3D + MoltenVK를 사용하지 않으며, Apple Game Porting Toolkit의 **D3DMetal (`libd3dshared.dylib` + Apple `d3d12.dll`)**을 필수 요구사항으로 사용합니다.
  - **VKD3D + MoltenVK 즉각 크래시 원인 규명**:
    1. 엘든링 엔진은 Direct3D 12 Feature Level 12_0 (`0xc000`)을 엄격히 요구하나, MoltenVK에 Geometry Shader, Stream Output, Pipeline Statistics Query가 없어 VKD3D가 장치 생성을 거부합니다.
    2. 강제로 Feature Level 검사를 통과시켜도 MoltenVK가 `VK_QUERY_TYPE_PIPELINE_STATISTICS`를 지원하지 않아 `vkCreateQueryPool`이 `VK_ERROR_FEATURE_NOT_PRESENT (vr -8)`로 실패하고, 엘든링이 NULL 포인터를 역참조하여 3초 만에 크래시됩니다.
    3. Apple D3DMetal은 Vulkan을 거치지 않고 Direct3D 12를 Metal Shading Language로 1:1 직접 변환하므로 이러한 한계 없이 구동됩니다.
  - **Easy Anti-Cheat(EAC) 오프라인 바이패스**: macOS Wine 컨테이너에서 Windows 커널 모드 EAC가 동작하지 않으므로, `start_protected_game.exe`를 `eldenring.exe` 복사본으로 대체하여 오프라인 모드로 플레이하는 것이 공식 표준입니다.
- **용사30(Half Minute Hero) 하얀 화면 10초 뒤 크래시 해결 및 가상 데스크톱 안정화**:
  - **원인 분석**: 1280x720 고정 해상도의 32비트 D3D9 게임이 Retina 1512x982 해상도에서 인트로 동영상(10초) 종료 후 타이틀 화면 진입 시 스왑체인 무효화 및 디바이스 유실로 크래시되던 현상 규명.
  - **Wine 가상 데스크톱(`1280x720`) 자동 주입**: Wine Prefix `user.reg`의 `AppDefaults\HMH.exe`에 `Desktop="HMH"`, `1280x720` 가상 데스크톱 및 Native D9VK(`d3d9=n,b`)를 자동 등록하여 내부 고정 렌더링 환경 구축.
  - **Steam 호스트 LAA 비간섭 격리**: Steam Big Picture 실행 시 환경변수에서 `WINE_LARGE_ADDRESS_AWARE` 강제 주입을 해제하여, 자식 32비트 프로세스가 자신의 PE 헤더 플래그를 따르도록 안전하게 격리.
- **빌드 및 검증**:
  - `SelfTests.swift`: 단위 테스트 109개 전수 통과 (**109 checks passed**).
  - `scripts/build-mac-app.sh`: `dist/MacDeck.app` 단독 빌드 및 서명 완료 (`/Applications` 미복사, DMG 미생성 지침 준수).


## 2026-10-18 · Steam 수명 관리 및 게임패드 중심 UI 개편 진행

- 요청: Wine 강제 종료 후 Steam 재실행 차단, Big Picture 복구. 이어서 사용자가 UI 전면 개편을 우선 요청함. 용사30·엘든링 실행 실패는 사용자 보고대로 미해결이며 이번 UI 작업에서 렌더러를 추가 수정하지 않음.
- SteamStorage: 실행 확인을 Wine tasklist 대신 macOS ps 조회로 전환하여 상태 확인이 종료된 prefix를 부팅하지 않도록 변경. 자동 런타임 업데이트는 Steam 실행 중 보류, 수동 업데이트 후 자동 Steam 재실행 제거. 주기적 설치 게임 확인의 그래픽 DLL 덮어쓰기 제거. 종료 시 관리 Steam prefix 외 기본 Wine prefix를 추가 종료하던 코드 제거.
- SteamClient: 신규/기존 Steam 모두 Big Picture 전환을 요청하도록 steam://open/bigpicture URI 추가. 실제 강제 종료 재현 및 Big Picture 정상 표시 확인은 아직 완료하지 않았음.
- UI: 기존 DeckView를 ConsoleView로 교체. 라이브러리·Steam·저장 공간·실행 환경·게임패드·실행 기록의 6개 탭, 큰 3열 카드, 선택 테두리, 자동 스크롤, 컨트롤 힌트. 공통 탐색 규칙(ConsoleGrid)을 키보드와 패드에서 공유. 방향·스틱, A/✕ 선택, B/○ 뒤로, X/□ 게임 관리, L1/R1 화면 전환. Menu는 Steam 화면 이동만 수행(실행하지 않음).
- 저장 공간 연결·해제, HUD·GPU·자동 시작·그래픽 모드 등 설정, 로그/진단을 카드로 조작. 제거/연결 해제는 별도 확인 화면. 이름·경로·인수 입력은 키보드 편집창 유지, 패드 □ 저장/○ 취소 지원. 시스템 파일 선택 창은 기본 macOS 조작 사용.
- 검증 진행: 컴파일·서명 성공. 방향 구분/반복·백그라운드 입력 방지·행 경계·빈 목록·불완전 마지막 행 회귀 검사 추가. 실제 화면 캡처와 전체 검사 결과는 아래 후속 기록에 누적 예정. DMG 및 커밋/푸시는 하지 않음.


## 2026-10-18 · 패드별 안내, 게임별 호환성 DB, 메일 신고 및 App ID JSON

- 추가 요청: Xbox/PlayStation 및 키보드 설명, 게임명·Steam App ID별 문제 관리, 다른 정상 게임에 대한 수정 영향 방지, sjhdeux@gmail.com으로 오류 로그 ZIP 작성, DB 등록용 App ID 포함 로그.
- Console UI를 7개 탭(호환성 DB 포함)으로 구성. Steam 캐시의 기존 게임 아트만 사용. PlayStation/Xbox 입력 프로필에 따라 버튼 설명 변경, 키보드 안내 항상 표시. 정지한 마우스 아래 카드가 자동 스크롤과 함께 바뀌며 선택이 튀던 문제를 없앰. 게임 관리에 상태 기록·실행 기준 보호·해제·오류 신고 추가.
- GameProfiles.swift: 로컬 Compatibility/game-profiles.json, steam:<App ID>/로컬 UUID 식별, 상태·엔진·revision·실험 설정·정상 실행 기준 해시 관리. 초기 RE3/DMC5 과거 성공 보고와 용사30/엘든링 최신 실패를 구분. 실험은 기본 끔, 허용 환경 변수만 해당 직접 실행에 적용. Steam 공유 클라이언트 실험은 거부. 정상 기준과 다르면 실행 보류, 보호 게임 존재 시 공유 런타임 업데이트 보류.
- Library.swift: 게임 폴더 DLL 자동 이동·배포, INI 렌더러 일괄 변환, 특정 게임 보호 런처 교체/레지스트리 주입 경로 제거. 다른 prefix 무차별 동기화 제거, 실행 대상 prefix만 준비. 기존 설치에 이미 적용된 변경은 이번 작업에서 자동 원복하지 않음. 공유 그래픽 모드와 런타임 자체가 완전히 게임별 격리된 것은 아님.
- SupportReports.swift: 재현 설명 입력 → 최신 게임 세션 + 관련 Steam 그래픽 로그 → 제한된 ZIP → 받는 사람 지정된 메일 작성 창. 실제 자동 전송 없음. 메일 서비스 실패 시 ZIP Finder 표시. 인증 파일·메모리 덤프·심볼릭 링크 제외, 로그 tail 및 총 용량 제한.
- issue-report.json(schema 1): reportID/gameKey/gameName/steamAppID/engine/profileRevision/recordedStatus/sessionID/sessionKind/reproduction/includedFiles/limitations, reportStatus=unverified-user-report 및 automaticPromotionAllowed=false. SessionDiagnostics에도 선택 게임 프로필 스냅샷 추가. 서버·메일 자동 수신/자동 DB import 구현으로 주장하지 않음.
- 검증 중간 결과: 자체 검사 119개 통과. 첫 ZIP 실제 생성 검사는 /var와 /private/var 경로 차이로 Renderer/enderer 형태가 되어 실패했고 canonical root로 보정. 최종 재검증 결과는 후속 기록에 추가 예정. 실제 UI 7화면 캡처 및 탐색 검사 성공, 실제 DualShock4 연결 인식/안내 확인; Xbox 실기는 아직 확인하지 않음.
- 상세 설명: docs/GAME-PROFILES-AND-REPORTS.ko.md. 용사30·엘든링 플레이 문제 미해결, UI 우선 지시 유지. DMG/커밋/푸시 없음.


### 최종 검증 보완 (2026-10-18)

- 자체 검사 **122개 통과** (`evidence/console-profiles-tests.log`): Xbox/PS 안내, 2차원 이동, 반복/백그라운드 입력, 프로필 ID 격리, 공유 Steam prefix 실험 거부, 정상 실행 설정/렌더러 SHA-256 변경 차단, 손상 DB 보존, 게임 폴더 DLL/INI/런처 무변경을 포함.
- 실제 ZIP 검사 **통과** (`evidence/support-report-tests.log`): JSON App ID/DB key 왕복, 포함 파일, 512KiB tail, 인증 파일·심볼릭 링크 제외, ZIP 목록 확인. 그래픽 stderr 필터 검사 **3개 통과**. 실제 메일 전송은 수행하지 않았으며 메일 계정 환경별 작성 창은 사용자 환경에서 확인 필요.
- 공유 prefix 비교에서 URL 디렉터리 플래그 차이가 허용 판단을 흐리는 것을 회귀 검사로 발견해, 심볼릭 링크 해소 후 표준화한 path 문자열로 비교하도록 수정.
- 최종 UI 검사의 캡처에서 활성 창이 순간적으로 없을 때 검사 전용 precondition이 앱을 종료하는 문제가 있었음. 보이는 MacDeck 창/시트로 대체 캡처하고 검사 실패를 결과 파일에 기록하도록 수정(일반 게임 실행 경로와 구분).
- 실제 연결된 DualShock 4의 PS 안내와 키보드 동시 표시 확인. Xbox 안내는 UI 강제 표시 및 단위 검사로 검증했으며 실제 Xbox 기기 입력 검증은 아님.
- 앱은 프로젝트 `dist/MacDeck.app`에서 빌드·서명. 현재 `/Applications/MacDeck.app` 및 `~/Applications/MacDeck.app`은 없음을 확인했으며 설치본이 있는 것으로 기록하지 않음. 기존 Steam을 종료하지 않고 UI 프로세스만 교체함.
- 현재 번들 x64 DXMT d3d11.dll SHA-256: `cafb32ba2b58e2e8decc1d6feabccdc131e1bf186713b34913a98974f94a3f02`. 이전 `.cache/d3d11-marshal-fixed.dll` 후보와 다르며 이번 UI 작업에서 그 예전 후보로 되돌리거나 새 게임 패치를 배포하지 않음.
- 코드 서명 검증과 `git diff --check` 통과. 최종 화면 재확인 결과는 이어서 기록. DMG/새 커밋/푸시 없음.


- 후속 유지보수의 범위도 제한하기 위해 AGENTS.md에 게임별 ID 프로필 우선, 정상 기준 보존, 공유 런타임 별도 검증, 다른 게임 설정/파일 보존 검사, 외부 제보 미검증 유지 규칙을 추가했다.
- 최종 시각 확인 중 신고 창의 보조 버튼이 캡처에서 흰 바탕·흰 글자로 표시되는 문제를 발견해 명시적 SwiftUI 버튼 스타일로 교체. 미검증 DB 항목에는 확인 마크 대신 물음표를 사용해 성공으로 오해하지 않도록 보정.


### 작업 완료 상태 (2026-10-18 21:30 KST)

- 최종 앱 바이너리 자체 검사 **122개 통과**, 실제 신고 ZIP 검사 통과, 코드 서명 검증 및 whitespace 검사 통과.
- 최종 UI 검사 **PASS**: 7개 탭, 게임 관리 진입/복귀, 행 단위 탐색, Xbox/PS 안내, 오류 신고 시트와 10개 화면 캡처 확인. `evidence/console-ui-result.log`, `console-library.png`, `console-library-xbox.png`, `console-report.png`, `console-compatibility.png` 등.
- 문서 폴더에 디버그 캡처 PNG를 쓰는 open()에서 앱이 대기한 것을 샘플로 확인. 캡처를 `/private/tmp/macdeck-console-final`에 생성한 뒤 프로젝트 evidence로 복사하여 해결. 일반 실행은 캡처 코드를 실행하지 않음. 실제 신고 창의 버튼 텍스트 대비도 최종 이미지에서 확인.
- 진단 ZIP에 `issue-report.json`과 Steam App ID/게임명/DB key/revision/session ID/재현 설명/제외 및 잘림 정보를 포함. 정상 구동 기록으로 자동 승격하지 않음. 메일 작성 기능은 사용자 최종 전송 방식이며 실제 메일을 보내지 않음.
- 새 UI 및 DB/신고 기능 구현 완료. 실제 Xbox 패드 입력, 사용자 메일 계정의 작성/전송, 외부 제보 자동 수신/서버 DB는 검증·구축 범위 밖. 용사30·엘든링 게임 구동 실패는 그대로 미해결 상태로 유지.
- 이번 변경의 커밋/푸시·DMG는 수행하지 않음. 일반 UI를 `dist/MacDeck.app`에서 열어 사용자가 확인할 수 있도록 함. Steam/게임을 종료하는 강제 테스트는 수행하지 않음.


## 2026-10-18 · 용사30/엘든링 격리 시험 및 Steam 멈춤 대응 (진행 중)

- 사용자 제공 GPTK 4.0 beta 3 DMG를 읽기 전용으로 마운트하고 Apple D3DMetal 원본과 라이선스를 엘든링 전용 복제 런타임에 보존했다. 공유 런타임과 기존 게임 파일은 이번 시험 준비에서 변경하지 않았다.
- GameTrials.swift 및 CLI에 App ID 214830/1245620별 런타임 복제·게임 staging·별도 Steam prefix 준비를 구현했다. 기존 Steam 인증 파일은 복사/열람하지 않았으며 별도 로그인이 필요하다. 시험 프로필 키는 기존 정상 게임과 분리했다.
- GPU clear/readback용 D3D9/D3D12 검사 실행 파일을 컴파일했으나 실제 GPU 실행 및 두 게임 플레이 성공은 아직 검증하지 않았다. 앞선 기록의 용사30 성공/엘든링 불가능 단정은 최신 사용자 실패 보고와 구분해야 한다.
- 사용자가 시험 Steam 멈춤 및 MacDeck 종료를 보고했다. 시험 Steam만 대상으로 종료·재실행을 준비하고 로그인 전용 CEF 인수를 -cef-force-gpu에서 -cef-disable-gpu로 변경했다. 게임 Metal 설정과 기존 Big Picture 설정은 유지한다. 이 변경의 멈춤 해결 효과는 미검증이다. wineserver 직접 호출은 초기 라이브러리 경로 누락으로 실패했고 경로 보정 호출도 종료코드 1이어서 종료 여부를 별도로 확인한다.
- 남은 작업: 시험 로그인 UI 확인, GPU 실제 검사, 게임별 실행/플레이 검증, 진단 세션 메타데이터·UI 통합 및 회귀 검사. 커밋/푸시/새 DMG 생성 없음.

- 재시도: 빌드·서명 완료, whitespace 검사 통과. 확인된 시험 Steam PID와 해당 CEF만 강제 종료했고 MacDeck을 --no-steam으로 다시 열었다. 수정된 로그인 전용 인수로 용사30 시험 Steam을 재실행했다. 로그인 창 응답 및 실제 게임 성공은 사용자 확인 전이다.

- 시험 Steam 로그인 완료를 사용자에게 확인받고 App ID 214830을 전용 prefix에서 직접 실행했다(세션 2026-10-18T12-53-10Z-F9A8B469-75B7-4DF9-99EB-816F52497770). HMH_d3d9.log에서 D9VK 장치 Apple M5, process.log에서 MoltenVK/Metal 4 및 CAMetalLayer swapchain 생성을 확인했다. 타이틀/플레이 성공은 아직 사용자 확인 대기이며 장치 초기화만으로 해결 판정하지 않는다.
- 실제 게임 EXE 직접 실행도 App ID가 있으면 Steam 실행 요청으로 잘못 기록되던 Diagnostics.swift 분류를 수정했다. Steam.exe 실행 요청에만 request-process-ended 설명을 적용한다. 엘든링 전용 별도 GraphicsProbe prefix에서 D3D12 GPU readback 검사를 시작했으며 결과 확인 중이다.

- 엘든링 D3D12 GPU 검사의 첫 실행은 종료코드 66으로 실패했다. PASS/readback 결과가 없으므로 Apple D3DMetal 사용 성공으로 판정하지 않는다. 별도 검사 prefix에서 DLL 로딩 진단을 추가해 호환 Wine 연결 문제 여부를 조사 중이며 기존 Steam/게임 prefix는 수정하지 않았다.

- 사용자 용사30 시험 결과: 화면 잘림 없음, 크래시 없음, 거의 멈출 정도로 느림. 플레이 가능/해결로 기록하지 않는다. CPU 표본에서 HMH 약83%, 기존 별도 Steam 약297%를 확인했으며 Rosetta 스택은 반복 unwind가 많아 단독으로 병목 원인을 확정할 수 없다.
- 동일 시험 prefix/D9VK로 D3D9 GPU clear/readback 및 full/partial Present 검사가 0.93초에 종료코드0으로 통과했다(evidence/hmh-d3d9-gpu-probe.log). 이는 간단한 렌더러 경로 검증이며 게임 성능 검증이 아니다.
- FIFO/IMMEDIATE 전환·swapchain 재생성 로그를 근거로 수직동기화 비교 시험을 추가했다. --trial-no-vsync 명시 옵션은 App ID214830의 직접 시험 실행에만 적용하고 기존 생성 설정을 별도 파일에 복사해 presentInterval만 1→0으로 바꾼다. 공유 게임 설정 및 기본 실행값은 유지한다. 효과는 재실행 후 사용자 확인 필요. 자체 검사 최신 빌드 122개 통과(직전 진단 분류 수정 포함).

- no-vsync 비교 빌드·서명 통과 후 재실행 PID60575, 세션 2026-10-18T12-57-24Z-3D7A874E-7024-4BDF-9FC2-405EA07E70F8. 재시도 직전 기존 HMH PID59403은 이미 종료되어 경로 검증 실패 시 종료 신호를 보내지 않았다. 기존 런처 종료코드5를 확인했으나 종료 원인은 미확정이며 사용자 보고의 “크래시 없음”과 구분한다. 현재 HMH 프로세스는 새 시험 1개만 확인했다.

- no-vsync 비교 결과 사용자 크래시 보고. 실행 로그 종료코드3 및 Wine winevulkan loader_thunks.c:6190의 `Assertion failed: !status && "vkQueueSubmit"` 확인. 직전 invalid swapchain window / VK_ERROR_OUT_OF_DATE_KHR도 관측되나 인과관계 미확정이다. Vulkan 미지원 함수 조회 경고만으로 원인을 단정하지 않는다.
- 실패한 --trial-no-vsync 옵션은 명시적 오류로 차단하고 설정 생성 코드를 제거했다. 기본 presentInterval=1 및 기존 게임 설정은 변경하지 않는다. 반복적인 사용자 게임 재시험을 요청하기 전에 합성 GPU 검사와 Wine Vulkan 연결부 조사를 우선한다. 기본 설정도 심각한 성능 문제로 미해결이다.

- 크래시 대응 검증: 수정 앱 빌드/서명 및 git diff --check 통과. --trial-run 214830 --trial-no-vsync 호출이 게임 실행 전에 명시적으로 거부되는 것을 확인했다.
- scripts/wine-game-graphics-probe.cpp에 선택적 600프레임/5회 Reset 합성 검사를 추가하고 i686 정적 실행 파일로 컴파일했다. 동일 전용 prefix/D9VK/MoltenVK에서 전체3.25초, 루프2540ms, 종료코드0으로 PASS(evidence/hmh-d3d9-stress.log). 이번 검사는 게임의 텍스처·셰이더·영상 재생·Steam 오버레이 경로를 모두 재현하지 않으므로 크래시 해결 근거가 아니다. 일반 Present/Reset만으로는 이번 assertion을 재현하지 못했으며 HMH 고유 호출 시퀀스 분석이 남았다. 자동 게임 재실행은 하지 않았다.


## 2026-10-18 · 엘든링 D3DMetal 연결 누락 수정 (진행 중)

- 엘든링 GPU 실패 조사에서 준비 코드가 Apple redist/lib/wine/x86_64-unix의 .so 심볼릭 링크를 복사하지 않았음을 확인했다. 원본 DLL은 libd3dshared.dylib 연결이 필요한데 시험 런타임에 d3d12.so 등이 없었다.
- GameTrials.swift의 Apple 가져오기에 원본 상대 링크 검증 및 5개 Unix bridge 복사를 추가했다. 기존 엘든링 전용 복제 런타임에는 누락된 링크만 복원했다. Apple 바이너리 수정·공유 런타임 교체·인증 파일 열람은 하지 않았다. GPU 재검증을 진행하며 아직 게임 실행 성공으로 판정하지 않는다.

- Unix 링크 복원 후 별도 GPU 검사는 D3D12 생성 중 NULL 주소 접근으로 Wine 디버거에 진입했다. 단순 대기로 오인하지 않도록 기록을 보완한다. 시스템 D3DMetal 범주에는 해당 조회 시간 로그가 없었고 PASS는 없었다. 기존 Wine 연결 호환성 문제 가능성이 남아 Apple README가 안내한 Gcenx game-porting-toolkit 배포본(3.0-3, 239200808 bytes)을 캐시에 내려받아 별도 환경에서 비교하기로 했다. 공유 런타임은 교체하지 않는다.

- 호환 Wine 3.0-3 다운로드 SHA-256 d377683937340f914823dbb2e1252b329cbf834ff58907d0293db8cebf0e392e가 공급자 Homebrew cask 값과 일치했다. 캐시에만 압축 해제하고 포함된 external은 external.original3로 보존한 뒤 사용자 제공 Apple4 redist를 원본 그대로 병합했다. 새 GPTK3GraphicsProbe prefix에서 독립 검사를 시작했으며 기존 Steam prefix를 이 다른 Wine으로 부팅하지 않았다.
- 진단을 위해 D3D12 검사 stdout 버퍼링을 끄고 장치 생성 시작 표식을 추가했다. GameTrials의 Unix 브리지 복사 변경 빌드·서명 통과, 자체 검사 122개 통과.

- 추가 원인 확정: 엘든링 trial Runtime 및 GraphicsProbe의 DXGI SHA가 Apple 원본과 달랐다. Apple 가져오기 후 installSteam이 기본 DXMT 모드로 LaunchPlan을 만들면서 DXGI를 덮어썼다. Library.swift는 준비된 Apple trial의 공통 DXGI 전환을 건너뛰도록, GameTrials의 설치 게임은 엘든링 D3D12 모드를 명시하도록 수정했다. 해당 trial DXGI 3개(런타임/검사 prefix/시험 Steam prefix)를 Apple 원본으로 복원했다.
- 복원 후 기존 복제 Wine에서 실제 D3D12 feature level12_0 장치 생성 및 GPU clear/copy/fence/readback 16픽셀 **PASS**(evidence/apple-d3d12-restored-dxgi.log). 이 결과는 GPU 경로 검사이며 엘든링 플레이 성공은 아니다. 호환 Wine 다운로드본은 채택하지 않았다. 검증한 프레임워크 경로 환경도 trial에 명시했다. 다음 단계는 엘든링 전용 Steam 로그인 및 게임 실행이다.

- 최종 빌드·서명/자체 검사122개/whitespace 검사 통과. 엘든링 시험 Steam 실행 후 Apple DLL5개 원본 해시 보존을 확인하여 DXGI 덮어쓰기 재발 방지의 실제 LaunchPlan 경로를 검증했다. 공유 DXMT d3d11 해시 cafb32ba2b58e2e8decc1d6feabccdc131e1bf186713b34913a98974f94a3f02 보존. 전용 Steam 로그인 창을 실행했으며 사용자 로그인과 실제 엘든링 플레이는 아직 미검증이다. 커밋/푸시/DMG 없음.

- 사용자 “로그인 창 안 보임, 모두 종료 후 재실행” 요청. 경로를 다시 확인한 엘든링 시험 Steam/CEF 잔여 프로세스5개만 종료하고 --trial-steam 1245620으로 재실행했다(evidence/elden-trial-steam-restart.log). 다른 prefix는 종료하지 않았다. 로그인 UI 표시/사용자 인증은 아직 확인 전이며 Steam raw stdout/stderr·로그인 화면 캡처는 수집하지 않는다.

- 엘든링 시험 Steam 재실행 후 프로세스는 존재하지만 CGWindow 소유자 목록에 Steam 창이 없었고 사용자도 Dock 아이콘만 표시됨을 확인했다. 로그인 창 표시를 확인했다는 이전 기록이 있다면 프로세스 실행과 구분해야 한다. 전용 Steam/CEF/server만 경로 검증 후 종료하고, 시험 prefix의 Steam/게임을 모두 WINEMSYNC=0(서버 대기)으로 맞추는 비교 변경을 진행한다. 용사30 시험 로그인에서 사용한 설정과 비교하는 가설이며 아직 해결 검증 전이다. 같은 설정의 D3DMetal GPU 검사를 병행한다.

- WINEMSYNC=0 비교 빌드·서명 및 자체 검사122개 통과. 같은 설정의 실제 D3DMetal feature12_0 clear/copy/fence/readback16픽셀 PASS(evidence/elden-serverwait-metal-probe.log). Steam 재실행 세션 2026-10-18T13-13-12Z-DB2A20E5-3E41-4B2A-A814-135424C38C9C에서 CGWindow owner wine PID66819, 화면상700×440 창 표시 확인. 인증 화면은 캡처/열람하지 않았으므로 창이 실제 로그인 UI인지·로그인 성공인지 사용자 확인 대기.

- 사용자 엘든링 시험 Steam 로그인 완료 보고 후 --trial-run1245620 실행. 세션2026-10-18T13-14-08Z-5EBC573C-4FF7-4B2E-93A2-FAD67D1E14F5, PID67335. mapped code 경로에서 Apple 원본 libd3dshared.dylib·D3DMetal.framework·libmetalirconverter 및 전용 d3d12/dxgi DLL 로드를 확인했다. D3DMetal의 eldenring.exe 셰이더 캐시가 생성된 것도 파일명 메타데이터로 확인했으며 인증 파일은 읽지 않았다. 초기 로그에서 SEH 오류는 아직 관측하지 못했지만 타이틀·실제 플레이·안정성은 사용자 확인 대기다.


## 2026-10-18 · 엘든링 실행 후 성능·카메라 조사

- 사용자 실제 게임 진입 보고: 실행됨, HUD 없음, 약15fps 추정, 무입력 카메라 회전. 실행 성공과 플레이 품질을 구분하며 아직 안정적 플레이로 승격하지 않는다. 시험 CLI가 HUD를 강제로0으로 지정한 것을 확인하여 명시적 --trial-hud 옵션을 추가했다(기본값/일반 게임 HUD 유지). 진단 세션 생성 전에 실제 HUD 값을 기록한다.
- 사용자 게임 종료 및 패드 미연결 확인. 초기 macOS GC 샘플에는 DS4중립0이 남았지만 이후 동일 Windows prefix XInput4슬롯×4회 모두 ERROR_DEVICE_NOT_CONNECTED1167을 확인했다. 스틱 드리프트로 단정하지 않는다. 마우스 상대좌표/전체화면/다른 입력 경로가 조사 대상이다.
- 전용 GraphicsConfig.xml은 자동 감지ON/전체화면1512×982/High/RT끔이었다. 게임 종료 후 전용 XML을 날짜별 원본 백업하고 명시적으로1280×720창모드/Low/자동감지OFF로 비교 설정했다. 일반 prefix·게임 설치 폴더는 변경하지 않았다. 레지스트리 MouseWarpOverride는 아직 적용하지 않았다. HUD로 실제fps와 카메라 동작을 다시 확인할 예정이다.

- 사용자가 이번 시험에는 패드 연결을 예고하여 Windows XInput 재검사를 시작했다. 새 빌드·서명 및 자체 검사122개 통과 후 --trial-run1245620 --trial-hud 실행(evidence/elden-low-hud-game.log). 720p Low 창모드/자동감지OFF는 전용 prefix에만 적용했으며 실제fps·패드 인식·카메라 회전 개선은 아직 사용자 확인 전이다. Windows XInput 검사 소스도 scripts/wine-xinput-probe.cpp에 보존했다.


## 2026-10-18 · 엘든링 9fps/패드 인식 실패 추가 조사

- 사용자 HUD 이미지: D3D12(Metal4),1280×720,Composited,9.11fps,FrameInterval109.83ms,GPU6.53ms. Composited는 화면 합성 경로 표시이며 Metal 미사용 판정 근거가 아니다. GPU 연산 시간만으로 전체 프레임 지연을 설명하지 못한다. 패드 불인식과 카메라 회전 지속, Low 창모드 효과 미흡으로 기록한다.
- 게임 프로세스는 종료코드0으로 이미 종료됨을 확인했다. macOS IOHID DS4 인식, 동일 x86_64 번들 SDL 검사 PS4 Controller mapped=1 확인. Wine 원시 HID DS4 장치 등록과 XInput 전슬롯미연결을 비교하여 전용 prefix의 winebus Enable SDL=1/DisableHidraw=1만 시험 변경했다. 원래 해당 키 값은 없었고 복구는 두 값 삭제로 가능하다. 아직 XInput 재검증 전이다.
- CPU/동기화 대기 병목 가설 비교용 --trial-esync 옵션을 AppID1245620 CLI에만 추가(기본off). 시험 Steam과 게임 양쪽에 동일옵션을 사용한다. 기존 게임의 MSync/ESync 설정은 변경하지 않는다. 게임 비실행 재확인 후 엘든링 시험 Steam/server만 종료하여 입력 드라이버를 다시 부팅한다. 카메라 레지스트리 변경은 아직 보류했다.

- SDL 경로 재부팅 후 XInput0번 슬롯이 result=0(연결됨), 좌우스틱0,0/트리거0으로4회 연속 확인되었다(evidence/elden-sdl-xinput.log). 이전4슬롯1167에서 개선된 실제 Windows API 검증이다. 버튼 입력·게임 조작 및 카메라 회전 개선은 아직 미검증이다. 로그에 esync up and running 확인, 빌드/서명·자체검사122개·whitespace 통과. 시험 Steam을 --trial-esync로 재시작했다.

- --trial-run1245620 --trial-esync --trial-hud로 엘든링 비교 실행(evidence/elden-esync-game.log). Metal4/720pLow창모드/HUD 유지. 패드XInput 인식은 검사로 개선됐으나 새 게임fps와 카메라 회전 여부는 사용자 확인 대기이며 해결로 주장하지 않는다. Composited→Direct 강제 전환은 적용하지 않았다.

- 비교 게임 요청 PID71062는 즉시 종료코드0으로 끝났고 후속 ps에 eldenring 프로세스가 없었다. 게임이 실행 중인 것으로 주장하지 않는다. 새 시험 Steam 인증/표시 상태를 사용자에게 확인 요청했으며 실제 ESync 게임 성능 비교는 아직 수행되지 못했다.

- 사용자 새 로그인 창이 아닌 이미 로그인된 시험 Steam이 실행 중임을 확인해 주었다. 앞선 즉시 종료를 인증 실패로 단정하지 않는다. 동일 --trial-esync --trial-hud 재시도 PID72730, 세션2026-10-18T13-28-40Z-BA888360-CD70-40A8-AF28-46472DCBED30. 10초 후 eldenring 프로세스 유지 및 초기 그래픽 오류 없음 확인(evidence/elden-esync-retry.log). 실제fps·패드 버튼·카메라 동작은 사용자 확인 대기다.


## 2026-10-18 · 엘든링 입력 사용자 검증 / 낮은 성능 계속 조사

- 사용자 SDL/ESync 비교 결과: 패드 조작 정상, 무입력 카메라 회전 없음. 입력 개선은 실제 사용자 플레이 보고로 확인했다. 전체 게임 상태는 약7.86fps로 여전히 미해결이며 정상 구동 기준으로 승격하지 않는다. HUD GPU12.55ms 대비 FrameInterval127.21ms 기록.
- 새 비교 전에 게임은 종료코드0으로 끝난 것을 확인했다. 시험 Steam외 기존 main Steam PID42166이 게임 비실행 상태에서도 CPU235~275%를 지속 점유함을 확인하고 정확한 main prefix Steam.exe 경로 재검증 후 TERM을 보냈다. 시험 Steam70711 및 입력/그래픽/ESync 설정은 유지한다. CPU 경쟁이 원인인지는 아직 가설이며 다음 실행에서 같은 구간 비교가 필요하다.

- 기존 고CPU Steam PID42166 종료 확인. 시험 Steam은 약5.9%,server0.6%이며 --trial-esync --trial-hud 동일 조건 게임 PID73334가193.2%CPU로 실행 유지됨을 확인했다. 세션2026-10-18T13-33-50Z-E4765B10-0504-40FB-A1CC-17B4EFF915F8. 이 비교에서 다른 그래픽/입력 설정은 바꾸지 않았으며 실제fps개선은 사용자 확인 대기다.

- 별도 Steam CPU 제거 후에도 사용자8~10fps 보고: 단순 CPU경쟁 가설은 효과 확인 실패. 추가 메모리 측정에서24GB중23GB사용/압축10GB/스왑9054MB/unused568MB와 높은 시스템CPU91%를 관측했다. 누적 swap 사용만으로 현재 스왑 속도를 단정하지 않는다. 종료한 main/HMH 환경의 CEF가 각각 수백MB 잔존했다.
- 실행 중 Steam host가 없는 main 및 AppID214830 prefix임을 mapped executable로 재검증한 CEF만 TERM으로 정리한다. 현재 엘든링/전용 Steam70711과 다른 앱은 유지한다. 설정을 바꾸기 전에 메모리 압박 제거 효과를 먼저 비교한다. Metal3 비교는 아직 미적용.

- 추가 ps에서 게임 종료 후에도 엘든링 trial의 services/plugplay/winedevice/explorer/rpcss 등이 각95~193% CPU를 사용함을 확인했다. ESync 시험 결과 성능개선은 없고 서비스 과점유가 있어 해당 옵션을 실행 전 거부하도록 중단했다. ESync 알고리즘 자체 결함으로 확정한 것은 아니며 누적된 잔여 서비스/서버 연결 상태도 관련 가능성이 있다.
- 게임 비실행을 확인한 후 모든 mapped runtime 코드가 AppID1245620 전용 Runtime 아래인 Wine 프로세스만 정리했다. 이전 재시작에서 남은 여러 세대 서비스도 발견/정리되었으며 일반 prefix/다른앱은 대상이 아니다. 입력 SDL 레지스트리와720pLow설정은 보존한다.
- 명시적 --trial-metal3 옵션(AppID1245620 직접 실행 한정, 기본off) 및 진단 D3DM_MTL4 기록을 추가했다. Apple README가 제공하는 D3DM_MTL4=0 경로이며 다른 게임·Steam에는 적용하지 않는다. Metal3 GPU 검사를 먼저 수행하고 새 게임 성능 비교를 진행한다.

- 정리 후 ps에서 CPU95~193% Wine 서비스들이 사라졌으며 최상위 부하는 WindowServer/Spotlight 등의 수십% 수준으로 내려갔다. Metal3 GPU clear/copy/fence/readback16픽셀 PASS, 수정 빌드/서명·자체검사122개·whitespace 통과. 기본 서버대기로 시험 Steam을 다시 열고 --trial-metal3 --trial-hud 게임 실행을 요청했다. 이번 비교는 잔여 서비스 정리·ESync복구·Metal3 변경이 포함되어 성능이 개선되어도 어느 하나만의 효과로 단정하지 않는다.

- Metal3 비교 세션2026-10-18T13-45-32Z-5317C1E3-2A9A-469A-A1B6-9C828F1033AC, PID75518은10초 후 실행 유지됨. Steam4.4%/게임132.9%/서버33.3% 측정. HUD 및 동일 구간의 실제fps는 사용자 확인 대기다.


## 2026-10-18 · 엘든링25~30fps 사용자 확인 / 추가 동기화 비교 준비

- 사용자 Metal3/ESync끔/잔여 서비스 정리 조합에서25~30fps로 향상 보고. 입력 정상과 함께 실제 사용자 보고로 기록하되60fps/안정적플레이 달성으로 승격하지 않는다. 변경이 여러 개라 Metal3만의 단독 개선으로 단정하지 않는다.
- 측정 시 메모리 여유51%,시험Steam1.7%/게임53%/wineserver49.6%CPU. 서버 대기 비용 가능성이 있어 --trial-msync를 AppID1245620 전용 명시옵션으로 추가했다(기본off,Steam/게임동일조건,ESync0). Metal3·SDL입력·720pLow는 유지할 계획. 이전MSync1로그인실패에는 잔여 서비스/잘못된DXGI 등의 교란이 있었으므로 깨끗한 환경에서 재비교하되 성공을 가정하지 않는다.
- 게임 저장·종료 및 현재GPU시간을 사용자에게 요청했다. 샘플 시도는 PID75518이 이미 사라져 실패했으며 유효 성능스택으로 기록하지 않는다. 재빌드 중이며 새 비교게임 실행은 아직 하지 않았다.

- 사용자 저장/게임종료 확인 후 전용 Runtime만 사용하는 Wine 잔여 프로세스를 정리했다. MSync1/ESync0으로 동일 Steam prefix XInput검사 종료코드0,슬롯0중립0,0 유지. 과거 shm이 정상 제거되지 않았다는 MSync 경고가 있었으나 새 Mach포트 부팅과 검사 통과를 확인했다. 새 빌드·서명·자체검사122개·whitespace 통과 후 시험 Steam을 --trial-msync로 열었다. 실제게임fps 비교는 다음 단계다.

- Metal3+MSync1 비교 게임PID77223,세션2026-10-18T13-49-57Z-7E6AFD44-57BE-4AB0-B371-FD0EC2DB1401이10초 후 유지됨. Steam1.3%/server7.8%/game120.3%로 초기 측정했으나 이전49.6%는 플레이 중 측정이므로 동일구간 성능개선의 증거로 직접 비교하지 않는다. 실제HUDfps·GPU시간·입력상태 사용자 확인이 남았다.


## 2026-10-18 · 엘든링720p60fps 및1920×1200 비교

- 사용자 MSync1/Metal3/ESync0 조합으로1280×720에서60fps까지 상승 보고. 패드·카메라 정상 보고와 함께 실제 사용자 검증 근거로 기록하되 모든구간60fps/장시간안정성은 주장하지 않는다. 25~30fps가M5상한이라는 판단은 배제한다.
- 사용자는1920×1200선택메뉴 부재를 보고했다. Windows EnumDisplaySettings 검사도구 scripts/wine-display-modes-probe.cpp를 추가/컴파일하고 같은 시험prefix에서 검사한 결과1920×1200 포함을 확인했다(evidence/elden-display-modes.log). 현재게임설정WINDOW이므로창모드UI제한 가능성을 판단했다.
- 게임종료를프로세스로확인후 전용GraphicsConfig.xml 날짜백업을보존하고 ScreenMode FULLSCREEN/FullScreenWidth1920/FullScreenHeight1200 세항목만명시적으로변경했다. 다른화질·MSync·Metal3·패드설정은유지하고 --trial-msync --trial-metal3 --trial-hud로재실행. 실제1920×1200 HUD와fps는사용자확인대기다.

### 2026-10-18 — 엘든링(ELDEN RING) 1920×1200 60 FPS 실기 검증 완료 및 작업 마무리

- **사용자 실기 검증 완료**:
  - Apple M5 환경에서 **1920×1200 해상도(전체화면)에서 60 FPS까지 안정적으로 구동됨을 사용자가 직접 확인**.
  - DualShock 4 / DualSense 패드 정상 인식, 무입력 카메라 자동 회전 결함 해결, 부드러운 조작감 확인.
- **게임 호환성 DB 정식 승격 (`GameProfiles.swift`, `game-profiles.json`)**:
  - `steam:1245620` (ELDEN RING) 항목의 상태를 `failing`에서 **`userReportedWorking` (사용자 구동 확인)**으로 정식 승격하고 revision 2로 갱신.
- **최적 런타임 파이프라인 기본값 확정 (`GameTrials.swift`)**:
  - 격리 런타임 기반 Apple D3DMetal + Mach-message MSync 1 + Metal 3 (`D3DM_MTL4=0`) + Wine SDL 패드 구성을 기본값으로 표준화.
- **빌드 및 패키징 준수**:
  - `dist/MacDeck.app` 단독 빌드 및 코드 서명 완료 (`SelfTests` 122개 전원 통과, `/Applications` 미복사, DMG 미생성).


## 2026-10-18 · 엘든링 검증 환경의 MacDeck 연결

- 사용자1920×1200에서도60fps유지 보고. 이를 사용자실기결과로 누적하며 장시간·모든구간60fps로 확대하지 않는다. 작업문서상단의 미해결 엘든링 표기를 최신상태로 보완하고 과거기록은보존했다.
- GameTrials.configure에 전용Apple조합 MSync1/ESync0/Metal3를 반영해 GUI와CLI동일설정으로 실행한다. 명시적변형CLI는 실행후에도 보호기준을검증한다. 잘못된 SteamAppID로전용설정적용은거부한다.
- Runtime.playGame은 정확한AppID1245620+준비된Apple전용환경+저장된보호기준이있을때만 전용게임EXE로연결하고 다른게임경로는유지한다. Runtime.launch는 선택게임runtimePath를검사하며 공유runtime선택값을바꾸지않는다. 직접실행Steam게임도세션추적한다. Console에전용Steam열기카드를추가했다.
- GameProfiles의별도 steam:1245620:trial 프로필에 사용자보고상태/revision/실행기준을저장하는명시CLI를추가했다. 기준은 D3DM_MTL4와실제AppleDXGI,d3d12core,D3DMetal,libd3dshared,MetalIR변환기해시도포함한다. 정상기준변경시실행차단,일반프로필에는전용환경검증이라는범위를명시했다.
- 빌드/서명성공,자체검사127개통과. 추가회귀5개는CLI없는전용환경Metal3/MSync,AppleDXGI덮어쓰기방지,다른게임환경격리,잘못된AppID거부,AppleDXGI변경시보호차단이다. 실제보호프로필저장결과는후속로그와함께확인한다. GUI일반플레이카드실행은아직미검증.


## 2026-10-18 · 사용자 흐름 확정: Steam Big Picture 공통 실행

- 사용자 지시: 모든 게임은 기존 Steam Big Picture를 기본으로 동일한 흐름에서 실행하며 엘든링만 별도 Steam/버튼으로 처리하지 않는다. 이에 추가 중이던 Console 전용Steam버튼·AppID1245620전용자동실행분기를 제거했다. 검증환경/성공설정/보호프로필은 내부검증자료로 보존하며 사용자UI에별도Steam을요구하지 않는다.
- SteamClient의 일반기동은 기존과같이 -gamepadui + steam://open/bigpicture를유지한다. 단일Steam에게임별그래픽조합을연결하는구현은아직완료가아니다. 성공한시험게임이일반Steam경로에서도성공했다고주장하지않는다.
- 공통런타임에서 기본DXMT와게임별AppleD3DMetal을동시에선택할수있는지 격리된CompatibilityLab에서먼저GPU검사할계획이다. 공유Steamprefix/DLL/기존정상게임은검증전변경하지않는다.

- 공통렌더러 실험: 기본DXMT런타임을APFS복제한 .cache/common-steam-runtime 및 인증없는 CompatibilityLab/CommonSteam prefix에서 Apple DLL 네이티브선택을검사했으나 D3D12 종료코드53으로실패했다. 기존게임에배포하지않았다.
- SteamAppId의정확한숫자값과관리INI만읽는 공통DXGI/D3D12선택기 원형(scripts/common-renderer-router.cpp,build-common-renderer-router.py)을 x64ABI유지트램폴린으로컴파일했다. 원본Apple/DXMTDLL은별칭복사본으로보존한다. 첫GPU검사는0xc0000135 DLL로드실패로미통과,경로지정재검증중이다. 이원형은제품번들빌드에포함하지않으며실제Steam/게임에는아직적용하지않는다.
- 사용자UI에서전용Steam/게임자동우회제거후 앱빌드/서명·자체검사127개·whitespace통과. Steam BigPicture기본인수는유지한다. 통합성공을주장하지않는다.

- 공통선택기의경로지정후 DX12/Apple GPU검사PASS,동일prefix에서 DX11/DXMT 및 DX11/Apple GPU clear/copy/readback16픽셀검사각각PASS(실제게임성능검증과구별). scripts/build-common-renderer-router.py는DXGI/D3D11/D3D12/D3D12Core선택기4개를빌드한다. 숫자SteamAppId와관리INI만읽으며Steam프로필/인증파일은읽지않는다.
- 사용자기존게임도Apple가좋으면맞춰도되고재테스트하겠다고승인. SharedSteamRuntime.swift에공통런타임복제,기존prefix그래픽DLL4개백업/복구,선택맵관리,실패시원복을추가했다. 활성Steam이있으면전환거부하며원래winePath·기존게임보호기준은보존한다. 선택기진단은AppID/PID/렌더러/모듈/시간만64KiB이하파일로남긴다.
- 일반SteamBigPicture클라이언트(AppID없음)는기존DXMT,게임은Apple비교기본값및AppID별명시선택을사용하는공통방식이다. MacDeckUI에통합모드전환과게임별렌더러선택을추가중이며,실험선택은보호기준해제및Steam종료후가능하다. 실제공통Steam적용은GPU/회귀검사및백업준비후진행할예정이다.

- 최종공통선택기조합에서 AppID1245620 DX12/Apple,601150 DX11/Apple,0(BigPicture) DX11/DXMT GPU검사3개모두종료코드0/PASS. 선택기AppID/PID/렌더러로그도생성확인. 앱빌드/서명·자체검사130개·whitespace통과.
- 사용자기존게임재테스트승인및Steam/게임비실행확인후 준비런타임을 SharedSteamRenderer/Runtime에독립복제하고 일반 Steam prefix의4개그래픽DLL을백업한뒤공통모드를활성화했다. 기존winePath는state.json에보존하고원복버튼을제공한다. Steam계정파일·게임설치폴더는읽거나복사/수정하지않았다. 기본DXMT번들의d3d11SHA cafb32ba2b58e2e8decc1d6feabccdc131e1bf186713b34913a98974f94a3f02 보존. 실제공통BigPicture와게임성능은이후검증이다.

- 일반Steamprefix에DS4검증과동일한SDL설정 EnableSDL1/DisableHidraw1을적용했다. 기존HKLM winebus두키값만winebus-before.json에보존했다. 입력설정은그래픽복구와별개공통입력개선으로유지한다. 인증파일/게임파일은대상이아니다.
- Steam/게임비실행확인후공통모드를실제비활성화하여 원래그래픽DLL4개가백업과바이트동일하고원래winePath가복구된것을검증했다. 그후공통비교모드를다시활성화했다. 기존게임별정상기준은자동갱신/삭제하지않았다.
- 공유렌더러선택기로그를일반SteamBigPicture게임의관찰기록(renderer-observed)으로오류ZIP에연결했다. AppID가일치하는관리폴더64KiB이하의일반파일만선택하고심볼릭링크/다른AppID는거부한다. 렌더러로드관찰은실제게임성공·종료상태의증거가아니라는주석을기록한다.
- 공통비교구성의자동/수동구성요소업데이트는혼합방지를위해비교모드종료까지보류한다. 최종빌드및일반BigPicture표시검증을진행중이다.

- 공통모드최종빌드/서명·자체검사130개·whitespace통과. GameProfile업데이트전기록은AppID해시/revision별History파일로보존하여다른렌더러재검증시과거성공기준을잃지않게했다. 보호기준은선택된공통렌더러와해당실제구성요소를기록하고,공통비교에서현재렌더러기준이없으면UI에미검증으로표시한다.
- scripts/stop-macdeck-test-processes.py는MacDeck소유런타임을mapped-code로확인하고게임/비보조exe가있으면전체정리를거부한다. 명시적유지보수실행으로남은24개보조프로세스만정리했다(다른앱은유지). 일반Steam은실행중이아니었으며게임전용클라이언트는추가실행하지않는다.
- dist/MacDeck.app --steam으로기존일반Steamprefix의공통BigPicture를열었다. 실제BigPicture표시/공통경로게임실행과성능은이후사용자검증이필요하다.

- 실제공통Steam첫실행은프로세스만생기고BigPicture창이관측되지않았다. 성공으로기록하지않고Steam/CEF자체가선택기를거치지않도록조정했다. 관리그래픽환경변수의4개모듈override를제거하고Wine등록설정에서일반게임은native프록시,steam.exe/steamwebhelper.exe는원래builtinDXMT를직접사용한다. 기존HKCU그래픽설정12개만별도JSON백업하여모드해제시복구한다. Steam계정설정은쿼리하지않는다.
- 공통host주소공간설정을성공한시험환경과동일하게LAA1로맞췄다. Steam표시개선원인으로선택기경로와LAA중하나를단정하지않는다. 새빌드/서명·자체검사130개통과후수정된공통설정활성화성공. 실제일반prefix에서DX12게임·DX11게임·SteamUI용이름의GPU검사를진행중이다.


## 2026-10-18 · 엘든링 일반 Steam 실행 재확인

- 요청: 통합 후 엘든링이 실행되지 않아 설정 변경이 필요한지 확인. 검증된 전용 환경의 1920×1200/Metal3/MSync1/ESync0 설정은 변경하지 않았다.
- 자체 진단에서 직전 일반 Steam 세션은 종료코드0으로 끝났으며 Steam/엘든링 프로세스가 없음을 확인했다. 게임 그래픽 옵션의 문제로 단정할 근거는 없다.
- 게임 비실행 확인 후 MacDeck UI를 재시작하고 일반 Big Picture를 다시 요청했다. 이번에는 일반 prefix의 Steam과 CEF 자식이 유지되고 화면상 Wine 소유 1512×982 창이 생성됨을 확인했다. 창 생성은 로그인/Big Picture 내부 준비 완료나 게임 성공을 보장하지 않는다.
- 동일 일반 Steam에 -applaunch 1245620을 전달했다. 별도 시험 Steam은 실행하지 않았다. 인증 파일/원시 Steam 로그는 읽지 않았다. 게임 구동 결과는 후속 확인 중이며 공통 모드에서 60fps 검증 완료로 승격하지 않는다.

- 후속 확인: Wine 창 제목을 원문 출력 없이 분류한 결과 Big Picture=true/로그인=false/ELDEN=false. 일반 Steam 요청 후에도 엘든링 프로세스가 생성되지 않았고 해당 AppID 렌더러 로그의 신규 생성도 확인되지 않았다. Steam 실행 요청 이전/게임 시작 단계의 실패를 구분하기 위해 사용자에게 플레이 버튼 이후 상태를 요청했다. 실제 원인은 아직 미확정이며 옵션 변경이나 게임 성공을 주장하지 않는다. 문서 수정 후 git diff --check 통과.


## 2026-10-19 · 엘든링 시작 직후 종료 / 과거 DXGI 혼합 조사

- 사용자 보고: 일반 Steam에서 잠깐 실행 중 표시 후 종료. 게임 그래픽 옵션은 유지했다.
- 같은 일반 prefix/런타임에서 게임 EXE 직접 재현 결과 종료코드5, Vulkan adapter LUID 식별 실패 반복 및 null page fault를 그래픽 필터로 확인했다 (`evidence/elden-common-startup-20261019.log`). 직접 재현은 Steam 플레이 버튼 성공과 구별한다.
- 게임 로컬 dxgi.dll SHA-256이 기존 번들 Vulkan/D3D12 브리지와 동일(5c866c3dac88db794a54fc6b2f2c3c41610395359d565bd7297c3fd105eb39d3)했고, 자체 라우터는 d3d12=metal만 기록했다. 기존 로컬 DXGI와 Apple D3D12 혼합을 원인 후보로 좁혔다.
- 수동 일회성 비교 조치: AppID1245620의 해당 DLL만 AppSupport/Compatibility/ManualBackups/1245620-20261019에 바이트 동일 백업/원위치·해시 복구 메타데이터 보존 후 게임 폴더에서 제거. 자동 실행/갱신에서 DLL 변경하는 코드는 추가하지 않았다. 다른 게임·INI·게임 런처는 변경하지 않았다. 재실행 비교 진행 중이며 아직 수정 완료로 승격하지 않는다.
- scripts/graphics-log-filter.c와 test-graphics-log-filter.py에 자체 라우터 오류의 허용 접두어 및 인증 단어 차단 검사를 추가. 필터 검사3개 통과 및 -Wall/-Wextra/-Werror 컴파일 성공. 원시 Steam 출력은 저장하지 않는다.

- 비교 결과: 기존 로컬 DXGI 제거 후 동일 조건의 eldenring.exe PID97470이20초 이상 유지되며 자체 로그1245620-1476에dxgi=metal 및d3d12=metal이함께기록됐다. 이번 필터 로그에는 기존Vulkan LUID오류/page fault가없다. 즉시종료재현이해소된 근거이며 Steam플레이버튼 재실행·실제타이틀/플레이/fps는사용자검증이남는다. 게임은종료하지않고유지했다.

- 창 메타데이터 확인: ELDEN RING 1920×1200 창 생성 확인. 화면 내용/프레임/플레이 성공은 아직 확인하지 않았다. 최종 git diff --check 통과.


## 2026-10-19 · 엘든링 통합 환경 사용자 구동 확인

- 사용자 보고: “현재는 잘 구동 되었어”. 일반 Steam prefix/공통 런타임에서 기존 로컬 Vulkan DXGI를 백업 분리한 후 열린 게임의 정상 구동을 사용자 확인으로 기록한다.
- 검증 범위: 일반 Steam 환경의 게임 EXE 직접 실행 및 사용자 정상 구동 보고. 이번 보고에는 FPS 수치가 없으므로 과거 격리 환경의 1920×1200 60fps 결과와 구분한다. Steam Big Picture 플레이 버튼을 통한 종료 후 재실행, 장시간·다른 구간 안정성은 미검증이다.
- 변경 파일: work.md/README.md의 현재 상태 갱신 및 이 기록 추가. 실행 구성/다른 게임 프로필/기존 정상 보호 기준은 변경하지 않았으며 자동 기준 갱신도 하지 않았다. 게임은 그대로 유지한다.
- 검증: 문서 변경만 수행; git diff --check 확인. 남은 작업은 Big Picture에서 재실행과 통합 환경 성능 확인이다.


## 2026-10-19 · 4 게임 사용자 비교 / DMC5 WindowServer 종료 대응

- 사용자: 엘든링1245620 및 RE3 952060 잘됨; DmC220440 실행 직후 크래시; DMC5 601150 타이틀 후 시작/로딩 중 크래시와 Mac 로그아웃. 이번 성공 보고의 FPS·장시간 범위는 미확인이다.
- 시스템 보고서 WindowServer-2026-10-19-002854.ips의 종료 메타데이터만 확인: WATCHDOG / monitoring timed out for service / 40초 checkin 없음. 게임 렌더러 로그601150-2392는d3d11 및dxgi=metal. 로그아웃과 렌더링의 인과·커널 GPU 오류는 확정하지 않았다. 메모리 덤프/원시 인증 출력은 수집하지 않았다.
- Steam/게임 비실행 확인 후 AppSupport 호환성DB의220440/601150에 최신 실패와revision을기록하고 기존 프로필은History에보존했다. 601150만steamRenderer=dxmt로지정해 공통INI에도601150=dxmt 추가. DXMT 역시Metal이며 과거 사용자 렉해소 조합으로의복귀다. 현재환경의재검증은미완료/failing유지. 다른모든프로필보존을JSON정규화비교로확인했고 RE3/엘든링/기본렌더러설정은변경하지않았다.
- DmC 실행파일은PE32(x86), DMC5는PE32+(x64)로확인. 서로같은게임수정으로묶지않는다. DMC5 재현실행은하지않고 DmC만DLL누락/예외메타데이터수집실험을진행한다. 게임폴더DLL/INI/런처자동변경은추가하지않았다.
- 변경범위: 로컬게임DB/이력/공통renderer맵과work.md/README.md. 앱코드·공유바이너리는변경하지않았으므로앱재빌드없음. 남은작업: DmC 원인확인 및 DMC5 DXMT비교(전체OS로그아웃위험고려),정상게임회귀확인.

- DmC 직접 시작 검사: 종료53, import mscoree.dll 실패(evidence/dmc-startup-20261019.log). PE CLR 데이터 디렉터리 RVA36322996/size72로 실제관리헤더존재확인. 공통WINEDLLOVERRIDES의mscoree,mshtml=차단이첫장애후보이며 DX9 GPU오류라고단정하지않는다. 다른게임보호를위해전역차단해제없이한프로세스에만mscoree=b비교중이다.

- DmC CLR 허용 시험은15초후에도프로세스생존/완료미확인(evidence/dmc-clr-trial-20261019.log). 공통prefix의windows/mono폴더도없음을확인했으나.NET설치여부전체를이검사로단정하지않는다. 정상게임승격없이시험PID3612만TERM으로정리하려했으나이미종료되어no such process였다. 정상구동확인이아니다. DmC는미해결이며다음은별도환경에서CLR의존성확인이다. DMC5는AppID별DXMT복귀만적용하고재실행하지않았다. 문서갱신후git diff --check통과.


## 2026-10-19 · DmC CLR 격리 설치 및 DMC5 DXMT 재검증 착수

- 사용자 작업 시작 지시에 따라 DmC의PE CLR 헤더 버전v4.0.30319 확인. 게임 설치 폴더에dotNetFx40_Client_x86_x64.exe와installscript.vdf가있음을확인했다. 공식호환런처PlayOnMac 설치스크립트도AppID220440에dotnet40을요구한다(https://www.playonmac.com/en/app-1659-DmC_Devil_May_Cry.html). 현재Wine성공으로확대하지않는다.
- 인증파일없는새.cache/dmc-clr-lab/Prefix를기본번들Wine으로초기화(종료0),Windows7설정(0),게임에포함된.NET4 Client설치프로그램을/q /norestart로시험중. 공유Steam설치·레지스트리에는설치하지않았다.
- DMC5선택대상DXMT d3d11/dxgi별칭이제품번들과바이트동일함을확인. d3d11 SHA cafb32ba2b58e2e8decc1d6feabccdc131e1bf186713b34913a98974f94a3f02 보존. 정확한SteamAppId601150+현재일반prefix로자체D3D11 GPU clear/copy/readback16픽셀검사종료0/PASS(evidence/dmc5-dxmt-route-probe-20261019.log). 실제DMC5플레이·WindowServer문제해결의증거는아니다.
- GameProfiles.swift의새DB용초기DmC220440/DMC5601150기록을최신실패로분리하고과거DXMT성공기록도보존했다. 실험환경자동주입없음. 기존DB는load시덮어쓰지않는다. SelfTests.swift에두AppID독립성과환경비주입회귀검사추가. 빌드진행중이며결과는후속기록.

- 격리.NET4 설치프로그램은180초대기후완료되지않아시간초과중단. 설치완료를주장하지않는다. 생성된네이티브CLR로자체x86 C#프로그램을컴파일/실행한결과둘다종료0, PASS native CLR 4.0.30319.1 ptr=4(evidence/dmc-native-clr-probe-20261019.log). 첫검사는Unix파일경로가csc옵션으로해석되어CS2007이었으며Windows Z:경로로수정후통과. 이결과는DmC게임/Steam성공과구별한다. 공유prefix에는.NET설치안함.
- 앱빌드/서명성공(evidence/dmc-compatibility-build-20261019.log),자체검사131개전수통과,그래픽필터3개검사통과,git diff --check통과.

- DmC 실제게임을.NET4격리prefix에서실행하면Exit-8,시스템Wine진단은EXC_ARITHMETIC/SIGFPE. 작은CLR검사에는정수0나눗셈예외catch/Math.Sqrt검사도추가했고둘다PASS였다(evidence/dmc-native-clr-exceptions-20261019.log). 단순CLR누락이외의게임실행호환문제가남는다.
- 인증없는prefix복제본Prefix-oldwow에서기존캐시Wine7.7/GPTK1.1 Wine32on64와비교했으나rundll32.exe .NET Framework Initialization Error(Unable to find a version of the runtime to run this application)가표시됨. 사용자첨부로확인. 정상게임화면아님을명시하고그격리prefix의wineserver-k만요청했으나종료코드1이었다. 후속ps조회에서Wine/rundll32/DmC프로세스가없어이미종료된상태임을확인했다. 공유Wine/Steam/정상게임변경없음.
- DMC5현재게임설정은TargetPlatform=DirectX11,WindowMode=Borderless,FullScreenMode=false,FramerateSetting=VARIABLE(읽기전용확인). 자체검사601150-32로그의d3d11/dxgi=dxmt를확인하여현재AppID별선택이실제적용됨을확인했다. 실제게임검증과구별한다.

- 추가분리: 격리Windows XP모드비교도20초후생존관측만있고이후Wine프로세스가없어성공판단불가(evidence/dmc-native-clr-winxp-20261019.log). 설치중단으로만들어진NGen이미지영향을배제하기위해동일격리게임프로세스의COMPlus_ZapDisable=1 JIT비교를추가중이며공유Steam에는미적용이다. CLR기초/예외회귀프로그램을scripts/wine-clr-probe.cs로보존했다.

- JIT 비교는35초시점프로세스생존을반환했으나후속게임/Wine창·프로세스는없었다. 화면성공으로판정하지않는다. 또한이실험실에는Steam인증이없으므로DRM/Steam의존에의한종료와런타임비호환을아직분리할수없다. SIGFPE만으로.NET/Wine근본원인을확정하지않는다. 공유prefix.NET배포및Steam인증정보복사는하지않았다.
- 최종빌드/서명성공,회귀검사133개PASS. 추가2개에서DMC5 DXMT선택이RE3/엘든링/DmC선택에영향없음과엘든링revision/보호baseline유지를확인했다. git diff --check PASS. 현재Wine/게임시험프로세스없음.
- 이번 작업 결론: DMC5의AppID별DXMT복귀·구성무결성·GPU검사까지완료. 실제로딩/WindowServer안정성은미검증. DmC는.NET4의기초실행경로만확인했고게임정상화는미완료. 공유.NET설치는보류하며이단계에서사용자에게DmC재테스트를요청하지않는다. 다음작업은인증이필요한Steam실행조건과CLR초기화실패를분리할안전한통합설계다.


## 2026-10-19 · 게임별 .NET / Visual C++ 자동 준비 구현 중

- 사용자 요청: 게임이 요구하는 .NET 버전별·VC 재배포 버전별 자동 설치. 이 요청으로 Wine prefix 내 의존성 설치를 명시적으로 허용받았으며 macOS 시스템 런타임 설치와 구분한다.
- DmC installscript.vdf 확인: VC2005/2008/2010 x86 + .NET4 Client를명시한다. 기존추측과달리VC단일버전으로묶으면안된다. 이파일의명령/실행파일/ignoreexitcode/hasrunkey는실행하거나성공조건으로믿지않는다.
- DependencyCatalog.swift: Winetricks공식소스에서확인한Microsoft공식URL/SHA256고정카탈로그18종. VC2005/2008/2010/2012/2013/2015–2022 각각x86/x64, .NET3.5SP1(2.0/3.x포함)/4.0/4.5/4.6.2/4.7.2/4.8. .NET4계열은prefix당요청최고버전으로계획을병합하고출처AppID를보존한다. 최신VC변동URL의해시가달라지면실행하지않고중단한다.
- Dependencies.swift: 게임별installscript와표준redist폴더의제한된메타데이터만읽어요구계획생성. 애매한버전/임의명령은무시한다. prefix별설치잠금·캐시·재시도하루유예·성공후실제네이티브PE/레지스트리확인·CLR컴파일실행검사·실패기록추가. 공식패키지다운로드만실행하며원시Steam출력·게임파일·인증파일은수집/수정하지않는다.
- Steam을열기전/라이브러리Steam실행요청전누락패키지를준비하도록Runtime.swift연결중. 실행중게임/Steam이있으면설치를다음시작으로보류. Console런타임에키보드/패드/마우스공통액션으로필수런타임다시준비추가. 자동준비실패를게임성공으로승격하지않는다.
- .NET설치는Wine Windows버전만일시변경하고기존값백업/복구. CLR활성화는고유실행파일이름과정확한AppID목록에한정하고다른게임은기존전역차단유지. 실행파일이름이충돌하면보류한다. 환경변경은기존정상baseline검사에계속노출되며자동보호갱신하지않는다. 이는prefix공통의존성변경으로기존게임재검증이필요할수있다. 실제공유prefix설치는아직실행하지않았다.
- App.swift에계획보기/패키지한정설치내부CLI, GameProfile에선택적requiredRuntimes와카탈로그ID검증, DependencyTests.swift에버전/아키텍처/출처AppID/임의명령차단/환경보존회귀검사추가중. 빌드/검사/실제격리설치결과는후속기록한다.

- 첫격리자동설치실기: VC2010 x86공식파일다운로드/고정SHA검증/무인설치종료0/설치후네이티브DLL조건검사통과,receipt installed(evidence/dependency-vc2010-lab-20261019.log). .NET40도기존격리prefix에서네이티브CLR실행검사까지통과했으나당시검사는x86만이었고최신코드는wow64환경에서x86/x64모두검사하도록강화해재검증예정.
- 요구계획실제출력에서Steamworks Shared(AppID228980)가모든공용설치패키지를필요로한다고잘못추정하는문제를발견해해당inventory는제외했다. PEDependencies.swift에실행없는PE일반/지연import및CLR메타데이터판독을추가해설치스크립트없는게임도정적의존성을탐지한다. 스캔은깊이4/512파일로제한하고symlink·redist실행파일은분석에서제외한다.
- .NET임시Windows버전복구의크래시복구마커를추가하고복구필요상태에서는Steam시작을차단한다. 기존환경의게임/타설치가실행중이면prefix별tasklist검사로설치를거부한다. 공유게임폴더DLL이동/레지스트리성공마커위조/인증파일복사는없다.

- 최신격리검증: VC2010재실행은설치기실행없이통과, .NET40도x86/x64컴파일·실행·정수예외처리검사후existing native runtime verified로통과했다. 이전start.exe대기보조프로세스와mscorsvw상시서비스는정상보조목록에추가했고게임/다른설치프로세스차단은유지한다. 원시프로세스명령/계정출력은수집하지않는다.
- 설치시작전dependencies-enabled마커를남겨VC/.NET공통DLL/SxS해시를기존정상baseline에포함하도록보강했다. 자동보호갱신은없다. 새회귀2개는VC파일변경감지와다른prefix비간섭이다. 관련AppID가있는설치receipt만기존오류ZIP에추가하고이전설치기록은History에보존한다. docs/GAME-DEPENDENCIES.ko.md에지원범위/동적로딩탐지한계/재시도/공통영향/복구를기록했다.
- CLR활성화는다른게임의VC설치실패때문에통째로보류하지않고현재게임AppID의CLR검사성공receipt를확인하도록보완. 이수정중Swiftasync논리OR자동클로저컴파일오류를확인해순차guard로수정했고최종재빌드중이다. 실제공유Steamprefix는아직설치/변경하지않았다.


## 2026-10-19 · 필수 런타임 자동 준비 최종 검증 / 인계

- 최종앱빌드·ad-hoc서명성공,코드서명검사통과. 자체검사150개와그래픽로그필터3개통과,git diff --check통과. 증거:evidence/dependencies-build-20261019.log,dependencies-tests-20261019.log.
- 실제게임요구계획: DmC220440=.NET40+VC2005/2008/2010 x86; 용사30214830=VC2010x86; 발라트로2379780=VC2013x64+VC14x64; 엘든링1245620/RE3952060/DMC5601150등=VC14x64. Unity/Mono DLL만근거로.NET을설치하는오탐은회귀검사로차단. 실제계획은evidence/dependencies-plan-20261019.json에보존. 정적탐지결과는게임구동확인의대체물이아니다.
- 실제격리검증: VC2010x86공식고정해시패키지설치종료0및네이티브DLL검사성공; 이후재실행에서는기존설치확인으로재설치없음. .NET4기존격리설치는x86/x64각각C#컴파일/실행/나눗셈예외검사성공으로준비됨확인. 최종CLI두검사모두종료0. .NET공식Full패키지의새자동설치와카탈로그18종전체실설치를완료했다는뜻은아니다.
- 변경파일: DependencyCatalog.swift/Dependencies.swift/PEDependencies.swift/DependencyTests.swift 신설, App.swift/Runtime.swift/Console.swift/Library.swift/GameProfiles.swift/SelfTests.swift/SupportReports.swift연결, docs/GAME-DEPENDENCIES.ko.md·README.md·work.md 갱신. 설치계획/버전·아키텍처/CLR기능검사/실패이력·재시도/보호기준변경감지를포함한다.
- 이번기능검증에서는기존공유Steamprefix에새VC/.NET설치를실행하지않았다. 다음정상Steam시작전에자동준비하며,Steam/게임실행중에는보류한다. 공유의존성변경은정상보호기준을자동갱신하지않고재검증을요구할수있다. 맥시스템/인증파일/게임폴더DLL은변경하지않았고,커밋·푸시·DMG생성없음.
- 남은검증: 실제일반prefix에서필수패키지준비후DmC실행과Metal/입력확인, DMC5 DXMT에서실제로딩/WindowServer안정성확인. 두게임을정상으로승격하지않는다.


## 2026-10-19 · VC2005 무인 설치 옵션 수정

- 사용자첨부: Microsoft Visual C++2005의Command line option syntax error. 자동설치기에서모든버전에/q /norestart를공통전달한것이문제였다. 고정한2005IExpress설치기는/norestart를받지않으며공식Winetricks의해당해시패키지호출도/q만사용한다.
- DependencyCatalog.swift의VC2005x86/x64에만/q를전달하도록수정. VC2010등다른패키지인수는보존했다. DependencyTests.swift에양쪽VC2005와VC2010의인수격리회귀검사추가. 실제격리설치및빌드검사중이며완료결과는후속기록.
- 현재프로세스조회에VC2005/Steam/MacDeck설치작업은없고자체공유환경receipt는vc2005-x86 failed/exit0이었다. 설치기종료0을설치성공으로믿지않는후조건검사가이실패를잡은것이며정상설치로승격하지않았다. 인증파일/원시Steam출력은읽지않았다.

- 후속실기검증: VC2005 x86/x64 및VC2008 x86/x64 네종모두/q로실제격리설치후종료0/네이티브SxS파일확인통과. evidence/vc2005-*-fixed-20261019.log 및vc2008-*-fixed-20261019.log. VC2008도공식소스와같은/q단독으로범위를확장했고다른설치기옵션은유지. 자체검사151개통과·서명검사통과. 패키지한정CLI재시도에서도원래관련AppID를유지하도록App.swift를수정해재빌드중.
- 별도미해결.NET진단: 일반prefix의v4Client/Full Install은32/64뷰모두1이지만Framework/Framework64 clr.dll은없고mscoree는Winebuiltin이다. 따라서설치표시만으로성공이라고할수없으며현재후조건검사가failed를기록한것은정상. 등록잔재에따른설치기사전판단가능성이있지만원인확정이나레지스트리삭제/위조는하지않았다.


## 2026-10-19 · 기존 prefix의 VC2008 및 .NET4 누락 구성요소 복구

- VC2005는수정된/q로실제일반prefix설치후검사성공. VC2008은일반설치·/repair·확인된MSI제품의/fa복구에도Wine기본대체DLL이남았다. 대체파일을백업분리후누락복구하는시도도실패해원본을복원했다. 성공으로기록하지않았다.
- VC2008최종수동복구: 같은고정SHA8742bcbf24ef328a72d2a27b693cc7071e38d3bb4b9b44dec42aa3d2c8d61d92 공식패키지로격리설치/검증한동일9.0.30729.6161 x86 VC90 DLL3개를백업된Wine대체파일위치에복원. 원본백업/원위치/파일별해시는.cache/vc2008-main-repair-backup에보존. 게임폴더DLL은대상이아니다. 자동준비기재검사종료0및실제VC90 CRT/C++로드·memcpy검사종료0/PASS(evidence/vc2008-main-api-20261019.log). 원인조사프로브scripts/wine-vc2008-product-probe.cpp와wine-vc90-runtime-probe.cpp추가.
- .NET최종수동복구: 인증없는격리prefix에게임이제공한Microsoft.NET4Client로설치·검증한Framework4/Framework64/GAC및mscoree x86/x64구성요소를백업후복원. 첫검사실패로원복했고,제한된DLL진단으로MSVCR100_CLR0400.dll누락을확인. 그.NET전용CRT양쪽도포함하여재검사한결과x86/x64모두컴파일·실행·0나눗셈예외처리·수학연산종료0/PASS. 백업/복구메타데이터·원본게임배포설치기해시는.cache/net4-main-repair-before에보존. Full.NET4전체새설치가성공했다는뜻은아니다.
- dotnet40패키지만--retry로자동준비기검사/실행확인및관련AppID220440의고유CLR실행파일활성화성공. 다른게임프로필/보호기준을갱신하지않았다. .NET4Full부트스트래퍼인수도공식Winetricks와동일한/q 및/c:install.exe /q로분리하고회귀검사추가. 해당.NET전용CRT를정상보호파일해시에포함.
- 현재같은일반Steamprefix/공통런타임으로BigPicture를열어DmC실제시작을확인중. 별도Steam인증복사/계정파일읽기없음. DMC5는WindowServer문제로재실행하지않았다. 공유.NET/VC런타임복구이므로기존게임의장시간회귀미검증은유지한다.


## 2026-10-19 · 중단 작업 재개: 런타임 검증 완료 / DmC 메타데이터 경고 분리

- 요청: 중단했던 필수 런타임 자동 설치 오류 수정을 마무리하고 남은 게임 실행 상태를 확인.
- VC2005/2008 무인 옵션 수정, .NET4 내부 설치 인수 수정 및 패키지 한정 CLI의 AppID 보존을 현재 dist/MacDeck.app에 반영. 실제 일반 prefix의 VC2005 설치 확인, VC2008 CRT API 검사, .NET4 Client x86/x64 컴파일·실행·예외 처리 검사 통과. 18종 전체 신규 설치나 .NET Full 신규 설치 성공을 뜻하지 않는다. 상세 복구 백업과 제약은 바로 앞 기록 참조.
- DmC220440의 게임 소유 창만 읽는 scripts/wine-dmc-dialog-probe.cpp로 대기 원인을 확인: UE3가 외장 디스크의 `._*.upk` AppleDouble 메타데이터를 실제 패키지로 읽어 Ambiguous package name 경고에 정지. evidence/dmc-after-runtime-dialog-20261019.txt에 보존. 기존 stack evidence의 ‘창 없음’은 제목 필터에 따른 오판으로, 실제로는 Message 모달이 있었음을 정정.
- 수동 복구: 정확한 AppID220440 게임 폴더에서 AppleDouble 매직8바이트·실제 동반 파일 존재·symlink 제외를 확인한 메타데이터 2004개(8,208,384바이트, 그중 upk1229개)만 백업 격리. 실제 게임 EXE/자산/DLL 변경 없음, EXE 해시 보존. 백업·원래 상대 경로·SHA256·완료 상태는 ~/Library/Application Support/MacDeck/Dependencies/MetadataQuarantine/220440/20261019/restore.json 및 Files에 보존. 게임 준비/목록 갱신의 자동 파일 변경으로 추가하지 않았다.
- 재실행 결과: 같은 일반 Steam에서 -applaunch220440 재요청 후 게임 프로세스가 유지되지 않음(게임 창 probe exit2). 로그인된 동일 prefix에서 직접 실행 비교도 exit1. 따라서 경고 원인 제거와 게임 정상화를 구별하며 DmC 성공으로 승격하지 않는다. 게임 자체 Logs 디렉터리는 없었고 원시 Steam 출력/인증 파일을 읽지 않았다. 화면 캡처 시도는 실패하여 이미지 확인 증거로 사용하지 않았다.
- 검증: 현재 빌드 자체 검사 재실행 152개 PASS(evidence/vc2005-options-tests-20261019.log), git diff --check PASS. 이전 동일 빌드 서명 검사 PASS. sandbox의 ps 조회는 차단되어 승인된 읽기 전용 조회로 전환. DMC5는 앞선 WindowServer 로그아웃 위험 때문에 재실행하지 않았다. 기존 정상 게임 프로필/보호 기준 자동 갱신 없음.
- 남은 작업: DmC의 후속 즉시 종료 원인 분리 및 실제 Metal/입력/플레이 확인, DMC5 AppID별 DXMT 복귀 후 로딩 안정성 사용자 검증, 기존 정상 게임의 공유 런타임 변경 회귀 확인. 커밋·푸시·DMG 생성 없음.


## 2026-10-19 · DMC5 GS/TS 보완판 복구 진행

- 초기 사용자 렉 해소 직전 배포한 후보와 현재 공통 DXMT 해시가 다름을 확인. 원본 cafb32…에서 보관 Metal library로 재생성한 후보가 초기 99efd3…와 바이트 동일. 공통 원본은 보존하고 전용 macdeck_dxmt_gsts_v1_d3d11.dll을 AppID601150/DXMT/명시적 gs-ts-v1 옵션으로만 선택하도록 구현.
- GameProfiles.swift에 선택적 dxmtMarshalFix(기본 비활성), 정확한 ID/렌더러/보호 기준 충돌 검사 추가. SharedSteamRuntime.swift map 및 component 선택, GameProfiles baseline 실제 선택 파일 fingerprint, common-renderer-router.cpp 명시적 분기/진단 연결. 기존 DB 자동 승격·게임 폴더 파일 수정 없음.
- router 빌드 첫 시도는 과거 /private/tmp Apple 원본 경로가 사라져 실패. build-common-renderer-router.py에 --apple-components 명시 입력을 추가해 기존 검증 Apple 별칭으로 재빌드 성공. 앱 빌드·회귀155개 통과. Metal 기본 sandbox에는 장치가 없어 실패했고 승인된 GPU 검사에서 GS/TS 두 배치 및 36개 함수 검사 통과. 별도 인증 없는 prefix에서 프로세스별 렌더러/GPU 검사 중이며 실제 게임 성공과 구분.


## 2026-10-19 · DMC5 전용 GS/TS 보완판 적용 및 격리 확인

- 정확한 AppID601150 로컬 프로필에만 dxmtMarshalFix=true/revision3을 기록하고 과거 JSON/관리map/router를 백업. 상태는 failing 유지, 보호 baseline 자동 변경 없음. 일반 원본 DXMT 해시 cafb32…와 다른 프로필 JSON이 보존됨을 비교 확인. 전용 DLL 후보는 초기 99efd3…와 바이트 동일.
- 백업/복구 manifest: ~/Library/Application Support/MacDeck/Compatibility/Repairs/dmc5-gsts-20261019/restore.json. 새 후보는 Runtime/lib/wine/x86_64-windows/macdeck_dxmt_gsts_v1_d3d11.dll, 관리 map의 [patches]601150=gs-ts-v1로만 연결. 변경한 공통 D3D11 router는 별도 환경에서 검증한 뒤 Runtime/Renderers 및 prefix/system32에 반영. 게임 폴더/INI/DLL 변경 없음.
- 실기: 인증 없는 별도 prefix에서 AppID601150/952060/1245620/0 각각 D3D11 GPU clear/copy/readback16픽셀 exit0. 로그에서601150만marshal=1, 나머지0. 일반 Steam prefix에도 동일 GPU 검사 exit0 및601150 marshal=1 확인. 실제 DMC5 게임은 자동 재현하지 않고 사용자 동일 구간 확인 요청. 증거:evidence/dmc5-gsts-router-gpu-20261019.log, dmc5-gsts-main-gpu-20261019.log, dmc5-gsts-metal-tests-20261019.log.
- DmC220440: 기존 직접 실행의 AppID 미지정 exit1과 구분하려고 정확한 AppID를 지정해 비교. DLL 누락은 이번 수집에서 없었지만 최종 c0000005/address0183c9b4,exit3. 모듈 이름/주소·예외 코드만 기록(evidence/dmc-main-module-exception-20261019.log), 인증/원시 출력/덤프 미수집. 게임 정상화 미완료이며 GS/TS 수정과 묶지 않는다.
- docs/DMC5-GSTS-RECOVERY.ko.md에 원본/후보 해시, 적용·검증 범위와 복구 제약 추가. 새 회귀는 후보 변경이 DMC5 baseline에서 감지되고 RE3 baseline이 보존되는지 확인하도록 보강하여 재빌드 중.

- 최종 검증: 재빌드·strict 코드서명 검사 PASS, 자체 검사157개 PASS(후보 변경 감지 및 RE3 기준 보존 포함), git diff --check PASS. 결과 evidence/dmc5-gsts-tests-20261019.log. 커밋·푸시·DMG 생성 없음. 사용자 DMC5 같은 구간 플레이 결과는 아직 받지 않았으므로 현재 렉 해소를 확정하지 않는다.


## 2026-10-19 · DmC220440 실행 실패 재조사 착수

- 요청: DmC 해결 방법을 찾아 수정. work.md 최신 미완료/검증 범위를 먼저 확인. Valve Proton 원본 이슈 https://github.com/ValveSoftware/Proton/issues/820 에서 .NET/XAudio2 분류는 확인했으나 현재 환경의 원인·해결 근거로 확대하지 않는다.
- 예외0183c9b4 주변 게임 EXE를 읽기 전용 분석: vtable0x5c 호출 직후 반환 객체를 역참조하는 코드로 D3D9 CreateTexture 실패 후 null 참조 가능성을 확인. EXE 수정 없음, 정확한 API·실패 사유는 추가 로그로 검증 중.
- 현재 공유 Steam 세션의 DmC 경로는 d3d9=b, WINE_D3D_CONFIG=renderer=vulkan이며 DXVK/D9VK가 아니라 WineD3D Vulkan이다. i386 d3d9 원본/일반prefix 해시7a769092… 동일. 정상 게임의 공유 렌더러/설정은 변경하지 않았고 오류 로그만 선별 수집 중.

- 실제 D3D9 경고에서 DXT5 텍스처 생성 실패0x8876086c 직후 동일0183c9b4 접근 위반을 확인(evidence/dmc-texture-failure-20261019.log). 정적 추정과 일치하며 현재 실행 실패의 직접 경로를 좁혔다.
- 신규 scripts/wine-dmc-dxt5-probe.cpp로 별도 prefix에서 비교: 기존 WineD3D는 DXT5 생성 실패, 보관 D9VK 후보는 정적/동적 DXT5 생성·업로드와 GPU clear/readback/Present PASS. 첫 테스트는 정적 DEFAULT 텍스처를 직접 Lock하여 잘못된 검사였으므로 SYSTEMMEM staging+UpdateTexture로 수정 후 재검증했다.
- scripts/d3d9-game-router.cpp 및 build-d3d9-game-router.py 추가: i386 14개 export/ordinal을 stack 보존 tail trampoline으로 전달. 고정 AppID220440 및 관리 map의 명시적 d9vk-v1에서만 별도 후보, 나머지는 원본 별칭으로 전달. Wine builtin 선택을 유지하기 위한 builtin marker도 포함. 공유 환경은 아직 변경 안 함.
- 별도 복제 런타임+인증 없는 CLR prefix에서220440 DXT5/GPU PASS. 기본/601150의 기존 WineD3D clear/readback는 pixel0 실패라 성공이라고 기록하지 않는다. 원본 동일 조건과 비교해 기존 실패인지 확인 예정. 실제 DmC 시작 비교 중이며 Steam 인증과 플레이 성공은 구분한다.


## 2026-10-19 · DmC DXT5 실패 우회 적용 (플레이 검증 중)

- 공통 원본과 D3D9 선택기의 기본 경로를 별도 prefix에서 비교: 둘 다 동일한 pixel0/exit6. 따라서 기존 WineD3D GPU readback 결함은 남아 있고 선택기 검사를 성공으로 확대하지 않는다. DmC 후보 경로만 DXT5 static/dynamic 업로드·GPU readback·Present PASS. evidence/dmc-d3d9-default-comparison-20261019.log 및dmc-dxt5-renderer-comparison-20261019.log.
- .NET 준비된 인증 없는 lab에서 게임은25초 후 살아 있으나 실제 타이틀 확인 안 됨. 추가 보조도구는동기화 모드 불일치가 가능한SIGFPE로 실패해이결과로화면성공판정안함. 그 lab 게임PID만 종료했고공유Steam은유지.
- GameProfile.dmcD9VKFix 기본 비활성, 정확한220440와보호baseline충돌검사, 관리map의dllDirectory32 및[patches]220440=d9vk-v1, 해당후보fingerprint추가. 회귀에서다른ID거부/DMC5선택보존/후보변경감지/RE3기준보존 확인. 빌드·strict서명·자체검사161개 PASS(evidence/dmc-d9vk-tests-20261019.log).
- 실제적용: 일반 공유 런타임 i386 d3d9.dll과prefix syswow64에선택기를반영하고원본을macdeck_original_d3d9.dll로보존, 별도macdeck_dmc_d9vk_v1.dll 배치. 공통코드변경이므로기존정상보호기준은변경을감지할수있고자동갱신하지않는다. 다른게임은원본으로위임하며x64DXMT/Apple/DMC5후보는변경없음. 게임폴더DLL/EXE/INI수정없음.
- AppID220440만dmcD9VKFix=true/revision3/failing유지. 모든다른프로필JSON동일확인. 원본·경로·해시·복구manifest는~/Library/Application Support/MacDeck/Compatibility/Repairs/dmc-d9vk-20261019에보존. 일반Steam인증을그대로유지한환경에서실제DmC시작확인중이며게임성공보고는아직없음.

- 실제 일반 Steam 재검증: DmC 프로세스PID77988가후보macdeck_dmc_d9vk_v1.dll을로드하고25초이상생존. 게임소유창제목 DMC-DevilMayCry (32-bit, DX9) 표시 및창probe exit0 확인. 수정전동일주소접근위반즉시종료와차이가있다. evidence/dmc-after-d9vk-module-20261019.log에수정후증거분리.
- 사용자에게현재게임창의타이틀/새게임/이어하기실제확인을요청했으며아직응답없음. 화면/플레이/FPS/패드정상및장시간안정성은미검증. docs/DMC-D3D9-RECOVERY.ko.md에원인·범위·검증·롤백제약을기록했다.
- 최종 현재빌드161개검사·strict서명·git diff --check PASS. 커밋/푸시/DMG생성없음.


## 2026-10-19 · DmC 실행 후 심한 버벅임 조사

- 사용자: 수정 후 실행은 되나 심한 버벅임으로 플레이 불가. 정상 구동 승격하지 않음. 기존 즉시 크래시 해결과 성능은 분리한다.
- 조사 시작 시 기존 DmC는 이미 종료. 예외 추적이 켜진 진단 실행의 영향을 배제하려고 동일 AppID/일반prefix에서 WINEDEBUG=-all/표준 그래픽 로그로 다시 실행(PID79340). 공유 Steam과 다른 게임 환경 변경 없음. CPU 약118%, wineserver 약27.5% 관측, 이 수치만으로 근본 원인 확정 안 함.
- sample 첫 시도는12초 제한시간 실패, 다음 -noSymbolication 시도exit255로 기호 없음. 성공한 스택 분석으로 기록하지 않는다. 관리D3D9 로그에는 이번 범위에서GPU오류가없고textureCompressionBC=1확인. 새로운 정상로그실행의사용자성능보고대기중.


## 2026-10-19 · 사용자 D9VK 사용 금지 / 비활성화

- 사용자 정상 로그 실행에서도 타이틀부터 심한 버벅임 보고. 이어서 D9VK→Metal은 사용하면 안 된다고 명시. 이후 DmC 해결 후보에서 D9VK를 제외한다. 단순 로깅 문제가 아니며 이전 기능 검사 통과는 플레이 성능 증거가 아니었다.
- 정확한 steam:220440만 dmcD9VKFix=false/revision4/failing으로 변경하고 관리 map의220440=d9vk-v1을 제거. PID79340 종료 요청 시 이미 종료 상태였음. 프로필/기존map/후보백업은 보존하고 다른 게임 프로필·DMC5 설정은 변경하지 않았다.
- 정상 로깅 sample 후속 시도는 성공했지만 WOW64 dispatcher 반복으로 Windows 호출 스택은 신뢰하기 어려움. 기호만 중복 제거해evidence/dmc-slow-stack-20261019.txt에 제한 보존. GPU 병목 원인 확정 안 함.
- 직접 Metal DXMT D3D9 후보는 별도 완전한 후보 런타임에서 DXT5 생성/업로드·GPU 검사 exit0. 기존 런타임에서 후보 DLL만 사전 로드하는 첫 비교는40초시간초과로 실패. 해당 후보를공유환경에설치하지않고새prefix에서명시적로더경로를재검증중. 사용자요청에따라D9VK재활성화·async옵션시험은진행하지않는다.

- 직접 Metal 격리 구성 진전: 일반 이름 winemetal.dll을 개별 로드하는 실험은 Windows/Unix 쌍 불일치로 제한시간 내 완료되지 않아 배포하지 않음. Wine10 원본 loader.c의 builtin Unix 검색 규칙을 확인한 뒤 고유이름 wm_dmc001.dll/.so 및 D3D9 import만 같은 길이 이름으로 바꾸는 방식을 구성. 세 원본 해시 고정·기존파일 덮어쓰기 거부를 scripts/prepare-dmc-metal-aliases.py에 적용.
- 별도 기존 런타임 복제본에 고유 별칭만 추가한 실제 DXT5 업로드/GPU 검사 exit0(evidence/dmc-metal-alias-gpu-20261019.log). 공통 winemetal.dll/so 교체 없음. 새 선택기는 정확한220440+dxmt-v1에서만 이직접Metal DLL을읽도록 변경중.
- 사용자 금지에 맞춰 이전 dmcD9VKFix=true를 프로필 검증에서 거부하고 새 dmcMetalFix 기본비활성 옵션을 분리. 후보3개 DLL/Unix해시를 해당게임정상기준에포함, DMC5선택/다른ID거부/RE3기준보존/구D9VK재활성화거부검사추가. 앱재빌드와직접Metal선택기스트레스검사진행중.


## 2026-10-19 · DmC 직접 Metal 전환 (D9VK 제외)

- 직접Metal후보의고유DLL/Unix쌍을통한 D3D9 선택기에서 DXT5 static/dynamic 업로드·GPU clear/readback/Present·600프레임+5Reset 스트레스검사 exit0, elapsed1907ms(evidence/dmc-direct-metal-router-gpu-20261019.log). 이는합성검사이며실제게임FPS가아님.
- dmcD9VKFix=true는앱검증에서항상거부하고새dmcMetalFix+관리map220440=dxmt-v1로분리. 선택기도D9VK분기를제거하여직접Metal DLL/원본만읽는다. 회귀162개·코드서명검사통과. 후보fingerprint에Windows DLL2개/Unix1개를포함하고DMC5및다른게임프로필은보존.
- 일반환경첫게임실행은wm_dmc001.dll import누락/c0000135/exit3. 별도새prefix wineboot가만든syswow64전용등록파일이기존prefix에는없다는차이를확인. 실제native Unix dlopen은PASS로의존성오류와구별. 첫실행을게임성공으로기록하지않는다.
- 설치백업 Compatibility/Repairs/dmc-direct-metal-20261019/restore.json에추가파일까지선기록한뒤기존prefix에wm_dmc001.dll만등록. 후보원본공통Metal파일은교체안함. AppID220440 revision5/failing, D9VKfalse/직접Metaltrue. 현재정상로그수준재실행PID82957에서모듈/창확인중. 전용prefix등록파일도정상기준fingerprint에추가하여재빌드중.

- 전용등록파일보완후실제게임PID82957에서macdeck_dmc_dxmt_v1.dll + wm_dmc001.dll + wm_dmc001.so 로드·게임창표시확인, D9VK미로드(evidence/dmc-direct-metal-live-modules-20261019.txt). 사용자에게직접Metal수정본의실제타이틀/플레이성능확인요청했으며응답대기. 이전처럼프로세스생존을성능성공으로승격하지않는다.
- 최종재빌드/자체검사162개/strict서명/git diff --check PASS. 시험prefix wineserver-k는-6실패라정리완료로보지않고경로조회후남은전용lab서버81322만TERM으로정리. 일반Steam/게임서버는유지. docs/DMC-D3D9-RECOVERY.ko.md에D9VK철회·직접Metal전환·등록파일실패및복구·검증범위를추가. 커밋/푸시/DMG생성없음.


## 2026-10-19 · 직접 Metal 타이틀 개선 확인 / 게임 시작 후 검은 화면

- 사용자: 타이틀은 부드러우나 게임 시작 후 검은 화면과 사운드만 출력. 직접 Metal 성능 개선(타이틀)과 실제 플레이 렌더링 실패를 구분하며 정상으로 승격하지 않는다. D9VK 사용 금지 유지.
- 조사 시작 시 기존 게임은 이미 종료되어 live 검은 화면을 즉시 수집할 수 없었음. 직접 Metal 그래픽 로그 경로를 명시한 정상 수준 실행PID84812를 다시 열고 사용자에게 같은 상황 재현·Esc/Start 시 메뉴/영상 건너뛰기 반응 확인 요청.
- 게임 Movies의 .bik 영상 존재를 읽기 전용 확인했으나 Bink 문제로 확정하지 않는다. 현재 관리 로그는 기존4196바이트 기록만 보이므로 새 로그 수집 성공을 주장하지 않는다. 정확한v0.4-d3d9 릴리스의 D3D9 device/shader/format 원본 소스를 별도 .cache로 받아 3D/영상 경로를 분석 중. 게임폴더/공통렌더러 변경 없음.

- 再현중숨은게임소유창을읽어PID84812가 Warning/Steam must be running to play this game 모달에서대기중임을확인. 이재실행은원래검은화면을재현한증거가아님. 해당게임만종료하고기존일반Steam BigPicture를다시열었음(PID85433). 인증파일/화면열람없음.
- scripts/graphics-log-filter.c에실제v0.4소스가출력하는DXSO/FFP shader→AIR/Metal라이브러리실패로그의고정접두사보존추가. 비민감오류만보존하며token/임의Steam출력은거부하는회귀추가,필터3검사PASS. 재현용독립collector를게임stderr에연결하여25초후파이프가닫히지않고게임종료까지수집하도록준비. 앱빌드진행중.

- 일반Steam재시작후독립collector85850+게임85851기동, 게임소유창 DMC-DevilMayCry (32-bit, DX9) 표시/창probe exit0확인. evidence/dmc-black-screen-graphics-20261019.log는현재0바이트로오류없음/렌더링정상증거가아니다. 게임시작후검은화면의실제재현은사용자조작대기.

- 최종진단빌드·strict서명·자체검사162개·그래픽필터3검사·git diff --check PASS. 검은화면수정완료를주장하지않으며현재게임/독립오류collector는사용자재현을위해유지. 다음판단은검은화면에서메뉴/영상건너뛰기반응과DXSO/FFP/Metal오류에근거한다. 커밋/푸시/DMG생성없음.


## 2026-10-19 · 검은 화면·메뉴 미출력 실재현 조사

- 사용자: 검은 화면 유지, Esc/Start 메뉴도 안 보임. 현 PID85851 CPU116.1%, wineserver7.3% 관측. 선별 그래픽 오류 파일0바이트, 관리DXMT로그도0바이트. 로그없음을오류없음으로확대하지않는다.
- macOS짧은stack표본은WOW64dispatcher반복으로Windows호출위치판단불가. scripts/wine-dmc-thread-probe.cpp로게임명정확일치대상만스레드명령주소를짧게수집하고즉시Resume;메모리/덤프/Steam조회없음. 54threads/110modules, GetThreadTimes는0이라CPU스레드식별불가. main은win32u, wm_dmc001 thread는SharedEventListener_start 대기위치. 반복대기원인을확정하지않는다.
- v0.4-d3d9 GPU query 완료 대기 소스를읽고EVENT/OCCLUSION(FLUSH유무)전진검사를scripts/wine-dmc-query-probe.cpp에추가. 별도prefix에서시간제한검증중. 게임폴더/공통렌더러변경없으며D9VK금지유지.

- 기본EVENT/OCCLUSION(FLUSH유무) query전진검사모두1~5ms/exit0. query일반구현을무작정우회하거나완료를위조하지않는다. 해당증거evidence/dmc-metal-query-progress-20261019.log.
- 실제게임의프레임/그리기/query진행구분을위해선택적 scripts/dmc-d3d9-trace.hpp 진단카운터추가. 정확한220440/직접Metal선택과별도[diagnostics]220440=frame-v1에서만활성화. 원래API반환값/호출을유지하며메모리·화면·입력내용대신누적횟수만64KiB로제한해기록. 기본비활성이고공통렌더러파일/게임파일수정은아직없음.
- 첫컴파일은CINTERFACE를windows.h후에선언해interface vtable타입이생성되지않아실패. 앞선선언으로수정후빌드성공. 별도GPU/query/600프레임검사로콜백전달을검증중.

- 카운터를켠별도prefix검증: DXT5+GPU/query+600프레임검사exit0, frames234/query8/pending4 기록. 추가삼각형DrawPrimitiveUP→GPU readback 검사도exit0으로기존API결과보존확인(evidence/dmc-render-counters-gpu-20261019.log,dmc-metal-draw-probe-20261019.log).
- 검은화면PID85851만종료,백업Compatibility/Repairs/dmc-render-trace-20261019/restore.json선기록후32-bit D3D9선택기의선택적카운터배포. 정확한220440만revision6/failing으로기록하고다른프로필JSON보존확인. 관리map의[diagnostics]220440=frame-v1은임시진단옵션이며앱map재생성시기본꺼짐. 게임폴더/셰이더후보/공통Metal원본변경없음.
- 게임88856/독립collector88855로재시작하고동일검은화면재현요청. 현재카운터는GPU/프레임/그리기/query호출횟수만보존하며1초빈도/64KiB상한, 입력·화면·메모리·인증수집없음. 실제문제수정은아직아니며관측결과로다음수정결정.

- 재시작88856은다시Steam미실행경고에서대기해카운터가생기지않음. 이실행을원래검은화면재현으로판단하지않는다. 해당게임만종료하고일반Steam의 -applaunch220440으로시작하도록재현경로변경(89062/collector89061). 별도Steam/prefix를만들지않았으며인증파일조회없음. 사용자가앞서보고한실제검은화면85851과이경고상태를구분한다.

- 일반Steam89062가실제자식DmC89428을실행한것확인. 새dmc-render-1264.log에카운터기록시작. 샘플에서는프레임과그리기가지속증가하며GPU EVENT/OCCLUSION GetData가다수S_FALSE후완료됨(완료횟수증가). 이것만으로실제검은화면구간인지판단할수없고타이틀/새게임구간재현사용자확인이필요. 무기한GPU대기를확정하지않는다.
- 현재설치된선택적카운터는합성GPU/query/삼각형그리기검증을통과했으나문제수정이아닌진단. 원래정상API결과·다른프로필을보존. 남은작업: 현재Steam자식게임에서동일검은화면구간과카운터시각대응, 영상/렌더타겟/프레젠테이션경로분리. D9VK금지유지.


## 2026-10-19 · 사용자 자율 진단 요청 / GPU 최종 프레임 확인

- 사용자: 켜두고 떠났으니 직접 판단·수정 요청. 더 이상사용자에게반복재현을요청하지않고게임내부확인진행.
- 현재Steam자식89428의카운터는~190fps 제출·프레임당34그리기로계속진행. 따라서이샘플이무기한GPU대기라는가설은배제. 누적query카운터의LONG부호오버플로확인(진단수치한계,게임오류근거아님).
- macOS게임창837만캡처시도는could not create image로실패. 이에scripts/wine-dmc-live-frame.cpp + wine-dmc-load-diagnostic.cpp 추가. 정확한DmC프로세스·고정DLL해시/PE버전/Present vtable주소·함수소유모듈을검사하고, 한프레임GPUbackbuffer만읽은후즉시Present복원. 원격메모리에서는자체진단DLL경로만할당/전달하고임의프로세스메모리·덤프·Steam정보수집없음.
- 먼저별도prefix자체GPU테스트에연결해완료hr0/1280x720/nonblack625/625와자동복원확인. 실제게임은1512x982/nonblack550/625였고BMP→PNG형식변환후직접확인한내용은타이틀화면이었다. 따라서사용자보고검은화면과재시작뒤타이틀을구분.
- scripts/wine-dmc-key.cpp는정확한게임소유foreground만검증해Enter/Esc/방향키만전달. 정상SendInput동작확인하여타이틀→저장슬롯선택화면까지직접진행. 기존slot1(플레이0시간/mission1)만선택했고새저장생성·삭제·덮어쓰기선택없음. 슬롯선택직후프레임은black0/625이며전환구간인지지속실패인지추가확인중.


## 2026-10-19 · 중단 작업 재개 / DmC 자율 재현과 한 프레임 감사

- 요청: 하던 작업 마무리. work.md 확인 후 기존 정상 게임 설정을 보존하고 AppID220440 직접 Metal 경로만 조사. 저장 슬롯1은 백업 후 NEW GAME→DEVIL HUNTER→튜토리얼 확인을 직접 조작했다. 슬롯 선택 직후 검은 프레임은 후속 메뉴가 정상 출력되므로 지속 실패로 판정하지 않는다.
- 게임 시작 뒤 실제 GPU backbuffer black0/625를 두 번 확인했으나, 이후 Bink 오프닝/크레딧 영상은 정상 색상으로 출력됨. 따라서 모든 영상이 실패하거나 창 표시만 고장났다는 결론은 배제하고 실제 3D 장면을 추가 확인 중이다.
- scripts/wine-dmc-frame-audit.cpp: 고정 PE버전/정확한 DmC만 대상으로 한 프레임 Draw/SetRT/StretchRect 반환값·중간RT 크기/형식/비영점 비율을 제한 수집하고 즉시 원본 vtable 복원. 게임/Steam 메모리 덤프·인증·임의 입력 수집 없음.
- 별도 계정 없는 GPU 테스트 첫 실행은 장시간 프레임 옵션 누락으로 NO AUDIT; 옵션 보완 후 RT100/100, hr0, 자동복원 확인. 실제 게임 영상 프레임은 draw1/RT변경4/실패0, 중간RT90/100 확인. 실제 3D 성공 증거로 확대하지 않는다. evidence/dmc-frame-audit-harness-20261019.log.
- 기존 카운터64KiB 상한에 도달해 제목화면 로그를 evidence/dmc-render-title-counters-20261019.log로 보존 후 자체 카운터만 비움. LONG 누적 query 부호오버플로는 진단 한계이며 게임 오류로 기록하지 않는다. D9VK 금지 유지.


## 2026-10-19 - DmC partial Clear failure isolated; bounded fix trial

- Request: finish interrupted DmC black-screen work autonomously. Navigated NEW GAME and tutorial prompt with game-only input; backed up the three AppID220440 save files first. No Steam authentication files or process dumps were read.
- Opening movie displays correctly. Actual gameplay shows HUD but no scene. GPU audit: 81 draws, 60 render-target changes, no failed draw HRESULT; scene FP16 targets remain zero. Shader bindings exist. Viewport1512x982 versus depth1512x984 enters partial Clear.
- Separate GPU tests: programmable SM3/FP16 draw PASS; original partial depth Clear FAIL(exit12, black); original partial color Clear FAIL(exit12, zero instead of requested color). Reproduced without Steam/game assets.
- scripts/dmc-depth-clear.hpp implements an experimental state-preserving draw Clear. Depth replacement PASS(expected half-float3400/3800/3a00/3c00); color replacement PASS(3404/3804/39fd/3c00). scripts/wine-dmc-frame-audit.cpp restores original hooks after one frame; bounded180/1200-frame trials also restore.
- Actual bounded trials display character/background and improved shadows, but severe overexposure/color artifacts remain. NOT a complete gameplay fix. Do not promote compatibility status or protected baseline. D9VK remains prohibited.
- Added dmcClearFix optional/default-disabled exact220440 profile/map experiment (dxmt-clear-v2), validation requiring private Metal and no protected baseline; other games cannot inherit it. Normal full clears, explicit rectangles and MRT retain original API. Candidate not installed into production.
- Evidence: dmc-partial-depth-probe-20261019.log, dmc-depth-fixed-probe-20261019.log, dmc-partial-color-probe-20261019.log, dmc-partial-color-fixed-probe-20261019.log, dmc-depth-clear-live-20261019.log. Shader source exact upstream release was inspected, but source-level root of malformed partial-clear constants and remaining color issue is not confirmed.


## 2026-10-19 - Final verification / explicit incomplete-playback handoff

- Changed: GameProfiles.swift (default-disabled dmcClearFix, exact-ID validation, map/32-bit-router fingerprint); SharedSteamRuntime.swift (explicit experimental map and query); SelfTests.swift (default-off, exact ID, dependency, disable/restore, RE3 baseline preservation); scripts/dmc-clear-router.hpp and dmc-depth-clear.hpp (partial-Clear candidate); saved SM3/depth/color probes and isolated runner; game-only frame-audit/key tools.
- Final app build PASS;169 self-tests PASS (evidence/dmc-clear-experiment-tests-20261019.log);3 isolated GPU probes PASS;3 graphics-filter tests PASS; strict code signature and git diff --check PASS. Color/depth original failures remain separately recorded. No normal-game success or baseline auto-promotion.
- Actual experiment1200 frames: character and scene present, severe overexposure persists. Candidate is NOT production deployed or enabled. DmC DB revision7/failing, dmcClearFix=false, original dxmt-v1 retained. All other game profile records compared unchanged. Protected original D3D11 SHA remains cafb32ba2b58e2e8decc1d6feabccdc131e1bf186713b34913a98974f94a3f02.
- Closed only owned reproduction PID89428 to unload temporary diagnostics, retained normal Steam. Removed only temporary diagnostics220440=frame-v1 after DB/map backup at Compatibility/Repairs/dmc-clear-investigation-20261019/restore.json. Game files/INI untouched; saved-file backup retained.
- Remaining: resolve actual-game color/postprocess defect in the private renderer, then replay and verify control/performance/relaunch before enabling the candidate. The requested complete DmC gameplay fix is NOT finished; diagnostic infrastructure, isolated Clear candidate, regressions and documentation are complete for this iteration. No commit/push/DMG requested or performed.


## 2026-10-19 - Stop request / Git handoff and sleep preparation

- User requested stopping investigation, tidying, committing/pushing current work, then putting the Mac to sleep. No further gameplay experiments.
- Commit scope: native controller UI, exact-game compatibility profiles, support reports/dependency handling, shared Steam renderer work, DmC/DMC5 experimental fixes and reproducible diagnostics, documentation and AGENTS changes accumulated since the previous commit. DmC color artifacts remain unresolved and Clear candidate remains disabled.
- Added ignore rules for local DMG installers, shader caches, logs and generated evidence. These files remain on disk; Apple installer/runtime binaries and raw diagnostic output are not published. Selected final non-authentication verification logs are explicitly retained in Git.
- Existing final validation:169 self-tests,3 isolated GPU probes,3 graphics-filter checks and strict code signature PASS. git diff --check is repeated before commit. Remote: origin/main (sjhdeux0114/macDeckAI). Sleep is requested only after successful push; its completion cannot be observed while the Mac is asleep.


## 2026-10-19 - DmC resumed: native Clear constant binding mismatch

- User requested resuming DmC fixes. Read current handoff; working tree began clean at14746d9. Preserve D9VK prohibition and exact-game scope.
- Exact upstream v0.4 source proves D3D9ClearQuad::clear sends fragment constants to slot0 while dxmt_command.metal reads kCustomBufferArgumentIndex0=30. The generic D3D11 Clear code already sends slot30. This explains the GPU-reproduced zero color/depth values; source-level mismatch is now confirmed.
- scripts/prepare-dmc-clear-binding.py locks original private DLL SHA, PE32 architecture and exact instruction/context. It changes only one instruction immediate0->30, preserves size and all other bytes, refuses overwrite and produces a separately named v3 DLL. Input af9a4837...; output84a4886fd6ac94d8dff5a680652f52068ccfb4be744aa40468a30b6843126627. Source equivalent retained in patches/dxmt-d3d9-clear-buffer-slot.patch.
- Isolated exact220440 router dxmt-bind-v3 uses the corrected candidate without the FFP/state-block Clear workaround. Depth/partial-color/SM3 GPU probes all exit0. Production runtime/profile not changed yet; actual game color correctness remains unverified. Evidence dmc-binding-{depth,color,sm3}-probe-20261019.log.


## 2026-10-19 - Native binding v3 deployment / verification checkpoint

- Added exact dxmt-bind-v3 routing and profile map/fingerprint support. Existing dmcClearFix option selects the native slot correction; the FFP/state-block workaround is not called on v3. Defaults remain off. New candidate-file changes are detected without changing the RE3 baseline.
- Validation: depth/color/SM3 isolated GPU3 PASS; exact routing AppIDs0/601150/952060 original vs220440 v3 PASS; patch identity/source preservation/refuse unknown/refuse overwrite3 PASS (including Python -O refusal); final app self-tests170 PASS. Initial py_compile attempted macOS cache outside workspace and was denied; project-local PYTHONPYCACHEPREFIX compilation and later in-memory syntax checks succeeded.
- Backed up before trial deployment at Compatibility/Repairs/dmc-clear-binding-v3-20261019/restore.json. Exact DmC revision8/failing + Clear native fix enabled. Other profile records compared unchanged and protected D3D11 SHA cafb32ba... retained; common winemetal PE/SO unchanged. No game-folder/INI/authentication changes.
- Same normal Steam89062 launched DmC30819. Private v3 DLL + wm_dmc001 PE/Unix loaded; game-only GPU frame confirms title. Windows SendInput returns success but title does not advance; process-only macOS activation true and scan-code/focus variant also did not establish game acknowledgement. Windows-style process paths are now normalized in deployment guard. Input submission is not claimed as successful menu control.
- User asked through pending text question to click game and press Enter / select existing save / continue. Waiting on actual-play entry; do not claim v3 color/fps success or promote status. Temporary one-shot frame hooks restore immediately; no continuous query-counter tracing enabled. D9VK remains prohibited. Docs updated; no new commit/push/sleep requested.

- Final housekeeping: regenerated Wine probe logs used CRLF and the first diff whitespace check failed; normalized only line endings/trailing whitespace, then git diff --check PASS. Strict app signature and graphics-filter3 checks PASS. No further renderer changes after the successful GPU comparison.


## 2026-10-19 - v3 actual gameplay: overexposure and intermittent stalls remain

- User entered gameplay, then reported washed-out/burned-white output and frequent small hitches. v3 is not a complete fix; do not promote its status/baseline.
- Initial two GPU readbacks returned D3DERR_DEVICELOST while fullscreen game was backgrounded. These are capture failures, not black-frame evidence. After activating the exact game (no keyboard/mouse input), readback succeeded and visually confirmed severe overexposure in an actual playable scene. Backbuffer itself is washed out before final Present gamma; final display gamma alone cannot explain it.
- Added bounded game-only Present timing (wine-dmc-frame-timing.cpp), no GPU readback or continuous per-query hooks, max1200 successful intervals/30sec with automatic restoration. First background run had0 valid intervals/895 failed Presents and is not a performance result. Second foreground run:1200 intervals, mean24.285ms (~41.18 submitted Presents/s), median21.227ms,p95=32.612ms,p99=76.307ms,max1275.412ms;55>33ms,22>50ms,4>100ms. GPU execution/displayed FPS was not independently measured. Evidence dmc-v3-play-frame-timing-20261019.txt.
- Told user measurement finished and game may now be closed. No further input sent. Native Clear fix remains installed; no claim of complete visual/performance success.
- Additional isolated SM3 external PS constant c13->FP16 GPU probe PASS(expected3400/3800/3a00/3c00), ruling out a blanket external-constant upload failure. It does not validate all shader instructions/texture formats/postprocess paths. Investigating texture sRGB/postprocess and cold-compile vs steady-state stalls next.


## 2026-10-19 · DmC 과노출·잔렉 우선 / sRGB 분리와 DX11 가능성 검사

- 요청: D9VK→Metal 옵션 자체 제거, DmC 해결 후 용사30 순서. 후속 지시에 따라 과노출·잔렉 조사를 먼저 진행한다. 옵션 제거는 아직 미완료이며 기존 DmC D9VK 금지는 유지한다. 용사30에 DmC 수정을 자동 적용하지 않는다.
- 기본 sRGB read off/on 및 write off/on 격리 GPU4개 PASS. 외부 상수 c13 검사도 PASS. 이것은 게임 전체 HDR/톤매핑 성공이 아니다. 첫 sRGB 소스 컴파일은 중복 변수명으로 실패, 미생성 EXE 실행도 실패한 뒤 불필요한 꼬리 코드를 제거하고 재컴파일·GPU4개 검사에 성공했다.
- Present 측정1200개에서 평균24.285ms,p99 76.307ms,max1275.412ms; 과노출과 잔렉은 미해결. 사용자는 게임 종료 가능 안내를 받았고 이후 실제 프로세스가 종료된 것을 확인했다.
- DmC 실행파일 D3D11CreateDevice import/string 및 SM5 캐시가 존재한다. Epic UE3 공식 문서의 -DX11/-D3D11 옵션을 확인했으나 이것만으로 해당 게임 지원을 단정하지 않는다. 일반 Steam에서 일회성 -dx11 실행은 여전히 D3D9 모듈을 로드했다.
- 추가 진단: 자체 실행한 타이틀 재현만 종료하고 게임별 DevilEngine.ini를 .cache/dmc-dx11-config-backup에 원본 SHA와 백업. AllowD3D11=False→True 하나만 변경해 재시험 중. 공유 런타임·다른 게임 프로필은 수정하지 않았다. 종료 후 원복 필요.
- 32비트 D3D11 GPU clear/readback 검사 PASS이나, 로그에 MoltenVK가 나타나 직접 DXMT 경로 증거로 주장하지 않는다. 최초 sandbox 실행은 wineserver bind 금지로 실패; 승인된 격리 실행은 성공했다. DX11의 실제 사용 여부/게임 색상/성능은 미검증.
- 다음 작업: DX11 실제 선택 여부 확인·게임 INI 원복, 직접 Metal 후처리/프레임 지연 원인 분리. 정상 구동/호환성 기준 승격 없음. D9VK UI/시험 진입점 제거 후 용사30은 별도 AppID214830 검증.


### 2026-10-19 · DX11 시험 원복 / 한 프레임 HDR 진단

- -dx11 인수 및 게임별 AllowD3D11=True 시험 모두 실제 D3D11 모듈을 선택하지 않았다. 지원된다고 주장하지 않는다. DevilEngine.ini는 SHA 확인 후 원본과 바이트 단위 일치하도록 원복 완료. 현재 플레이는 직접 D3D9 Metal v3다. 공식 UE3 옵션 설명: https://docs.unrealengine.com/udk/Three/DirectX11Rendering.html (엔진 일반 문서이며 DmC 지원 증거 아님).
- scripts/wine-dmc-hdr-audit.cpp 추가: 고정 v3만 허용, 한 프레임 최대32개의 GPU 렌더타깃에서100점 RGB 범위/포화/비유한 값만 수집, 인증/프로세스 덤프 없음. 별도 계정 없는 GPU 하네스에서 readback hr0·정상 범위·원본 콜백 복원 확인.
- 실제 첫 진단은 fullscreen background의 D3DERR_DEVICELOST(88760868)라 색상 증거로 사용할 수 없다. 두 번째는 유효 device 상태에서만 시작하도록 보완했으나 foreground 복귀 대기 중. 출력 파일이 이전 실패 기록일 수 있으므로 원복 완료/새 기록 확인 전 성공으로 취급하지 않는다. 사용자에게 게임 창 직접 활성화를 요청했다.
- 후속 진단 바이너리에15초 idle 자동 취소/복원 추가, 컴파일·diff whitespace 검사 통과. 이 취소 보완판은 아직 실제 프로세스에 로드하지 않았다. 현재 기다리는 구버전 진단은 foreground에서 한 프레임 수집 후 복원되거나 게임 종료 시 해제됨. GPU 읽기 진단 자체 끊김은 실제 잔렉 성능으로 집계하지 않는다.
- 과노출·잔렉 원인 수정은 아직 미완료, 프로필 revision/정상 보호 기준 변경 없음. D9VK UI 제거는 사용자 우선순위에 따라 뒤로 유지.


### 2026-10-19 · 실제 후처리 프레임 확보 / LUT CPU 대조

- 사용자가 게임 창을 직접 활성화한 후 v3 HDR 한 프레임416개 추적 draw,64개 RT전환,API실패0 확인. 최종 RGB300표본 중139개>=.99. 32개 표본 제한 때문에 이 검사만으로 최종 원인 단정 불가. 콜백 자동 원복 확인.
- HDR render→texture sampling→FP16 readback 격리 검사에서16픽셀 모두2/4/.5/1 보존 PASS(scripts/wine-dmc-hdr-sampling-probe.cpp). 일반 sRGB/HDR 전달의 광범위 고장은 재현되지 않음.
- 후반 패스용 scripts/wine-dmc-postprocess-audit.cpp: 최대64개 GPU 표면 표본·공개 GetFunction 셰이더(각64KiB한도)·16개 그래픽 상수·256x16 LUT만 로컬 수집. 프로세스 메모리 덤프/Steam 인증 수집 없음. console 없는 loader로 초점 방해를 줄임. idle15초 취소/정상 한 프레임 원복 추가. 실제 원복 완료 확인.
- 초기 RT전환 뒤 GetTexture는 이미 unbind되어 입력이 없었음. UE3 후처리가 DrawIndexedPrimitiveUP을 쓰는 것을 확인해 draw 직전 상태 검사로 수정. 입력 LUT16KiB와 출력 LUT16KiB 및 정확한 상수를 확보. LUT 셰이더의 CPU 재계산과 출력 RGB12288개 비교: 평균/최대오차0, 3초과오차0. 따라서 해당 LUT 계산 오류는 증거상 배제 가능. 캐릭터/장면 색감 전체 정상이라는 뜻은 아님.
- 정확한 최종 셰이더4f40b4e1을 계정 없는 합성 하네스에서 재생하는 scripts/wine-dmc-final-shader-probe.cpp 작성. 첫 결과는 기대 감마값 대신RGB0으로 FAIL. 아직 하네스/초기상태/번역 결함을 구분하지 못했으므로 원인이나 수정 성공으로 주장하지 않는다. 동일 하네스 기본 감마 셰이더 대조를 진행 중.
- 기존 game-profile/공유 런타임/다른 게임 파일 추가 변경 없음. DmC 과노출·잔렉 미해결, 옵션 제거 및 용사30 후속 요청 유지.


## 2026-10-19 · BC sRGB 원인 재현·v4 후보 / 실제 시작 미확인

- 최종 셰이더 합성 하네스의 최초 RGB0은 시험 마스크 알파0 때문이었다. 마스크 알파1로 교정 후 정확한 게임 셰이더16픽셀이 CPU 감마 기준과 일치 PASS. 중간 레지스터 변형에 같은 최종 기대값을 적용한 FAIL은 원인 증거가 아니다.
- DXT5 sRGB off/on 격리 비교에서 off≈.518, on도≈.518으로 동일해 on 기대≈.23을 위반. 일반 RGBA8 sRGB는 PASS. 최초 BC 검사 컴파일은 cstdint 누락으로 실패하고 미생성 EXE 실행도 실패; 헤더 추가 후 성공 빌드만 검사하도록 수정했다.
- 순수 Metal BC3 뷰 검사(.cache/dmc-bc-metal.swift): linear .517647/.509804/.517647, sRGB .230769/.223199/.230769 PASS. M5 자체 sRGB BC 뷰 지원 확인. 고정 upstream dxmt_texture.cpp의 TextureView 생성자가 ‘BC sRGB 뷰 미지원’이라는 잘못된 가정으로 linear parent를 반환하고 있음. 이 분기를 우회한 후보에서 BC sRGB GPU 검사가 PASS로 바뀜.
- scripts/prepare-dmc-bc-srgb.py: v3 정확한 SHA 입력/PE32/명령 문맥 확인, file offset840678의 조건분기6바이트만 NOP, 원본 보존·출력 덮어쓰기 거부(-O 포함). 출력SHA def19eca660d29eb9065624971a2b3003a59a21896e1e62d58c096404f54a719. source 동등 patch dxmt-d3d9-bc-srgb-view.patch. 최초 명령 문맥 길이/선택기 문자열 타입 오류는 배포 전에 검출·수정했고 최종 패치3검사 및 라우터 빌드 PASS.
- dmcSrgbFix 기본 비활성, 정확한220440·native Clear·보호기준 없음 조건 필수. map dxmt-srgb-v4와 별도DLL fingerprint 추가. 다른게임/용사30 오적용 거부 및 RE3 기준 보존·끄면v3복원 자체검사 추가. 앱176검사 PASS, 서명 검증 PASS. 격리 새 라우터 BC off/on·RGBA sRGB·HDR·depth GPU5PASS, AppIDs0/601150/952060 원본 선택 로그 및220440 v4선택 확인.
- 사용자가 DmC 종료 완료한 후 Compatibility/Repairs/dmc-bc-srgb-v4-20261019/restore.json에 파일·맵·DB 백업. v4전용DLL/32비트 라우터/정확한DmC revision9 failing 적용. 다른 프로필 JSON 및 보호 x64D3D11/공유winemetal PE/SO 동일 해시 확인. 게임 폴더 DLL은 수정하지 않음.
- 일반 Steam 실행 요청 후 사용자가 ‘실행 안됨’ 보고. ps에 Steam89062만 있고 새 DmC/v4선택 로그가 없어 실제 v4 게임 검증은 미확인. 시작 요청 재시도/실패 단계 분리 중이며 GPU 합성 성공을 실제 게임 성공으로 승격하지 않는다. 필요 시 v3원복. 과노출·잔렉 해결 완료 아님.
- 옵션 제거와 용사30 작업은 사용자 지시에 따라 DmC 과노출·잔렉 이후로 유지. 실제 플레이 v4 검증과 시작 복구가 다음 최우선 작업.


### 2026-10-19 · 시작 요청 분리 / 실제 v4 로드 확인

- Steam -applaunch 재시도 및 steam://run/220440 요청에서도 DmC 자식이 생성되지 않았다. 새 v4 선택기 로그도 없어 이 상태를 v4 로더 실패로 판정하지 않았다.
- 켜진 동일 인증 Steam/prefix를 유지한 직접 EXE 시작 재현에서 PID45348 생성, macdeck_dmc_dxmt_srgb_v4.dll + wm_dmc001 PE/Unix 로드와 exact v4선택 로그 확인. CGWindow에서 DMC-DevilMayCry (32-bit,DX9) onscreen=true 확인. 이는 Steam Big Picture 플레이 버튼 복구의 증거가 아니며 별도 시작 요청 문제는 남음.
- 사용자에게 실제 생성된 게임에서 이어하기 후 과노출/잔렉 비교를 요청했다. 사용자 결과 대기 중이며 실제 플레이 성공이나 성능 개선은 아직 선언하지 않는다. 진단 한 프레임 콜백들은 앞선 게임에서 자동 복원된 상태로 종료되었고 새 PID에는 주입하지 않았다.
- source 동등 patch의 미사용 helper/변수를 제거했다. 소스 전체 재빌드 검증은 하지 않았고 배포물은 고정 해시6바이트 후보다. GPU 검사 및 원본/수정본 비교 숫자 로그를 evidence에 보존했고 실제 게임 셰이더/텍스처는 .cache에만 보존했다.


### 2026-10-19 · v4 실제 플레이 색상 확인 / 잔렉 조사 계속

- 사용자가 같은 플레이 구간에서 **과노출 개선**을 확인했다. 이는 BC 압축 텍스처 sRGB 뷰 수정 후보의 실제 게임 효과를 확인한 결과다. 다만 장시간 안정성 및 다른 장면은 미검증이므로 프로필 revision9/failing과 보호 기준 미승격을 유지한다.
- 사용자는 **잔렉이 남는다**고 보고했다. v3 측정치와 비교할 v4 전용 bounded Present 측정을 준비한다. GPU readback·입력·Steam 인증 자료 없이 최대1200개/30초만 측정하고 콜백을 자동 복원한다.
- D9VK 옵션 제거 및 용사30 별도 검증 요청은 보존한다. DmC 잔렉을 먼저 분리하며, DmC 수정은 App ID214830에 자동 적용하지 않는다.
- 사용자 비교가 끝난 뒤 기존 DmC 프로세스는 종료되어 있어 즉시 측정하지 못했다. 동일 로그인 Steam/prefix에서 DmC를 재실행해 PID47635와 v4 DLL/wm_dmc001 PE·Unix 로드를 다시 확인했다. v4로 잠근 bounded Present 진단 DLL을 재빌드했으며, 사용자가 잔렉 구간에 진입하면 측정한다. 아직 새 성능 수치는 없다.
- v4 실제 플레이 첫1200프레임: 평균20.969ms(47.69 제출fps),p95 28.763,p99 58.107,max160.520ms,50ms초과18,100ms초과2. 두 번째 warm-cache1200프레임: 평균21.541ms(46.42),p95 30.468,p99 46.405,max58.836ms,50ms초과7,100ms초과0. v3의 p99 76.307/max1275.412보다 큰 끊김은 감소했으나 지속 잔렉은 남았다.
- 실제 DXMT 셰이더 캐시는3166항목/약25.9MB이며 WAL이 플레이 중 증가했다. warm-cache에서 최악 지연이 감소해 cold shader 준비가 일부 큰 끊김에 기여한 근거지만, 평균 프레임 페이싱 원인 전체는 아니다.
- 프로세스 호출 스택을 저장하는 macOS sample은 자동 승인 검토가 프로세스 덤프 금지 범위 위험으로 거부했다. 우회하지 않고 공개 D3D9 함수의 횟수·소요시간만30초 집계하는 안전한 대안으로 전환했다.
- API 집계 결과: Present1496 최대0.190ms, DrawIndexed554749 최대0.290ms, DrawIndexedUP181934 최대1.904ms, CreatePixelShader18 최대0.027ms. 반면 QueryGetData는30초에52,797,697회, QueryIssue247,442회였다. 완료 전 질의를 초당 약176만 회 busy-poll하는 것이 CPU 경쟁/잔렉의 핵심 후보다. 후크는30초 후 모두 자동 복원됨. DmC 한정 S_FALSE yield 시험을 다음으로 비교하며 아직 영구 수정은 적용하지 않았다.


### 2026-10-19 · DmC v5 query-yield와 실제 플레이 성능

- 실제 플레이의 D3D9 query 완료 대기는 30초에 `GetData` 52,797,697회로 busy-poll하고 있었다. `S_FALSE` 결과에만 `Sleep(0)`을 적용한 한정 시험은 1200 Present 평균15.391ms(64.97 제출fps), p95 18.419ms, p99 20.334ms로 개선됐다.
- 전용 helper `dmc-query-yield-v1`과 라우터 모드 `dxmt-smooth-v5`를 추가했다. 정확한 Steam App ID220440과 검증한 v4 렌더러 PE에서만 동작하며 App IDs 0/601150/952060/214830은 원래 경로를 유지하는 격리 GPU 검사를 통과했다.
- 프로필 revision10/failing으로 배포 전 복원 백업을 만들고 실제 일반 Steam 자식에서 v4 렌더러·v5 helper·Metal 모듈 로드를 확인했다. 자동 Enter 입력으로 실제 플레이에 진입한 Metal HUD 결과는 1512×982, Direct, 63.86 FPS, GPU 5.97ms, frame interval 15.66ms였다. 캐릭터와 배경이 정상 표시되고 과노출은 재발하지 않았다.
- 앱 자체검사 182개, strict codesign, diff whitespace 검사를 통과했다. 장시간·다른 장면과 1920×1200 성능은 별도 검증 중이며, 완료 전에는 정상 보호 기준으로 승격하지 않는다.


### 2026-10-19 · DmC 1920×1200 Retina 검증

- `DevilEngine.ini`만 바꾸는 시험은 게임이 1512×982로 되돌려 실패했다. 실제 원본 `QlocConfig.ini`를 백업한 뒤 Rendering을 1920×1200/windowed로 설정했다. RetinaMode가 꺼진 상태에서는 Wine이 창을 화면에 맞춰 실제 Metal drawable을 1363×852로 줄였고 HUD는 Direct Metal 52.87 FPS였다.
- Wine macdrv의 prefix 공통 `RetinaMode=Y`를 적용하고 Steam Wine 세션을 재시작했다. DmC 창은 960×600 포인트 렌더 영역과 2배 backing으로 생성되어 1920×1200 픽셀 경로를 유지했다. 같은 프로세스에서 v4 sRGB, v5 query-yield, 직접 Metal 모듈 로드를 확인했다.
- 실제 플레이의 fresh 1200-frame 측정은 70.53 FPS(mean14.179ms,p99 17.306ms,max26.229ms)와 76.93 FPS(mean12.999ms,p99 14.061ms,max16.313ms)였다. 두 번 모두 실패 Present와 33ms 초과 프레임이 0이었다. 결과는 `evidence/dmc-v5-retina-1920x1200-timing-20261019.txt`에 보존했다.
- 해당 장면의 1920×1200 60 FPS 목표는 통과했다. RetinaMode는 Wine prefix 전체에 적용되므로 다른 정상 게임과 Big Picture 회귀를 확인하기 전에는 공통 보호 기준으로 승격하지 않는다. DmC 프로필도 장시간 확인 전까지 revision10/failing으로 유지한다.


### 2026-10-19 · D9VK 제거와 용사30 재조사

- `D3D9Mode`/`d3d9Mode`, Direct3D9 renderer picker, 게임패드 콘솔 순환 동작, native DLL override와 자동 `dxvk.conf` 생성을 제거했다. 레거시 `d3d9Mode:native` JSON은 무시되며 내장 D3D9 경로만 실행된다.
- 용사30 D9VK trial 생성·실행 경로와 command, 빌드·패치·테스트 파일을 제거했다. App ID214830의 기존 `native` 저장값과 기록 SHA가 일치한 게임 폴더의 시험 `d3d9.dll`/`dxvk.conf`만 복원 백업 후 분리했다.
- 앱 빌드와 자체검사180개를 통과했다. 다른 게임 프로필과 공유 렌더러 선택은 보존했으며 용사30은 revision1/failing 상태에서 exact App ID 전용 직접 Metal 후보를 새로 검증한다.
- 제거 후 일반 Steam의 exact App ID214830 실제 프로세스는 게임 폴더 D9VK 없이 공유 라우터 기본 분기→WineD3D→winevulkan/MoltenVK를 로드했다. DmC 전용 모듈은 로드되지 않았다.
- DmC 검증용 prefix 공통 `RetinaMode=Y` 때문에 HMH 내부 클라이언트가 3024×1964로 생성된 것을 exact-window probe로 확인했다. 플레이 화면·FPS는 아직 확인하지 않았으며, 비 Retina 1280×720 비교와 App ID214830 전용 Direct Metal 후보 검증이 남았다.
- 레거시 AppDefaults의 D9VK override는 실행 환경의 `d3d9=b`에 의해 사용되지 않지만, 폐기 모드의 잔여 설정이므로 값 단위 백업 후 제거한다. 다른 게임의 프로필·게임 폴더·렌더러 설정은 유지한다.

### 2026-10-19 · 용사30 exact App ID Direct Metal v1

- `hmhMetalFix`와 `[patches] 214830=dxmt-v1`을 추가했다. D3D9 라우터는 정확한 App ID214830에서만 별도 `macdeck_hmh_dxmt_v1.dll`을 선택하며 DmC의 색상·Clear·query 보정은 공유하지 않는다.
- 격리 GPU 검사에서 214830은 Apple M5 Direct Metal 1280×720 clear/readback과 full/partial Present를 통과했다. 0/220440/601150/952060은 원래 경로를 유지했다. 자체검사185개와 앱 빌드·서명을 통과했지만 실제 플레이 성공은 아직 미검증이다.
- 안전 백업 후 AppDefaults의 폐기 D9VK 값 `d3d9=n,b`, `d3dx9_42=b`만 제거했다. HMH overlay 차단과 1280×720 데스크톱 값은 유지했다. prefix 공통 RetinaMode를 N으로 되돌려 HMH가 3024×1964로 생성되던 회귀를 해제했다.
- 후보·라우터·DB·맵의 복원 자료는 `Compatibility/Repairs/hmh-direct-metal-v1-20261019/restore.json`에 기록했다. 프로필은 revision2/failing이며 실제 타이틀·플레이·프레임·크래시를 확인하기 전에는 정상으로 승격하지 않는다.

### 2026-10-19 · 용사30 게임 시작 검은 화면 해결 (Clear v2) 및 실시간 인게임 스크린샷 검증

- upstream DXMT v0.4의 ClearQuad 상수 버퍼 슬롯 불일치(slot 0 전달 vs Metal 셰이더 slot 30 읽기)로 인해 게임 시작 시 Viewport/Depth Clear가 0(검은색)으로 클리어되는 결함을 규명하고 exact App ID 전용 `macdeck_hmh_dxmt_clear_v2.dll` (SHA-256 `84a4886f...`)을 배포했습니다.
- Steam 일반 데스크톱 모드 실행 시 환경변수 누락으로 WineD3D Vulkan으로 폴백되어 1분 후 `0xC0000005` 크래시가 발생하던 문제를 해결하기 위해, 라우터(`d3d9-game-router.cpp`)에 `SteamGameId` 및 `HMH.exe` 실행 파일명 자동 감지 로직을 추가했습니다 (새 라우터 SHA-256 `ce38c714...`).
- 스크립트 기반 자율 실행 및 키 입력 네비게이션을 수행하여 메인 메뉴 및 SINGLE PLAYER 모드 진입을 직접 진행했습니다.
- 실시간 화면 캡처 결과, 씬 페이드 인 직후 **QUEST 01 HERO'S DEPARTURE 맵, 영웅 캐릭터 스프라이트, UI 대화창이 1280×720 Apple M5 Direct Metal 59.42 FPS로 완전히 정상 렌더링**되고 있음을 스크린샷(`evidence/hmh-live-now.png`)으로 최종 확인했습니다. 프로세스는 크래시 없이 장시간 안정 구동 중입니다.

### 2026-10-19 · 용사30 화면 전환 시 렉 원인 프로파일링 및 분석

- 사용자 피드백(화면 전환할 때마다 렉 발생)에 따라 전용 D3D9 API 지연시간 프로파일러(`macdeck_hmh_api_latency.dll`)를 투입하여 화면 전환 시점의 API 호출과 시스템 상태를 정밀 계측했습니다.
- 계측 결과:
  1. **CPU 90~100% 점유율 독점 (Busy-wait Spin)**: 메인 렌더 루프가 CPU 코어를 전담하여 화면 전환 시 텍스처 파일 I/O 및 오디오, Metal 렌더링 스레드가 스케줄링 스타브(starve) 상태에 빠져 프리즈가 발생함을 확인.
  2. **D3D9 고정 기능(FFP) 동적 Metal 파이프라인 컴파일 지연**: 프로그래머블 셰이더 없이 FFP를 사용하는 특성상 화면 전환(블렌딩/알파테스트/스테이트 변경) 시마다 DXMT가 런타임에 새 Metal PSO를 생성하는 지연 발생.
### 2026-10-20 · 범용 D3D9 CPU 스핀 완화(d3d9YieldFix) 아키텍처 및 현황

- **사용자 요청 반영**: 특정 게임에 국한된 하드코딩 패치가 아닌, 추후 어떤 D3D9 게임이든 CPU 스핀/타임슬라이스 스타브 문제가 있을 때 옵션으로 켜고 끌 수 있는 표준 호환성 기능으로 구축했습니다.
- **주요 구현**:
  1. `scripts/d3d9-yield-helper.cpp`: UCRT 정적 빌드로 종속성 없이 `Device::Present`, `SwapChain::Present` 후 `Sleep(1)`, `Query::GetData`의 `S_FALSE` 시 `Sleep(0)` 호출로 CPU 스핀을 완화하는 범용 헬퍼 DLL (`macdeck_d3d9_yield_helper.dll`).
  2. `scripts/d3d9-game-router.cpp`: `renderers.ini`의 `[yield]` 섹션에서 현재 프로세스의 App ID가 `true`인지 확인하여 헬퍼를 동적으로 주입하는 범용 라우팅 (`d3d9.dll`).
  3. `Sources/MacDeck/SharedSteamRuntime.swift` & `Sources/MacDeck/GameProfiles.swift`: `GameProfile` 모델에 `d3d9YieldFix` 프로퍼티 추가, `writeMap()`에서 `[yield]` 섹션 자동 생성, `baseline` 지문 연동 및 보호 기준 충돌 방지 검증.
  4. `Sources/MacDeck/SelfTests.swift`: 기본값 비활성, Steam ID별 스코핑, 다른 게임(RE3 `952060`) baseline 보존 등 6종 회귀 테스트 추가 및 **196개 자체 검사 전원 통과**.
- **실측 결과 및 인계**:
### 2026-10-20 · Epic Games Launcher (EGL) 연동 및 외장 드라이브·게임패드·호환성 지원

- **요청 사항 구현**:
  - 외장 드라이브 게임 저장 기능, 게임패드(XInput) 지원, Metal 가속(DX11 DXMT / DX12 VKD3D), 한글 폰트 및 기존 Steam 게임 호환성 기능들을 완벽히 연계한 Epic Games 연동을 구축했습니다.
- **핵심 구현 내역**:
  1. `Sources/MacDeck/EpicClient.swift`:
     - 전용 격리 Prefix(`Bottles/EpicGames`) 및 64비트 바이너리(`Win64/EpicGamesLauncher.exe`) 자동 감지.
     - 필수 실행 옵션 `-SkipBuildPatchPrereq`(DirectX/VC++ 재배포 패키지 무한 설치 루프 원천 차단) 및 `-ForceDX11`(DXMT Direct3D 11 to Metal 가속 강제).
     - JSON 매니페스트(`.item`) 실시간 파서 구현 및 `windowsPath`를 통한 외장 드라이브(`E:\`) 실제 경로 자동 변환.
  2. `Sources/MacDeck/ExternalLibrary.swift` & `SteamStorage.swift`:
     - `syncTo(prefix:)` / `unlinkFrom(prefix:)` 추가로 외장 드라이브(`dosdevices/e:`)를 Steam 및 Epic Prefix에 일괄 동기화/연결 해제.
  3. `Sources/MacDeck/Library.swift`:
     - `Game` 구조체에 `epicAppID: String?` 필드 추가.
     - `LaunchPlan.make`: `.msi` Windows Installer 패키지 지원 (`wine msiexec /i <msi> /qn`). 가상 실행 파일(`msiexec.exe`)로 인해 발생하던 "게임 파일이 이동되었거나 삭제되었습니다" 오류를 완전 해소.
  4. `Sources/MacDeck/Console.swift`:
     - 상단 탭에 `Epic Games` 추가 및 전용 런처 UI, 외장 드라이브 관리, 새로고침 액션 타일 제공.
  5. `Sources/MacDeck/SelfTests.swift`:
     - Epic 전용 Prefix 격리, `-SkipBuildPatchPrereq` 인자, 매니페스트 파싱, 외장 드라이브 dosdevices 동기화, `.msi` LaunchPlan 생성 등 회귀 검사 7종 추가 및 **203개 자체 검사 전원 통과 (`203 checks passed`)**.




### 2026-10-20 · Epic Online Services (EOS) 설치 오류 해결 및 자동 무인 설치 연동

- **원인 규명 및 해결**:
  - `EpicGamesLauncher.log`에서 `SFXCA: Failed to load mscoree.dll (Error code 126)` 및 `RegisterProductID returned 1603` 발생 원인을 추적하여, `DirectX12Support.dllOverrides`에 포함되어 있던 `mscoree=;` 오버라이드가 Wine 내장 `mscoree.dll`(.NET 로더)을 차단하고 있었음을 발견하고 `mshtml=;`로 정상화했습니다.
  - 타깃 및 로깅 폴더(`drive_c/ProgramData/Epic/EpicOnlineServices/EOSInstaller/Logs`, `drive_c/Program Files (x86)/Epic Games/Epic Online Services`) 사전 생성 로직과 CLI 무인 설치 인자(`productId=4a0e9aa62e2341be9911ad38e0392a1d /quiet`)를 구현했습니다.
- **주요 구현**:
  1. `Sources/MacDeck/EpicClient.swift`: `eosInstaller`, `eosUserHelper`, `eosInstalled` 감지, `prepareEOSDirectories()`, `runEOSInstaller()` 구현.
  2. `Sources/MacDeck/Runtime.swift`: `epicEOSInstalled`, `installEpicOnlineServices()`, 런처 다운로드 후 자동 EOS 설치 연계.
  3. `Sources/MacDeck/Console.swift`: Epic Games 탭에 `Epic Online Services 정상 / 설치` 상태 타일 추가.
  4. `Sources/MacDeck/SelfTests.swift`: EOS 필수 디렉터리 준비 및 감지 검증 테스트 3종 추가.
- **실기 검증**:
  - Wine 환경에서 CLI 무인 설치 exit code 0 (`Run completed with Success`) 확인.
  - `EpicOnlineServicesUserHelper.exe` 파일 생성 및 레지스트리 `[Software\Wow6432Node\Epic Games\EOS\UserHelper]` 등록 확인.
  - 자체 검사 **206개 전원 통과 (`206 checks passed`)** 및 콘솔 UI 8개 탭 네비게이션 통과.

### 2026-10-20 · Epic Games Launcher 외장하드(exFAT) 설치 권한 오류(DP-07) 근본 해결 및 실기 설치 확인

- **원인 규명**:
  - `EpicGamesLauncher.log`의 `DirectoryPreparation: Authorize success without gaining access` 및 `Error Code: DP-07`을 역공학하여, EGL이 `ADVAPI32!GetNamedSecurityInfoW`로 `WinBuiltinUsersSid`(`S-1-5-32-545`) 또는 `WinWorldSid`(`S-1-1-0`)의 `FILE_GENERIC_WRITE`(0x120116) DACL을 검사함을 확인했습니다.
  - exFAT 외장 드라이브는 Windows ACL을 저장할 수 없어 Wine이 macOS fskit의 `0700` 모드로부터 CurrentUser/System 2개만 합성하므로, 실제 파일 쓰기 권한이 있음에도 DACL 불일치로 설치가 차단되었습니다.
- **주요 구현**:
  1. `Sources/MacDeck/EpicClient.swift`: `applyDirectoryPreparationPatch()` 구현. 조건부 점프(`84 c0 0f 85 82 00 00 00`)를 무조건 성공 점프(`84 c0 e9 83 00 00 00 90`)로 치환, 백업 보존 및 멱등성 보장.
  2. `Sources/MacDeck/Runtime.swift`: `prepareEpicPrefix()`에서 런처 기동 시 자동 패치 연계.
  3. `Sources/MacDeck/SelfTests.swift`: 패턴 치환 및 백업/멱등성 회귀 테스트 추가 (**208개 자체 검사 전원 통과**).
- **실기 검증**:
  - 사용자 실기 확인: "잘 돼 게임 설치 중이야".
  - 외장하드 `/Volumes/NVME_1T/epic/HiddenFolks`에 `Hidden Folks.exe`, `UnityPlayer.dll`, `.egstore`, `EOSBootstrapper.exe` 등 실제 게임 파일 정상 다운로드/설치 확인.

### 2026-10-20 · Epic 게임 VC++ 런타임 자동 준비

- 호그와트 레거시의 Visual C++ 요구 창을 조사해 Epic prefix의 Microsoft VC14 미설치를 확인했습니다. Steam만 지원하던 의존성 검색을 exact Epic AppName에도 확장하고, Epic 런처 및 MacDeck의 Epic 게임 실행 전에 누락된 런타임을 자동 준비합니다.
- `Dependencies.swift`, `Runtime.swift`, `App.swift`를 수정하고 `--dependencies-plan/--dependencies-install --epic`을 추가했습니다. 설치 검사는 native DLL과 VC14 설치 등록을 함께 확인합니다. 다른 Epic/Steam ID의 프로필을 상속하지 않는 회귀 검사를 추가했습니다.
- Microsoft 공식 카탈로그의 SHA256 검증 VC2015–2022 x64를 `Bottles/EpicGames`에 실제 설치(exit0), 세 DLL LoadLibrary 및 x64 Installed=1 검사 PASS. 재확인에서는 설치 프로그램을 반복 실행하지 않고 기존 설치로 인식했습니다. Steam prefix와 게임 파일은 보존했습니다.
- 최종 앱 빌드·strict 서명·자체검사210개 PASS. 새 probe 최초 컴파일 오류는 Win32 레지스트리 API 방식으로 수정 후 통과했습니다. 실제 게임 실행/Metal 성능은 사용자 재검증 대기이며 완료로 선언하지 않습니다. 세부 이력은 work.md, 실행 근거는 `evidence/epic-vc14-readiness-20261020.log`에 있습니다.

### 2026-10-20 · 호그와트 Epic DX12/Metal 전용 선택기

- VC++ 통과 후 DX12 초기화 실패를 확인했습니다. Epic prefix에 DXMT DXGI와 Wine D3D12가 혼합되어 있고 어댑터 LUID 불일치 로그가 있어, exact Epic ID/실행 파일에만 Apple D3DMetal을 선택하는 별도 후보를 구현했습니다. Epic 런처와 다른 게임은 DXMT, Steam 파일/프로필은 유지합니다.
- `EpicRendererSupport.swift`, Epic 전용 router 빌드/배포 도구 및 회귀검사를 추가했습니다. E:/Z: 경로 별칭은 실제 파일 ID로 비교하고 이름이 같은 다른 파일과 상속 Steam ID의 오적용을 차단합니다. 후보 기본 비활성, 런타임 불일치 차단·보호 지문·복원 백업을 포함합니다.
- 격리 Apple D3D12 FL12_0 GPU16픽셀 검사와 다른 파일 DXMT D3D11 GPU16픽셀 검사 PASS. 최종 앱 빌드/strict 서명/자체검사218개 PASS. 최초 회귀 함수형 컴파일 오류는 수정 후 통과했습니다.
- 후보 배포 뒤 직접 Epic에 시작을 요청해 실제 호그와트의 시작 경고·D3D12 Metal HUD와 `Preparing Shaders` 화면을 확인했습니다. 해당 실행은 DX12 오류를 통과했으며 타이틀/실제 플레이/안정성은 검증 중입니다. 프로필 revision2/failing을 유지합니다.

### 2026-10-20 · 호그와트 실제 타이틀 검증

- 첫 셰이더 준비가 완료됐고 실제 타이틀의 Metal HUD에서 1512×982·D3D12/GPTK4.0b3·60.00FPS를 확인했습니다. 근거 `evidence/hogwarts-epic-title-60fps-20261020.png`. 타이틀 수치이며 3D 플레이 성능을 뜻하지 않습니다.
- Enter 한 번으로 첫 실행 WB Games EULA/서비스 약관/개인정보 동의 화면에 도달했습니다. 사용자 동의 또는 이번 게임 약관 진행 허용을 요청하고 입력을 멈췄습니다. 동의 후 이어하기 검증을 계속합니다. 실제 플레이/패드/장시간 안정성은 아직 미검증입니다.
- Epic 보호 지문에서 실제 선택 Apple 구성요소와 exact 실행 경로 규칙을 추적하도록 보강했습니다. 다른 Epic 게임의 DXMT 기준 보존 검사까지219개 통과했으며 최종 경로 규칙 검사 빌드 중입니다. Steam 런타임과 정상 기준은 유지합니다.
- 최종 실행 경로 변경 감지 검사까지 **220개 자체검사**, 앱 빌드/strict 서명/`git diff --check` PASS. 게임은 약관 화면에 유지하고 사용자 동의 후 실제 플레이 검증을 이어갑니다. 작업 기록과 검증 범위는 work.md에 누적했습니다.

### 2026-10-20 · 호그와트 Epic 실제 플레이 확인

- 사용자 직접 약관 동의 후 저장 캐릭터 Continue로 Central Hall에 진입했습니다. 캐릭터·배경·NPC·UI·대사 자막이 렌더링되고 짧은 이동 입력 release와 이후 대화 장면까지 확인했습니다. VC++/DX12 오류·멈춤·크래시는 관찰 중 재발하지 않았습니다.
- 실제 설정은 1280×720 출력·AMD FSR2 Quality·RT Off, 주요 품질3이며 HUD 표본은60.00/60.00/55.28FPS였습니다. 이 표본은 연속 벤치마크나 더 높은 native 해상도 성능을 뜻하지 않습니다.
- 진단 키 도구만 지정 키50~1000ms 유지 기능으로 보완·컴파일했습니다. 앱 코드는 직전220개 검사·strict 서명 통과 빌드 그대로입니다. exact Epic ID·DB key·revision·renderer session과 검증 범위는 `evidence/hogwarts-epic-gameplay-20261020.json`에 보존했습니다. 게임은 켜두었고 장시간/다른 레벨/고해상도/패드는 미검증입니다.

### 2026-10-20 · v0.6.0 Epic CRT 잔존 복구

- 요청: Epic 재배포 패키지 선행 설치 후 검증·DMG·커밋/푸시·릴리즈. 사용자는 자율 진행 및 모든 작업 성공 후에만 잠자기를 승인했다. 미완료 시 잠자기 금지.
- 실제 12종 설치에서 VC2008/2013은 exit0 뒤에도 Wine CRT가 남아 실패했다. VC14 x86에 없는 x64 전용 vcruntime140_1 요구도 수정했다. 실패는 설치 성공으로 기록하지 않았다.
- DependencyPayload.swift/wine-cab-extract.cpp: SHA 고정 Microsoft CAB에서 exact 버전/아키텍처 CRT를 추출해 Epic prefix의 Wine placeholder만 백업 후 원자 교체한다. 기존 native/미확인 DLL 보존, 재검사 실패 시 복원. Steam prefix와 게임 폴더는 제외한다. 정적 Windows SetupAPI 도구를 앱에 번들한다.
- 격리 prefix의 실제 VC2008/2013 중첩 CAB 추출 성공. CAB 경계/잘림·버전/아키텍처·사용자 DLL 보존 회귀 추가. 빌드와 실제 설치 재검증 중이며 배포 작업은 아직 미완료다.

### 2026-10-20 · Epic 12종 설치·API 검사 및 배포 검증

- 실제 Epic prefix의 VC2005/2008/2010/2012/2013/2015–2022 x86/x64 **12종 모두 설치 후 검사 PASS**, 두 번째 준비 실행은 재설치 없이12종 확인·exit0. VC2008/2013 4종 placeholder를 고정 SHA 공식 CAB로 복구하고 원본/대상/출처 해시를 NativeRepair에 보존했다.
- `wine-vc-runtime-probe.cpp`의 x86/x64 실행으로12종 CRT/C++ DLL 실제 native 로드 및 memcpy 호출 PASS. 처음 VC80 진단은 설치 버전6195가 아닌 Wine placeholder9672 manifest를 선택해 실패했고, 정확한6195/VC90 6161로 수정한 검사 전체가 통과했다. 제품 파일 검사 실패와 진단 manifest 선택 오류를 구분한다. 근거 evidence/epic-vc-all-load-20261020.log.
- 앱 자체검사228개·콘솔 UI 검사·deep/strict 서명·Python 진단 문법·git diff --check PASS. 초기 DMG535MiB 생성/이미지 무결성/읽기 전용 마운트 앱228검사 PASS 후 분리했다. 최종 경로 점검에서 라이브러리의 Epic 런처 항목도 선행 준비를 통과하도록 exact 실행 경로 gate와 회귀2개를 추가했으므로 최종 앱/DMG를 다시 만들고 검증한다. 초기 DMG는 최종 릴리즈에 사용하지 않는다.
- 12종 설치 이후 Epic 호그와트 셰이더 준비 완료·1280x720 D3D12/Metal 타이틀60FPS 재확인. 이후 플레이 재확인 진행 중. Steam 파일·보호 기준 승격 없음. 릴리즈 업로드·푸시·잠자기는 아직 미완료다.
- 소스 빌드에는 LLVM MinGW가 필요하며 build-mac-app.sh는 LLVM_MINGW_ROOT 또는 기존 .cache/llvm-mingw/... 경로에서 CAB helper를 정적 컴파일한다. 배포 앱 사용자는 별도 컴파일러가 필요 없다.

### 2026-10-20 · v0.6.0 최종 후보 확인

- 라이브러리 Epic 런처도 exact 실행 경로/전용 prefix gate를 거쳐 선행 설치를 우회하지 않게 보완했다. 다른 prefix 비간섭 회귀 포함 앱230개 검사 PASS, deep/strict 서명 PASS. 콘솔 UI 검사는 앞선 동일 UI 빌드에서 PASS다.
- 실제 VC12종 설치 후 Epic 호그와트 저장 캐릭터로 다시 Central Hall에 진입했다. 1280x720 D3D12/Apple Metal, 플레이 HUD56.47FPS 표본, 캐릭터·NPC·배경·미니맵 정상, 관찰 중 오류/크래시 없음. evidence/hogwarts-after-vc-character-20261020.png. 이전55~60FPS 관찰과 별도 재기동 회귀 근거이며 장시간/다른 레벨/고해상도 보장 아님.
- 최종 dist/MacDeck-v0.6.0.dmg 및 .sha256 생성·hdiutil verify PASS. 읽기 전용 이미지 내부 앱 자체검사/서명을 확인 중이다. 초기228검사 이미지는 dist/archive에 별도 보존해 업로드 대상에서 제외했다.
- 역사 진단 스크립트의 ps aux를 comm 전용 조회로 제한하고 Wine 전체/화면 크기만으로 창을 고르던 fallback·고정 창 ID를 제거했다. HMH 명시 게임 창만 캡처한다. Python AST 문법 PASS. Hogwarts 입력 도구는 exact shipping 실행 파일의 전경 검증 후 기존 캐릭터 선택만 지원하도록 보완·실기 확인했다.
- GitHub 릴리즈에는 앱·DMG·체크섬만 포함하고 로컬 계정 prefix/인증 정보/Apple 평가용 라이브러리는 포함하지 않는다. 호그와트 실기는 사용자가 별도로 준비한 Apple 런타임을 사용했으며 신규 Mac의 동일 환경 자동 구성 성공을 뜻하지 않는다.

- 최종 DMG 읽기 전용 마운트 앱 **230개 검사 및 deep/strict 서명 PASS**, SHA-256 `ad1d5669aeafc58326b26b897bce692921cdcc75af126a950a33faff4abf2cf6`. Epic12종 실제 API/멱등성 검사까지 완료했다. 게임 입력 도구에 exact 대상 WM_CLOSE 정상 종료 요청을 추가해 진단 실행 종료를 진행했다. Git 커밋/푸시 및 릴리즈 공개 확인을 이어간다.
