# 저장소 구조

## 1. 현재 구조

도메인 기반의 과도기 배치를 사용합니다. 기존 `st_*` 이름은 그대로 두고,
`st_setup.m`이 소스와 MATLAB 진단 폴더를 경로에 등록합니다.

```text
Simulink-Test-Automation-Toolkit/
├── st_setup.m
├── src/
│   ├── workflow/
│   ├── config/
│   ├── targets/
│   ├── harness/
│   ├── sldv/
│   ├── signal_editor/
│   ├── assessment/
│   ├── coverage/
│   ├── test_manager/
│   ├── execution/
│   ├── pipeline/
│   ├── reporting/
│   ├── exporting/
│   ├── verification/
│   ├── maintenance/
│   ├── examples/
│   ├── scenarios/
│   └── shared/
├── diagnostics/
│   ├── matlab/
│   └── python/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── examples/
├── resources/
└── docs/
    ├── manual/
    └── archive/
```

| 영역 | 책임 |
| --- | --- |
| `workflow` | 전체 및 기존 Harness workflow 진입점, 단계 계획, 재시작 |
| `config`, `targets` | 프로젝트 설정, workbook 파싱, 모델/CUT 탐색과 검증, 모델 profile |
| `harness`, `sldv`, `signal_editor` | 비용이 큰 모델 준비와 시나리오 데이터 생성 |
| `assessment`, `coverage`, `test_manager` | 검증 로직, Test Case별 커버리지 필터, Test Case·Iteration·정렬 관리 |
| `execution` | 테스트 실행과 기대값 갱신 |
| `pipeline` | standalone Coverage 파이프라인과 결과 재생성 |
| `exporting` | 불변 template 번들, dependency와 입력 수집, 테스트 명세서 |
| `verification` | QUICK/RUNTIME/CERTIFY 조율, 상태 집계, 수동 증거, Excel/JSON/JUnit writer, readiness 검사 |
| `maintenance` | 알려진 생성물의 dry-run 우선 정리 |
| `reporting`, `shared`, `scenarios` | 도메인을 가로지르는 결과·경로·lifecycle·명명 helper |

## 2. 경로와 호환성 규칙

- `st_setup.m`은 저장소 루트에 남으며, 루트에 있는 유일한 MATLAB bootstrap 파일입니다.
- `st_project_root()`가 `st_setup.m`을 통해 루트를 해석합니다. 소스 파일은 자기
  폴더가 프로젝트 루트라고 가정해서는 안 됩니다.
- 기존 공개 `st_*` 명령은 `st_setup` 이후 계속 호출 가능하며, 이번 이전 과정에서
  이름을 바꾸지 않습니다.
- 진단 명령은 공개 명령이지만 제품 소스 밖(`diagnostics/`)에 둡니다.
- `docs/archive/`의 인수인계 문서는 과거 증거를 보존하는 것이며 **현재 구현 지침이
  아닙니다.**

## 3. 설정 우선순위

```text
프로젝트 기본값
    → st_config 전역 옵션
        → Targets 행 override
            → 1회 실행 호출 옵션
```

문서화된 행 수준 옵션만 전역 설정을 덮어씁니다. 잘못된 값은 모델이나 Test File을
바꾸기 전에 실패합니다.

## 4. 향후 package 이전

MATLAB 회귀 검증 이후 `setup`, `selectModel`, `validate`, `generate`, `run`을 담는
작은 `+simtest` package를 도입할 수 있습니다. 기존 `st_*` 함수는 별도로 공지하는
major 릴리스까지 호환 wrapper로 남겨야 합니다.

## 5. 설계 경계

이 항목들은 구현이 지켜야 하는 불변 조건입니다.

### 검증과 변경의 순서

- Excel과 설정 파싱은 Simulink 변경 API를 호출하면 안 됩니다.
- Harness, 모델, Test File, 기대값을 바꾸기 전에 검증이 끝나야 합니다.
- 기대값 생성과 승인은 별개의 책임입니다. 명시적 `APPLY` 동작만 값을 바꿉니다.

### 결과와 보고서

- 보고서는 재현 가능한 출력이며 다음 실행의 입력이 아닙니다.
- 각 테스트 실행은 `result/runs` 아래에 불변 디렉터리 하나를 소유합니다. 초기·최종
  ResultSet은 서로 구분되며, `result/latest.json`과 최신 workbook은 교체 가능한
  pointer입니다.
- Coverage 집계는 호환 가능한 CUT checksum 사이에서만 outcome 가중으로 합산합니다.
  Coverage 임계값은 보고 전용이며 테스트 판정을 바꾸지 않습니다.
- 보고서 번들은 로컬 산출물이며 외부 게시 부작용이 없습니다.

### 커버리지 필터

- 관리 필터는 Test Manager 준비 전에 생성하고, 각 Test Case의 coverage settings
  객체를 통해서만 붙입니다.
- RUNTIME 모드는 실행 후 수동 설정을 복원하고, PERSIST 모드는 Test Case별 연결을
  저장합니다.
- **Test File 수준의 자동 연결은 금지입니다.**

### 증분 상태

- 증분 workflow 상태는 `result/state` 아래의 운영 캐시입니다. **절대 진실의 원천이
  아닙니다.**
- 상태가 없거나 손상됐거나 어긋나면 가장 이른 안전한 준비 단계까지 실행 범위를
  넓힙니다.
- workflow 진입점이 대상별 단계 계획을 세웁니다. 도메인 함수는 인자 없는 직접 호출
  동작을 유지하며, workflow 조율자가 호출할 때만 내부 행 선택 옵션을 받습니다.

### 검증(fixture)

- 실제 모델, workbook, MAT 파일, 생성 결과는 저장소 fixture가 아닙니다.
- 검증 fixture는 MATLAB builder입니다. 생성된 SLX/XLSX/MAT/MLDATX는 실행 workspace
  아래에만 존재합니다.
- QUICK은 `result/verification` 아래에만 쓸 수 있습니다. 모델/Test File 세션 상태를
  기록하고 복원하며 시뮬레이션을 하지 않습니다.
- RUNTIME과 CERTIFY는 격리된 export snapshot을 통해 실제 프로젝트 입력을 실행합니다.
  원본 모델, Test File, Excel, dependency, Signal Editor·SLDV 입력의 checksum은 변하지
  않아야 합니다.
