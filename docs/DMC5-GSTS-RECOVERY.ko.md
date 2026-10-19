# DMC5 GS/TS 보완판 복구 기록 (2026-10-19)

## 배경과 검증 범위

2026-10-18 사용자에게서 같은 구간의 긴 렉이 해소됐다는 보고를 받은 DXMT GS/TS marshal 보완판이 공통 렌더러 도입 후 선택되지 않았다. DXMT로 되돌린 것만으로 보완판이 복구되지는 않았다.

- 공통 원본 d3d11: `cafb32ba2b58e2e8decc1d6feabccdc131e1bf186713b34913a98974f94a3f02`
- 초기 보완판 및 이번 재생성본: `99efd3c06ce9070c815922857c8aed5b6652017b70d1c4270b7e1f7a5a1ab725`
- 버전 잠금 패처: `scripts/patch-dxmt-marshal.py`; 셰이더 변경: `patches/dxmt-0.80-gs-ts-marshal.patch`.
- Metal 검사: 36개 함수 보존, GS/TS의 0 작업 건너뛰기 및 다음 작업 실행 PASS. 실제 플레이 안정성과 다르다.

## 게임별 적용

`GameProfile.dxmtMarshalFix`는 선택적 필드이며 기본 비활성이다. 정확한 `steam:601150`, `steamRenderer=dxmt`, 보호 baseline 없음 조건에서만 활성화를 허용한다. 이번 로컬 프로필 revision은 3이며 상태는 재검증 전까지 failing으로 유지했다.

MacDeck의 관리 `renderers.ini`에만 다음 규칙을 기록한다. 게임 폴더나 공유 Steam 환경변수에 패치를 주입하지 않는다.

```ini
[renderers]
601150=dxmt
[patches]
601150=gs-ts-v1
```

라우터는 AppID601150의 d3d11 요청만 `macdeck_dxmt_gsts_v1_d3d11.dll`로 연결한다. DXGI·D3D12·다른 게임·Big Picture는 기존 선택을 유지한다. 별도 인증 없는 prefix에서 DMC5/RE3/엘든링/Steam ID로 D3D11 GPU 검사를 실행해 모두 통과했고 DMC5만 `marshal=1`이었다. 이는 네 게임의 실제 플레이 검증이 아니다.

정상 기준 fingerprint도 실제 선택된 후보 DLL을 추적하므로 후보 변경이 DMC5 기준에서 감지되고 다른 게임의 기준은 보존된다. 정상 기준을 자동 재설정하지 않는다.

## 이번 설치와 복구

현재 사용자 데이터의 `Compatibility/Repairs/dmc5-gsts-20261019/restore.json`에 원래 파일 경로·존재 여부·해시와 백업을 남겼다. 변경 대상은 관리 프로필·관리 map·D3D11 라우터 두 복사본·새 후보 DLL이다. 공통 원본 DXMT와 다른 게임 프로필은 보존했다. 공유 라우터 바이너리 변경은 공통 코드 변경이지만 새 선택은 정확한 DMC5에만 발생한다.

롤백은 Steam과 게임을 종료한 상태에서 해당 manifest에 따라 원본을 복원한다. 일반 런타임 재준비 스크립트로 덮어쓰지 않는다. 이번 후보는 자동 업데이트나 다른 버전 바이너리에 재적용하지 않는다. 새 컴퓨터에 배포하려면 같은 버전의 Metal library 생성/검증 및 별도 후보 설치가 필요하며 프로필 필드만 옮기면 안 된다.

`build-common-renderer-router.py --apple-components <검증된 별칭 디렉터리>`는 사라질 수 있는 임시 DMG 마운트 경로 대신 `macdeck_metal_*.dll`을 명시 입력으로 사용한다.

## 남은 확인

- 사용자 동일 구간 DMC5 플레이에서 렉/로그아웃 해소 여부.
- DmC220440은 별도 게임이다. .NET/VC 기능 검사 후에도 정확한 AppID 실행에서 접근 위반으로 종료되며 이번 GS/TS 패치 대상이 아니다.
