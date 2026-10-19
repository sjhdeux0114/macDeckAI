# 30초전사 DX9 조사와 D9VK 수정

2026-10-18. Steam AppID 214830, HMH.exe x86. 현재 **실험 수정본**이며 지속 플레이·프레임률·화면 잘림은 사용자 검증 전이다. RE3/DMC5의 DXMT 런타임은 교체하지 않았다.

## 실제로 확인한 결함

1. Sikarugir-App/d9vk 태그 `v1.10.3-20240229`, 소스 커밋 `afae08756737382c1e91c398a2b7053a44f59ed9`의 `lookupFormatInfo`가 확장 포맷에서 자기 자신을 호출한다. 최적화된 x86 DLL은 확장 enum을 일반 배열 인덱스로 사용했고, HMH의 YV12 텍스처 생성 중 `D3D9CommonTexture::GetMipSize`에서 크래시했다. EBP `0x3b9d2b62`는 실제 YV12 Vulkan 포맷 값이다.
2. 같은 소스에는 YV12의 3-plane 포맷 정보가 빠져 있다. 느린 조회 함수 호출뿐 아니라 평면별 바이트 크기·chroma subsampling과 포맷 그룹도 추가했다.
3. `PFN_wineLogOutput`은 stdcall로 선언됐으나 Wine 10 `ntdll.spec`의 `__wine_dbg_output`은 cdecl이다. LLVM x86 빌드가 첫 로깅 이후 스택 손상으로 종료되어 선언을 수정했다. x64에서 호출 규약 차이가 무시된다고 x86까지 안전한 것은 아니다.

근거: [포맷 조회 원본](https://github.com/Sikarugir-App/d9vk/blob/v1.10.3-20240229/src/dxvk/dxvk_format.h), [포맷 테이블](https://github.com/Sikarugir-App/d9vk/blob/v1.10.3-20240229/src/dxvk/dxvk_format.cpp), [로깅 선언](https://github.com/Sikarugir-App/d9vk/blob/v1.10.3-20240229/src/util/log/log.h), [Wine의 실제 export](https://github.com/wine-mirror/wine/blob/wine-10.0/dlls/ntdll/ntdll.spec).

## 검사 결과와 한계

- 실제 수정 소스를 링크한 x86 테스트: 기본 포맷 전체, YV12 평면·subsampling, NV12와 확장 packed 포맷, 미지원 값 거절 등 8개 검사 그룹 통과.
- 실제 Wine `__wine_dbg_output`을 호출하는 x86 로거 검사: 64회 반복 호출 통과.
- 게임의 수정 DLL 버전 라벨 확인. Apple M5, MoltenVK와 CAMetalLayer 1280×720 swapchain 생성 기록 확인.
- 게임 창 캡처에서 컨트롤러 안내 화면 전체를 확인했다. 이것은 인트로 출력 증거이며 타이틀·게임 플레이·60fps 보장은 아니다.
- 이전 WineD3D GL 비교는 사용자가 심한 버벅임과 잘림을 보고해 실패로 분류했다. DXMT D3D9 포크 비교도 assertion과 검은 화면이 있어 채택하지 않았다.
- 이전 native d3dx9_42.dll의 x87 픽셀 변환 루프는 실제 CPU hot spot이었다. 그것이 모든 문제의 단독 원인이라는 의미는 아니다. 현재 시험에는 builtin d3dx9_42를 사용한다.

## 재빌드

캐시 준비 후 `python3 scripts/build-d9vk-macos.py` 실행. 이 스크립트는 게임이나 설치 앱에 파일을 배포하지 않는다. 준비한 소스에 세 패치를 적용하거나 이미 적용됐음을 확인하고, x86 DLL과 두 테스트 EXE를 만든다. 입력 archive SHA-256과 출력 DLL SHA-256은 `evidence/d9vk-build-manifest.json`에 기록한다. 소스 캐시에 추가 변경이 없는지도 별도 검토해야 한다.

준비 입력:

- 소스 태그 archive와 `include/vulkan`, `include/spirv`의 정확한 gitlink 커밋. Vulkan `85c2334e92e215cce34e8e0ed8b2dce4700f4a50`, SPIR-V `0bcc624926a25a2a273d07877fd25a6ff5ba1cfb`.
- [LLVM-MinGW 20261006 macOS universal UCRT](https://github.com/mstorsjo/llvm-mingw/releases/tag/20261006). 게시자 SHA-256 `a7a19b11048e89372637d26279cdb7c430ed3cf8c1e224310421312bf986ebf6` 확인.
- [glslang 16.6.0 macOS universal release](https://github.com/KhronosGroup/glslang/releases/tag/16.6.0).
- `.cache/d9vk-build-tools` venv의 Meson 1.11.2, Ninja 1.13.2. 헤더·도구는 `.cache`에만 있다. 소스 archive 해시는 로컬 고정 입력 해시이며 별도의 게시자 서명을 뜻하지 않는다.
- LLVM/현대 MinGW 빌드에는 portability 패치를 적용하고 `DXVK_HAVE_D3DDEVINFO_RESOURCEMANAGER=1`을 지정한다. 이전 SDK의 dummy typedef와 충돌을 피한다.

테스트는 `.build/test-d9vk-formats.exe`, `.build/test-d9vk-logger.exe`를 별도 Wine prefix, `WINEMSYNC=0`, `WINEESYNC=0`, `WINEDEBUG=-all`로 실행한다. 로그 콜백을 검사할 때는 `DXVK_LOG_LEVEL=info` 이상으로 출력이 실제 활성화됐는지 확인한다.

## 로컬 게임 시험과 원복

- 원래 게임 폴더에 d3d9.dll이 없음을 확인한 후 시험 DLL만 추가했다. `evidence/hmh-d9vk-file.json`에 대상과 SHA-256을 남겼다. 원복 시 **해시가 일치하는 시험 DLL만** 제거한다. 사용자가 바꾼 파일을 덮어쓰거나 삭제하지 않는다.
- 실험 실행은 `.build/hmh-diagnose.swift`로 수행했고, `d3d9=n`, `d3dx9_42=b`, MSync/ESync off, 인증된 Steam과 AppID 214830, Wine 1280×720 가상 데스크톱을 사용했다. 임시 helper는 배포용 인터페이스가 아니다.
- `res/logomovie.wmv`는 비교 후 원래 이름과 원래 해시로 복원했다. 영상 삭제로 해결했다고 간주하지 않는다.
- 일반 MacDeck 실행의 `d3d9=b` 환경은 이 시험 DLL을 자동으로 사용하지 않는다. 검증 후 별도의 게임 프로필 통합이 필요하다. 현재 정식 기본값으로 배포한 상태가 아니다.
- 로그, 테스트 DLL, 소스와 도구 캐시는 Git에 추가하지 않는다. 기존 런타임을 재준비하는 스크립트를 무작정 실행하면 RE3/DMC5 수정이 사라질 수 있다.

## 이어서 시험하기

`Run-HMH-Metal-Trial.command`를 실행하면 기존 체크섬 일치 시험 DLL을 사용해 게임을 실행한다. Steam이 실행 중이지 않으면 Steam 시작·직접 로그인 후 실행기를 다시 실행해야 한다. Steam 인증·소유권 검사를 우회하지 않는다. 로그는 `~/Library/Application Support/MacDeck/Logs/HMH-D9VK-Trials`에 남는다.

마지막 시험은 16:47:22~16:48:40에 실행됐고 Steam 기록의 종료 코드는 0이었다. 사용자가 종료했는지, 타이틀 이후 성능이 어땠는지는 아직 확인하지 못했다. 그 전 실행에는 별도 주소의 접근 위반도 있었으므로 정상 종료 한 번을 완전한 해결로 취급하지 않는다.

Windows 창 검사에서 1280×720 화면에 게임 창의 y 오프셋 33이 보였다. 위치 보정 시도 전에 게임이 닫혀 실제 보정 효과는 검증하지 못했다. 자동 Enter는 거부되어 전달되지 않았으며, 타이틀 이후는 직접 키보드·패드로 확인해야 한다. 구형 D9VK의 부분 Present가 GDI로 폴백한다는 경고도 관측되어 GPU/성능 검증 시 이를 확인해야 한다.
