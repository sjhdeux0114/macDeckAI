# MacDeck (macDeckAI)

> **Apple Silicon Mac을 위한 Steam 머신 경험 및 Windows 게임 Metal 가속 런처**

MacDeck(macDeckAI)은 Apple Silicon(M-시리즈) Mac 환경에서 Windows 게임과 Windows Steam Big Picture 모드를 네이티브에 가깝게 즐길 수 있도록 돕는 오픈소스 프로젝트입니다.

---

## 📸 미리보기

| MacDeck 라이브러리 UI | Windows 게임 Metal HUD 구동 (Brogue CE) |
|---|---|
| ![MacDeck App](evidence/macdeck-app.png) | ![Metal HUD Game](evidence/macdeck-v02-game-metal.png) |

---

## ⚡ 주요 특징

1. **Apple Silicon 네이티브 UI & Steam Big Picture 연동**
   - SwiftUI / AppKit 기반의 깔끔한 macOS 네이티브 인터페이스.
   - 공식 Windows Steam 클라이언트를 백그라운드 환경에 설치하고, Steam Big Picture 모드를 한 번의 클릭 또는 패드 입력으로 실행.
   - Steam 라이브러리(`libraryfolders.vdf`, `appmanifest`)를 자동 파싱하여 MacDeck 런처에 동기화.

2. **Apple Metal 하드웨어 가속 듀얼 그래픽 파이프라인 (DX10/11 & DX12)**
   - **WineSikarugir 10.0 (x86_64, Rosetta 2)** 기반 호환성 레이어.
   - **DirectX 10 / 11 → DXMT 0.80**: Direct3D 10/11 호출을 Apple Metal로 직접 변환하며, `SetRotation(IDENTITY)` 호환 패치를 적용하여 SDL2/D3D11 게임의 OpenGL 강제 대체를 방지.
   - **DirectX 12 → VKD3D 1.14 + MoltenVK 1.4.1**: 게임 폴더 내 Agility SDK(`D3D12Core.dll`), 설정 파일(`Capability=DirectX12`), 또는 실행 파일 임포트를 자동 감지하여 Wine D3D12 DXGI 브리지와 MoltenVK(`libvulkan.1.dylib`)를 통해 Apple Metal 3로 가속.
   - Apple Metal HUD (`⌘F9`) 및 프레임 레이트/GPU 부하 실시간 모니터링 지원.

3. **외장 SSD/HDD 게임 라이브러리 지원 및 시작 시 자동 연결**
   - 내장 SSD 용량이 부족한 Mac 환경을 위해 외장 저장장치(NVMe/SSD/HDD)의 게임 설치 폴더를 Wine 가상 드라이브(`E:\SteamLibrary` 등)로 매핑.
   - **앱 실행 시 설정된 외장 게임 설치 폴더가 있으면 드라이브 심볼릭 링크와 Steam `libraryfolders.vdf` 등록 상태를 자동으로 연결·복구**.
   - 연결 해제 시에도 외장 드라이브의 실제 게임 파일은 안전하게 보존.

4. **게임패드 완벽 지원 (콘솔 모드)**
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

### 🎲 3D 게임: DX11(DXMT) & DX12(VKD3D/MoltenVK) 파이프라인 구축 및 집중 테스트 진행 중
- **현재 상태:**
  - **Direct3D 10/11 (DXMT → Metal)** 및 **Direct3D 12 (VKD3D 1.14 → winevulkan → MoltenVK 1.4.1 → Metal 3)** 듀얼 가속 파이프라인이 구축되어 있습니다.
  - 외장 NVMe 드라이브(`E:\SteamLibrary`)에 설치된 **Resident Evil 3 (`re3.exe`, DirectX 12)** 실행 시 Apple M5 Metal 3 장치 생성 및 스왑체인 렌더링(`d3d12_swapchain_Present`) 초기 구동 확인을 완료했습니다.
  - 각 게임 실행 설정에서 그래픽 백엔드를 **자동 감지(DX11/DX12)** 하거나 수동으로 전환할 수 있습니다.
- **향후 계획:**
  - 3D 게임은 복잡한 셰이더 연산, 엔진별 DirectX 11/12 특성, 안티치트(Anti-Cheat) 솔루션, 런타임 종속성(Visual C++ 재배포 패키지 등), 장시간 플레이 안정성 등 다양한 변수가 존재하므로 **앞으로도 다양한 3D 타이틀을 대상으로 테스트를 집중적으로 많이 수행해봐야 하는 단계**입니다.
  - 진단 시스템을 활용하여 각 3D 타이틀별 오류 패턴을 분석하고 순차적으로 호환성을 개선해 나갈 계획입니다.

### ☁️ Steam 클라이언트 및 외장 스토리지 연동
- Valve 공식 Windows `SteamSetup.exe`를 통한 설치, 최신 클라이언트 업데이트, Big Picture 로그인 및 외장 NVMe SSD(`E:\SteamLibrary`) 게임 다운로드·설치 검증 완료.
- 앱 재실행 시 설정된 외장 게임 설치 폴더 자동 재연결 및 총 **68개 자체 검증 테스트(`--self-test`) 통과**.

---

## 🏗️ 아키텍처

```text
┌─────────────────────────────────────────────────────────────────┐
│                    MacDeck.app (SwiftUI / AppKit arm64)         │
│  - 라이브러리 관리       - 외장 드라이브 자동 연결 - 게임패드 내비게이션 │
│  - 진단 및 ZIP 내보내기  - DX11/DX12 자동 감지   - 세션 로깅          │
└─────────────────────────────────┬───────────────────────────────┘
                                  │ 실행 (LaunchPlan)
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│               Rosetta 2 + WineSikarugir 10.0-8 (x86_64)         │
│  - Windows 환경 에뮬레이션 (drive_c, dosdevices)                  │
│  - Windows Steam (Big Picture) & Windows Game .exe              │
│  - Builtin XInput 게임패드 지원                                   │
└──────────────────┬──────────────────────────────┬───────────────┘
   Direct3D 10/11  │                              │ Direct3D 12
                   ▼                              ▼
┌──────────────────────────────────┐ ┌────────────────────────────┐
│  DXMT 0.80 (SetRotation 패치)    │ │ Wine D3D12 (VKD3D 1.14)    │
│  - D3D10/11 → Metal 직접 변환     │ │ + Wine DXGI Native Bridge  │
│  - _macdrv_functions Metal View  │ │ + MoltenVK 1.4.1 (Vulkan)  │
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

## 📄 라이선스

본 프로젝트의 자체 소스 코드는 **GPL-3.0** 라이선스로 배포됩니다.
포함되거나 연계되는 외부 런타임(Wine, DXMT, SDL2 등)은 각 프로젝트의 원본 라이선스를 준수합니다. 자세한 내용은 [`LICENSE`](LICENSE) 및 [`licenses/`](licenses/) 디렉터리를 참고하십시오.
