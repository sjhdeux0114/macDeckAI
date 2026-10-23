# MacDeck 다른 PC 인계 — 2026-10-24

## 새 담당자에게

루트 `AGENTS.md`, 이 문서, `work.md` 끝의 최신 날짜 기록, 관련 `docs/` 순으로 읽는다. README/work의 오래된 상단 상태는 과거 시점이며 최신 누적 기록을 우선한다. 사용자의 목표는 macOS Steam 머신 경험, 실제 Steam 로그인/게임 실행, Metal 가속, 외장 게임 설치 및 앱 시작 시 자동 연결이다.

이번 요청은 기존 PC 초기화에 앞선 개발 인계 문서 작성과 커밋/푸시다. PC 삭제·초기화, 사용자 데이터 백업이나 외장 복사는 실행하지 않았다. **이 문서와 Git만으로 기존 PC 데이터 전체가 복원되지는 않는다.** 인증 정보나 Steam 인증 파일은 읽거나 문서에 담지 않았다.

## 소스와 배포 기준

- 저장소: https://github.com/sjhdeux0114/macDeckAI.git , 브랜치 `main`.
- 인계 전 HEAD: `f7ae958` (v0.6.0 배포 완료 기록), 구현 커밋 `9b309fdd93b94547f2394a85eb3faf3f1f80f6f5`.
- 앱 v0.6.0/build15, Apple Silicon arm64, macOS 13 최소 빌드 대상. 기존 실기: Apple M5/24GiB/macOS 27.0.1. 타 기기 호환 검증과 구분한다.
- 사전 릴리즈: https://github.com/sjhdeux0114/macDeckAI/releases/tag/v0.6.0
- 배포 DMG SHA256: `ad1d5669aeafc58326b26b897bce692921cdcc75af126a950a33faff4abf2cf6`.
- 2026-10-20 기록 기준 앱 자체검사230개, 콘솔 UI, strict 서명, DMG 내부 앱 검사, Epic VC12종 실제 API/멱등성 검사 PASS. 이번 인계에서 모든 게임을 다시 실행한 것은 아니다.

## 삭제 전 별도 보관할 데이터

아래는 위치와 용도 목록이다. 자동 백업 또는 원격 업로드 완료를 뜻하지 않는다. 비공개 사용자 백업은 암호화된 외장 저장소/개인 백업으로 별도 보관하고 Git에는 올리지 않는다. prefix에는 로그인 세션이 포함될 수 있으므로 전체 prefix를 공개 저장소에 추가하지 않는다.

| 위치(기존 Mac) | 내용 / 복원 시 유의사항 |
| --- | --- |
| `~/Library/Application Support/MacDeck/library.json` | 라이브러리·실행 옵션·경로. 사용자명/저장소 경로가 달라지면 재설정 필요 |
| `~/Library/Application Support/MacDeck/Compatibility/` | `game-profiles.json`, revision·기존 정상 보호 지문·History·Repairs. 기존 지문을 새 환경으로 자동 승인하지 말 것 |
| `~/Library/Application Support/MacDeck/Bottles/` | Steam/Epic 등 Wine prefix, 설치 상태 및 prefix 안의 로컬 저장게임. 계정 정보가 섞일 수 있는 비공개 데이터 |
| `~/Library/Application Support/MacDeck/Games/` | 내장 게임 데이터 및 저장 위치 후보 |
| `~/Library/Application Support/MacDeck/SharedSteamRenderer/` | 공유 렌더러 상태. 새 런타임 경로와 반드시 대조 |
| `~/Library/Application Support/MacDeck/Dependencies/`, `Installers/` | 필수 런타임 설치 영수증·복구 자료·설치 캐시. 실제 DLL 준비 여부는 재검사 |
| `~/Library/Application Support/MacDeck/Logs/`, `CompatibilityLab/`, `GameTrials/` | 비공개 진단/시험 상태. 원시 인증 출력·덤프는 공유하지 말 것 |
| 저장소 `.cache/` (약18GB) | LLVM MinGW, DXMT 원본/후보, 런타임·수정 전 백업·격리 prefix·저장 백업. 전부 재다운로드 가능한 캐시로 간주하면 안 됨 |
| 저장소 `.build/` (약531MB) | Swift 산출물과 common/D3D9/Epic 라우터 등 실험 바이너리. 소스 외 재현 자료 포함 가능 |
| 저장소 `dist/` (약2.8GB) | 현재 앱·런타임·DMG·보관 이미지. 공개 DMG와 사용자 Apple 런타임을 포함한 로컬 앱은 구분 |
| 저장소 `evidence/` (약144MB), `logs/` | 실기 근거. evidence는86개 파일만 Git 추적 중이며 나머지는 ignore 대상 |
| 저장소 `upstream/` (약222MB), 루트 Apple 평가용 DMG | 외부 원본/Apple 런타임. Git 미포함, 사용 조건에 따라 별도 준비 |
| 과거 `/Volumes/NVME_1T/SteamLibrary`, `/Volumes/NVME_1T/epic/` | 외장 게임 파일·manifest. 외장 디스크 자체 보존 필요. 인계 점검 시 `/Volumes`에는 해당 볼륨이 없어 현재 파일은 재확인하지 못함 |

Steam Cloud/Epic Cloud에 저장됐다고 가정하지 않는다. 게임별 `drive_c/users/.../AppData`, Documents, Steam userdata 등의 실제 저장 위치는 새 PC로 옮기기 전에 사용자 개인 백업으로 확인한다. 이번 작업에서는 인증 파일을 피하기 위해 prefix 내부를 열람하지 않았다. Keychain·macOS 권한·Rosetta·개인 Codex 채팅/설정은 Git 복원 대상이 아니다. 다음 담당자에게는 이 문서를 전달하면 된다.

## 새 Mac에서 이어가기

```sh
git clone https://github.com/sjhdeux0114/macDeckAI.git
cd macDeckAI
git switch main
git pull --ff-only
cat AGENTS.md
cat docs/PC-MIGRATION-HANDOFF.ko.md
```

1. Apple Silicon Mac에 Xcode Command Line Tools/Swift, Python3를 준비한다. 기존 인계 시 Swift6.4, `/Library/Developer/CommandLineTools`를 확인했다. x86_64 Wine에는 Rosetta가 필요하다. Metal 셰이더 재컴파일은 별도 Xcode와 Metal Toolchain 필요(`docs/runtime-patches.md`).
2. 비공개 백업이 있으면 앱·게임·런처를 종료한 상태에서 MacDeck Application Support와 필요한 실험 바이너리를 복원한다. `dosdevices` 외장 링크, 절대 경로, 앱 경로, 사용자명, macOS 파일 접근 권한은 새 환경에서 재확인한다. 기존 앱은 `dist/MacDeck.app` 단독 사용 정책이었다.
3. 공개 배포 앱만 필요하면 v0.6.0 릴리즈 DMG/체크섬을 내려받아 비교한다. Apple 평가용 D3DMetal은 배포본에 포함되지 않으므로 과거 호그와트/엘든링 환경과 동일하다고 가정하지 않는다.
4. 소스 앱 빌드에는 LLVM MinGW UCRT가 추가로 필요하다. `scripts/build-mac-app.sh`의 기본 경로는 `.cache/llvm-mingw/llvm-mingw-20261006-ucrt-macos-universal`; 다른 설치 위치는 `LLVM_MINGW_ROOT`로 지정한다. 라우터 빌드 Python 일부는 기본 캐시 경로를 직접 참조한다.

```sh
swift build
# LLVM MinGW 설치/복원 후 실행
bash scripts/build-mac-app.sh
dist/MacDeck.app/Contents/MacOS/MacDeck --self-test
codesign --verify --deep --strict dist/MacDeck.app
# UI 세션이 있는 Mac에서 실행
dist/MacDeck.app/Contents/MacOS/MacDeck --console-ui-test
```

`build-mac-app.sh`는 Swift 앱/CAB helper 빌드이며 전체 게임 런타임 준비를 대신하지 않는다. `package-mac-app.sh`는 `prepare-metal-runtime.py`를 호출하며 기존 번들 Runtime을 지우고 pinned Wine/DXMT 기반으로 재생성한다. **복원한 실험 런타임 위에서 무작정 실행하지 않는다.** 먼저 별도 사본에서 준비하고 `docs/runtime-patches.md`, `DMC-D3D9-RECOVERY.ko.md`, `DMC5-GSTS-RECOVERY.ko.md`, `DX9-HALF-MINUTE-HERO.ko.md`와 스크립트의 입력 해시를 대조한다. 이 준비 스크립트 하나로 모든 최종 게임 후보가 복원되는 것은 아니다.

5. 외장 볼륨을 연결하고 앱에서 라이브러리/런타임 경로를 다시 선택한다. E: 매핑의 Steam/Epic prefix 동시 재연결을 확인한다. 이번 PC에서는 외장 미연결이므로 자동 재연결을 재검증하지 않았다.
6. Steam/Epic은 필요 시 사용자가 직접 재로그인한다. 로그인 창 표시, 인증 완료, 게임 프로세스 생성, 실제 3D 플레이와 Metal HUD를 각각 확인한다. 새 기기 성능은 새 session으로 기록한다.
7. 검사 실패 시 파일/로그/정확한 App ID/DB key/revision/원본 session ID/재현 절차를 보존한다. 기존 정상 보호 기준 변경 경고를 우회하거나 자동 승인하지 않는다.

## 최근 게임 상태와 남은 일

| 게임 / exact ID | 마지막 근거와 다음 확인 |
| --- | --- |
| Epic 호그와트 `epic:fa4240e57a3c46b39f169041b7811293` | revision2/failing 유지. 전용 Apple DXGI/D3D12 선택기, VC12종 준비 후 저장 게임 Central Hall1280×720 FSR2 Quality/RT Off55~60FPS 표본. 장시간·다른 레벨·고해상도·패드/오디오 별도 확인 |
| 엘든링 Steam1245620 | 사용자1920×1200/60FPS·입력 정상 보고, Apple D3DMetal/MSync1/ESync0/SDL 조합. Big Picture 재실행·장시간·다른 게임 회귀 확인 필요 |
| RE3 Steam952060 | DX11 non-RT 사용자 정상 보고. 과거 DX12 GPU timeout은 해결로 취급하지 않음 |
| DMC5 Steam601150 | exact GS/TS 보완 후보 revision3, 사용자 긴 렉 해소 보고. 이후 동일 로딩 구간 재검증 필요 |
| DmC Steam220440 | v5 Direct Metal1920×1200 실기70.53/76.93FPS, 실패 Present0·과노출 재발 없음. revision10/failing 유지, prefix 공통 RetinaMode의 타 게임 영향과 Steam 시작 요청 무응답 별도 확인 |
| 용사30 Steam214830 | clear-v2 Direct Metal1280×720 약60FPS 실기. 화면 전환 렉은 남아 사용자 요청으로 튜닝 종료. D9VK 재도입 금지 |

새 조정은 정확한 App ID/로컬 UUID와 revision에만 적용한다. 게임 폴더 DLL/INI 일괄 수정·공유 Steam 환경에 게임별 실험 주입 금지. 다른 게임 보존과 보호 지문 변경 감지 회귀를 포함한다. 실제 플레이 결과가 있어도 DB failing을 자동 승격하지 않는다.

## 인계 작업 검증 범위

2026-10-24: 시작 시 git 변경 없음, 브랜치 main/원격 origin과 위 디렉터리 존재·용량·도구 버전·소스의 경로/빌드 진입점을 확인했다. 실제 백업 복원, 새 PC 빌드, 계정 로그인, 외장 드라이브/게임 플레이는 미검증이다. 인증 파일·토큰·QR·덤프는 수집하지 않았다. 소스 변경 없이 문서만 추가/갱신한다. 최종 커밋/푸시 결과는 작업 응답과 Git 원격 이력으로 확인한다.
