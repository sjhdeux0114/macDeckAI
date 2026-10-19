# 엔진·그래픽 호환성 점검

조사일: 2026-10-18. 게임 미실행 상태에서 확인할 수 있는 위험을 분류한다. 엔진/API 감지나 자체 테스트 통과는 게임 실행·Metal 가속 성공의 증명이 아니다. Linux Proton 보고를 macOS 재현으로 취급하지 않는다.

| 범위 | 사례·위험 | MacDeck 조치와 검증 한계 |
|---|---|---|
| Unity | Risk of Rain 2의 경로·버전별 입력 문제 보고. Player의 그래픽 API 선택은 빌드에 포함된 API에 한정 | UnityPlayer/globalgamemanagers로 후보 감지. 전역 CrashHandler 차단 제거. DX11 강제는 자동 적용하지 않음 |
| Unreal | Hogwarts Legacy 등에서 보고된 드라이버·렌더링 문제. UE5 Nanite/SM6 요구와 DX11의 기능 차이 | Shipping 실행 파일 후보 감지. 기능 수준 12_1 위장 제거. VC++/Agility SDK와 실제 RHI부터 확인 |
| CryEngine | 엔진 버전마다 r_Driver 지원과 전체화면 전환 동작 차이 | CrySystem/CryGame 단서 수집. 검증 없는 CPU 개수 제한·캐시 삭제·CrashHandler 차단을 일괄 적용하지 않음 |
| Cocos | 구 Cocos2d-x Windows OpenGL과 Creator의 Metal/Vulkan/GLES 지원을 혼동하면 잘못된 실행 옵션을 적용 | 동봉 엔진 DLL 후보 확인. Windows OpenGL을 DXMT로 변환한다고 표시하지 않음. 정적 링크는 감지 못할 수 있음 |
| Godot | Forward+/Mobile/Compatibility의 요구 API 차이 | .pck는 후보 단서일 뿐 엔진 확정 근거가 아님. 렌더러 전환 자동 적용 없음 |
| RE Engine | RE3 영상 재생·DMC5 DXMT GS/TS 경로에서 실제 로컬 문제가 있었음 | 기존 GStreamer 및 DXMT 수정 유지. 다른 RE 게임 전체가 해결됐다는 의미 아님 |
| DX9 / 30초전사 | 32비트 게임이 64비트 Steam의 동기화 환경을 상속. device lost/reset과 실제 백엔드도 별도 조사 필요 | Steam 호스트에도 ESync 적용. Vulkan 강제만으로 Metal 가속 성공·성능 문제 해결을 선언하지 않음. 현재 게임 재검증은 Steam 로그인 대기 |
| 안티치트 | Proton 지원 여부는 게임 개발사 설정에 의존하며 macOS 지원과 별개 | EAC DLL 전역 차단 제거. 안티치트 탐지 시 정보 제공만 함 |
| 프록시·모드 | dinput8/dxgi/version DLL이 게임 또는 모드의 구성요소일 수 있음 | dinput8 builtin 전역 강제 제거. 감지한 파일을 자동 삭제하지 않음 |

## 적용 범위

- `DXMT_CONFIG`의 전역 `ignoreMapFlagNoWait=True`, `maxTessFactor=64` 제거. 특정 게임용 우회가 다른 게임의 동작을 바꾸지 않도록 기본 동작을 보존한다. 기존 Alt-Tab 처리 유지.
- MoltenVK command-buffer prefill을 기본값 0으로 복원. 값 3이 요구하는 autorelease pool과 descriptor 사용 조건을 모든 게임에 가정하지 않는다.
- Wine VKD3D에 vkd3d-proton 전용 설정을 무조건 주입하지 않는다.
- `compatibility.json`을 실행 진단 폴더에 기록한다. 게임 카드 우클릭의 '엔진·그래픽 호환성 점검'으로 실행 전에도 생성할 수 있다.
- 검사 한도: 항목 2500개, 깊이 5단계, EXE 최대 12개, PE 헤더/짧은 import 이름만 읽는다. 동적 로딩·정적 링크·암호화된 파일은 놓칠 수 있다.

## 근거

- [Unity Player 실행 인자](https://docs.unity3d.com/6000.0/Documentation/Manual/PlayerCommandLineArguments.html)
- [Risk of Rain 2 Proton 보고 #2476](https://github.com/ValveSoftware/Proton/issues/2476): 플랫폼·버전별 제보이며 macOS 원인 확정 근거가 아님.
- [UE 하드웨어·기능 요구](https://dev.epicgames.com/documentation/en-us/unreal-engine/hardware-and-software-specifications-for-unreal-engine)
- [Hogwarts Legacy Proton 보고 #6510](https://github.com/ValveSoftware/Proton/issues/6510): Linux 드라이버/Proton 재현과 MacDeck을 구분.
- [CryEngine Vulkan 지원](https://www.cryengine.com/docs/static/engines/cryengine-5/categories/23756816/pages/27594203)
- [Cocos Creator 그래픽 백엔드](https://docs.cocos.com/creator/3.8/manual/en/graphics-backend/overview.html), [Cocos2d-x v4 변경 이력](https://github.com/cocos2d/cocos2d-x/blob/v4/CHANGELOG)
- [Godot 렌더러](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- [Valve Proton·안티치트 안내](https://partner.steamgames.com/doc/steamhardware/proton)
- [Microsoft DX9 lost devices](https://learn.microsoft.com/en-us/windows/win32/direct3d9/lost-devices)
- [DXMT v0.80 설정 원본](https://github.com/3Shain/dxmt/blob/v0.80/dxmt.conf), [GS/TS 문제 #200](https://github.com/3Shain/dxmt/issues/200)
- [MoltenVK 설정 조건](https://github.com/KhronosGroup/MoltenVK/blob/main/Docs/MoltenVK_Configuration_Parameters.md)
- [vkd3d-proton 설정](https://github.com/HansKristian-Work/vkd3d-proton/blob/master/README.md), [Wine 10.0 실제 포함 버전·D3D9 변경](https://github.com/wine-mirror/wine/blob/wine-10.0/ANNOUNCE.md)

## 기존 기록 정정

work.md의 과거 '크래시 원천 차단', '무결점', 'OpenGL이므로 CPU 전용' 표현은 검증 범위를 넘어선다. HMH CPU 샘플에는 AppleMetalOpenGLRenderer와 AGXMetalG17G가 로드되어 있다. 이것만으로 실제 프레임의 GPU 사용량을 확정할 수도 없다. 고주사율·CSMT 경합·MSync 경고 각각이 해당 게임 문제의 단독 원인이라는 가설은 별도 비교 검증이 필요하다.

## DX9 현장 조사 추가 (2026-10-18)

30초전사의 macOS D9VK 시험에서 YV12 확장 포맷의 잘못된 재귀/배열 조회와 Wine 로깅 함수 호출 규약 불일치를 실제 크래시·소스로 확인했다. 수정 소스의 포맷 8개 그룹과 Wine 콜백 64회 검사가 통과했다. 세부 재현·패치·한계는 [DX9-HALF-MINUTE-HERO.ko.md](DX9-HALF-MINUTE-HERO.ko.md)에 있다. 이것은 D9VK 특정 버전의 확인된 결함이며 모든 DX9 엔진의 원인이라는 의미가 아니다.

부분 영역 Present가 구형 D9VK의 GDI 폴백으로 넘어가면 GPU 경로를 만들었더라도 CPU 복사·GetDC 실패가 발생할 수 있다. 해당 경고도 수집한다. Metal 장치/인트로 출력과 지속 게임 플레이·프레임률을 따로 검증해야 한다.
