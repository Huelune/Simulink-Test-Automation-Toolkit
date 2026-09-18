# 내부 표준 명령

우리가 실제로 쓰는 명령만 모았습니다. 이 문서 하나로 준비부터 제출물까지
끝납니다. 나머지 `st_*` 명령은 평소에 쓸 일이 없습니다.

## 큰 그림 — 세 덩어리

```text
┌──────────────────────────────────────────────────────────────┐
│  1. 준비 + 실행                                               │
│     Harness·입력·verify·Test Case를 만들고, 돌리고,           │
│     실패한 기대값을 고치고, 다시 돌린다                       │
│                                                              │
│     st_run_from_harness  /  st_run_after_harness             │
└───────────────────────────┬──────────────────────────────────┘
                            │  실행 기록만 남기고 끝
              ┌─────────────┴─────────────┐
              ▼                           ▼
┌───────────────────────────┐ ┌───────────────────────────────┐
│ 2a. 결과 정리             │ │ 2b. 제출물                     │
│    Harness를 안 내보냄    │ │    Harness를 독립 모델로 내보냄 │
│                           │ │                               │
│ st_generate_test_report   │ │ st_run_standalone_            │
│   (BATCH)                 │ │   coverage_pipeline           │
│ st_collect_per_cut_results│ │ st_check_standalone_coverage  │
│   (PER_CUT)               │ │                               │
└───────────────────────────┘ └───────────────────────────────┘
```

**커버리지 필터(CVF)는 2단계에서만 만들어집니다.** 1단계는 커버리지를 필터 없이
수집만 합니다. Excel의 `Coverage*` 열 네 개도 2단계에서만 쓰입니다.

## 0. 명령 이름

줄여 부르는 이름과 실제 함수 이름이 다릅니다. MATLAB에는 **오른쪽 이름**을
입력해야 합니다.

| 줄여 부르는 이름 | 실제 함수 이름 |
| --- | --- |
| `st_setup` | `st_setup` |
| `st_select_model` | **`st_select_target_model`** |
| `st_pre_validate` | **`st_pre_validate_targets`** |
| `st_run_from_harness` | `st_run_from_harness` |
| `st_run_after_harness` | `st_run_after_harness` |
| `st_export_spec` | **`st_export_test_specification`** |
| `st_report` | **`st_generate_test_report`** |
| `st_collect` | **`st_collect_per_cut_results`** |
| `st_run_standalone_coverage_pipeline` | `st_run_standalone_coverage_pipeline` |
| `st_check_standalone` | **`st_check_standalone_coverage`** |

## 1. 전체 흐름

```text
st_setup                                 MATLAB 켤 때마다 1회
    │
st_select_target_model                   처음 1회 / 모델 바꿀 때만
    │
    │   ← TestManagement.xlsx 작성 또는 수정
    │
st_pre_validate_targets                  Excel 고칠 때마다
    │
st_run_from_harness                      Harness가 없을 수 있을 때
  또는 st_run_after_harness               Harness가 전부 있을 때
    │
    │   ← 여기서 모델과 Test File이 바뀝니다
    │   ← 실행 기록이 result/run_records/ 에 남습니다
    │
st_generate_test_report                  보고서가 필요할 때
    │
st_export_test_specification             명세서 Excel이 필요할 때
    │
    │   ← 원본 Top Model과 Harness를 저장하고 닫기
    │
st_run_standalone_coverage_pipeline      제출물 생성
    │
st_check_standalone_coverage             제출물 검사 → 1111111111 PASS
```

`st_generate_test_report`와 standalone은 **형제 갈래입니다.** 순서 관계가 아니고,
필요한 쪽만 부르면 됩니다. standalone은 통합 보고서를 읽지 않습니다.

> 둘 다 하실 거면 **보고서를 먼저** 하십시오. standalone은 Top Model이 닫혀
> 있어야 시작합니다.

## 2. 복사용 전체 코드

```matlab
%% 1. 세션 시작
st_setup

%% 2. 대상 모델 선택 (처음 1회, 또는 모델을 바꿀 때만)
st_select_target_model

%% 3. Excel 확인
st_pre_validate_targets

%% 4. 준비와 실행
st_run_from_harness
% Harness가 이미 전부 있으면: st_run_after_harness
% 전부 한 번에 돌리려면:
%   st_run_from_harness('ExecutionMode','BATCH')

%% 4-1. 결과 정리 (보고서가 필요할 때만)
st_collect_per_cut_results              % 기본 PER_CUT으로 돌렸을 때
% BATCH로 돌렸으면: st_generate_test_report

%% 5. 명세서 Excel (필요할 때)
[T, specFile] = st_export_test_specification();
disp(specFile)

%% 6. 제출물 생성 — 원본 Top Model과 Harness를 먼저 저장하고 닫습니다
info = st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);

%% 7. 제출물 검사
[code, summary, details] = st_check_standalone_coverage();
disp(code)
disp(summary)
disp(details)
```

## 3. 명령별 설명

### `st_setup`

```matlab
st_setup
```

이 도구의 명령을 MATLAB이 찾을 수 있게 경로에 등록하고 `result/` 폴더를 만듭니다.

- **MATLAB을 새로 켤 때마다 한 번씩** 실행합니다. 등록은 그 세션에만 유효합니다.
- 실행 전에 **Current Folder를 저장소 루트**(`st_setup.m`이 보이는 폴더)로
  맞춰야 합니다.
- 옵션이 없습니다.

성공하면 이렇게 출력됩니다.

```text
Automation project path added: D:\...\Simulink-Test-Automation-Toolkit
Source path added            : D:\...\Simulink-Test-Automation-Toolkit\src
```

### `st_select_target_model`

```matlab
st_select_target_model          % 이미 고른 게 있으면 그대로 재사용
st_select_target_model(true)    % 무조건 다시 고르기
```

목록에서 Top Model을 고르고 그 선택을 `runtime_target.mat`에 저장합니다.

- **처음 한 번, 그리고 대상 모델을 바꿀 때만** 실행합니다. 이후 명령들이 저장된
  선택을 그대로 씁니다.
- `runtime_target.mat`은 Git에 올라가지 않습니다. 저장소를 pull해도 다른 사람의
  모델 선택이 딸려 오지 않고, 내 선택도 지워지지 않습니다.
- 모델을 열지는 않습니다. 선택만 저장합니다.

### `st_pre_validate_targets`

```matlab
R = st_pre_validate_targets();
disp(R)
```

Excel에 적은 CUT 경로가 실제로 존재하는지 확인합니다. **모델을 바꾸지 않습니다.**

확인하는 것:

- `CUTPath`가 비어 있지 않은가
- 선택한 Top Model 기준으로 경로를 해석할 수 있는가
- 그 경로에 블록이 실제로 있는가
- 그 블록이 Subsystem인가

결과는 `result/reports/PreValidationResult.ini`에 저장됩니다.

> **여기서 걸리면 다음으로 넘어가지 마십시오.** Harness를 엉뚱한 블록에 만들게
> 됩니다. 대부분 `CUTPath` 오타이거나, 경로가 모델 이름부터 시작하지 않는
> 경우입니다.

### `st_run_from_harness` / `st_run_after_harness`

```matlab
st_run_from_harness     % Harness가 없을 수 있을 때
st_run_after_harness    % Harness가 전부 있을 때
```

둘 다 준비부터 테스트 실행까지 한 번에 합니다. **차이는 Harness 생성 단계 하나뿐**
입니다.

| 명령 | 실행하는 단계 |
| --- | --- |
| `st_run_from_harness` | **HARNESS** → SLDV → HARNESS_CONFIG → SIGNAL_EDITOR → ASSESSMENT → TEST_MANAGER → ALIGNMENT → EXECUTE |
| `st_run_after_harness` | SLDV → HARNESS_CONFIG → SIGNAL_EDITOR → ASSESSMENT → TEST_MANAGER → ALIGNMENT → EXECUTE |

각 단계가 하는 일:

| 단계 | 하는 일 | 무엇이 바뀌나 |
| --- | --- | --- |
| `HARNESS` | 없는 Harness를 만듭니다. **기존 Harness는 건드리지 않습니다** | 모델 |
| `SLDV` | 입력 데이터를 준비합니다 (`OFF`/`FILE`/`GENERATE` 전부 여기서) | 입력 MAT |
| `HARNESS_CONFIG` | StopTime 등 Harness 설정 | Harness |
| `SIGNAL_EDITOR` | 입력 Scenario를 만들어 Harness에 연결 | Harness |
| `ASSESSMENT` | `verify` 문장 구성 | Harness |
| `TEST_MANAGER` | Test File, Test Case, Iteration 구성 | Test File |
| `ALIGNMENT` | 네 곳의 Scenario가 일치하는지 **검사만** | 없음 |
| `EXECUTE` | 테스트 실행 → 기대값 갱신 → 재실행 → 실행 기록 저장 | Harness, 실행 기록 |

`ALIGNMENT`는 실행 직전의 마지막 안전장치입니다. 아래 네 곳이 **같은 이름 집합**을
갖는지 확인합니다. 하나라도 어긋나면 실행은 되지만 엉뚱한 scenario의 기대값이
덮어써지기 때문입니다.

```text
SLDV ScenarioNames  ==  Signal Editor  ==  Test Assessment  ==  Test Manager iterations
        (SLDV)          (SIGNAL_EDITOR)      (ASSESSMENT)        (TEST_MANAGER)
```

#### 이 명령이 바꾸는 것

**모델과 Test File을 실제로 저장합니다.** 처음 돌리기 전에 백업하십시오.

기본 기대값 정책이 `APPLY`라서, 테스트가 실패하면 **실제 출력값을 정답으로 보고
`verify`의 기대값을 그 값으로 고쳐 쓴 뒤 다시 실행합니다.** 승인된 기준값이 있으면
반드시 끄십시오.

| 끄는 방법 | 범위 |
| --- | --- |
| Excel의 `ExpectedUpdateMode` 열을 `OFF` | 그 행만 |
| `src/config/st_config.m`의 `cfg.ExpectedUpdateMode = 'OFF'` | 전체 |

#### 두 번째 실행부터는 빨라집니다

각 단계가 성공하면 입력 지문을 `result/state/`에 저장하고, 다음 실행에서
Excel·설정·모델·입력이 그대로면 그 단계를 건너뜁니다.

다시 하고 싶을 때:

```matlab
st_run_from_harness('PreparationMode','FORCE');                      % 전부 다시
st_run_from_harness('PreparationMode','FORCE', 'FromStage','SLDV');  % 그 단계부터
```

| 무엇이 바뀌었나 | `FromStage` |
| --- | --- |
| 입력 MAT 또는 SLDV 설정 | `SLDV` |
| Harness StopTime 등 설정 | `HARNESS_CONFIG` |
| verify 대상 또는 Assessment 구성 | `ASSESSMENT` |
| Test Case 이름 또는 Iteration | `TEST_MANAGER` |
| **Coverage 필터 설정** | **없음 — 준비를 다시 할 필요가 없습니다** |

Coverage 열은 준비 단계가 읽지 않습니다. 바꿔도 Harness나 Test File을 다시 만들지
않고, 다음 결과 정리에만 반영됩니다.

> `FromStage`는 앞 단계를 **건너뛰라는 뜻이 아닙니다.** 지정한 단계부터 강제로
> 다시 하라는 뜻이고, 그보다 앞 단계는 여전히 지문으로 판정합니다. 모델이
> 바뀌었거나 checkpoint가 없으면 앞 단계도 함께 실행됩니다.

`AUTO`여도 아래 조건이면 그 단계부터 강제로 다시 돕니다.

| 무엇이 감지되면 | 다시 도는 범위 |
| --- | --- |
| checkpoint 없음 / state 파일 깨짐 | `SLDV` 이후 전부 |
| 모델 파일이 바뀜 | `SLDV` 이후 전부 |
| SLDV manifest 없음 / 캐시된 profile 깨짐 | `SLDV` 이후 전부 |
| Test File이 바뀜 | `TEST_MANAGER`, `ALIGNMENT` |
| 한 단계가 다시 돎 | 그 뒤 단계 전부 |

#### 준비만 하고 실행은 나중에

```matlab
st_run_from_harness('ExecuteTests', false);
```

Test Case까지만 만들고 멈춥니다. 실행은 Test Manager에서 직접 하거나 나중에 다시
이 명령을 부르면 됩니다.

#### 한꺼번에 돌릴까, 하나씩 돌릴까

```matlab
st_run_from_harness                                  % PER_CUT (기본), 하나씩
st_run_from_harness('ExecutionMode','BATCH')         % 한꺼번에
```

| | `PER_CUT` (기본) | `BATCH` |
| --- | --- | --- |
| 실행 | Test Case마다 따로 | `run(tf)` 한 번에 전부 |
| 기대값 고친 뒤 재실행 | 그 Test Case만 | Test File **전체** |
| 결과 정리 명령 | `st_collect_per_cut_results` | `st_generate_test_report` |
| 결과물 | CUT별 폴더 | 통합 보고서 하나 |

**기본은 `PER_CUT`입니다.** Test Case가 서로 영향을 주지 않고, 결과가 CUT별로
나뉘어 남습니다. 전부 한 번에 돌려 통합 보고서 하나로 끝내고 싶을 때 `BATCH`를
씁니다. 커버리지 필터를 쓰는지 여부는 이 선택과 아무 상관이 없습니다.

`PER_CUT`에만 있는 옵션이 셋 있습니다. 작동 시점이 다릅니다.

| 옵션 | 언제 | 기본값 | `true`면 |
| --- | --- | --- | --- |
| `ContinueOnFailure` | 실행 **도중** CUT 하나가 터졌을 때 | `true` | 기록하고 다음 CUT으로 |
| `FailOnNonPass` | 전부 끝난 **뒤** 한 번 | `false` | 하나라도 비-통과면 MATLAB 오류 |
| `AutoCollect` | 실행이 **다 끝난 뒤** | `false` | `st_collect_per_cut_results`까지 이어서 실행 |

```matlab
% CI처럼 하나라도 실패하면 알아야 할 때
st_run_from_harness('ExecutionMode','PER_CUT', ...
    'ContinueOnFailure', true, 'FailOnNonPass', true);

% 명령 하나로 보고서까지 받고 싶을 때
st_run_from_harness('ExecutionMode','PER_CUT', 'AutoCollect', true);
```

`AutoCollect`는 수집을 실행과 한 세션에 묶습니다. 그만큼 늦게 끝나고, 수집이
실패하면 워크플로가 실패합니다. 긴 실행을 끊어서 하거나 다른 세션에서 수집하려면
기본값 그대로 두십시오. 항상 이어서 실행하고 싶으면
`cfg.PerCutAutoCollect = true`로 바꿉니다.

#### 결과 정리하고 보기

실행은 **기록만 남기고 끝납니다.** Test Manager의 결과는 그 MATLAB 세션 안에서만
살아 있어서, 실행이 `result/run_records/`에 저장해 둡니다. 보고서는 원할 때,
다른 세션에서도 만들 수 있습니다.

```matlab
st_collect_per_cut_results              % PER_CUT(기본)으로 돌렸을 때
st_generate_test_report                 % BATCH로 돌렸을 때

cfg = st_config();
winopen(cfg.LatestSummaryFile)
```

| 무엇이 | 어디에 |
| --- | --- |
| 실행 기록 (ResultSet 포함) | `result/run_records/` |
| BATCH 통합 보고서 | `result/runs/` |
| PER_CUT CUT별 결과 | `result/per_cut_runs/` |

커버리지 필터(CVF)는 이 단계에서 만들어져 결과에 붙습니다. 실행은 커버리지를
필터 없이 수집합니다.

### `st_export_test_specification`

```matlab
[T, specFile] = st_export_test_specification();
disp(specFile)
```

**테스트를 실행하지 않고** 저장된 시나리오·입력 마지막 값·`verify` 문장을 Excel
명세서로 뽑습니다. 시뮬레이션, 테스트 실행, SLDV 생성, 기대값 갱신을 하지 않습니다.

기본 출력은 `result/test_specification_<timestamp>.xlsx`입니다.

실행 전에 모델·Harness·Test File·입력 MAT을 **저장**하고 실행 중인 모델을
멈추십시오. 저장되지 않은 것이 있으면 중단합니다.

자주 쓰는 옵션:

```matlab
% 모든 스텝의 verify를 스텝별 열로 나누기 (기본은 Step 2만)
[T, file] = st_export_test_specification('VerifyMode','ALL_STEPS_COLUMNS');

% If/Switch가 없는데 Decision coverage가 나오는 이유를 찾을 때
[T, file] = st_export_test_specification('DecisionBlockScope','ALL');

% 다른 이름으로 저장 (기존 파일은 덮어쓰지 않고 실패합니다)
[T, file] = st_export_test_specification( ...
    'OutputFile', fullfile(pwd,'result','spec_review.xlsx'));
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `VerifyMode` | `'STEP2'` | `'STEP2'`는 직계 Step 2만, `'ALL_STEPS_COLUMNS'`는 verify가 있는 모든 스텝을 오른쪽 열에 |
| `DecisionBlockScope` | `'EXPLICIT'` | `DecisionBlocks` 열 범위. `'EXPLICIT'`(If/Switch 계열 5종) / `'ALL'`(암시적 분기 13종 추가) / `'NONE'` |
| `OutputFile` | 자동 생성 | 저장 경로 |

만들어지는 시트: `사용법`, `TestSpecification`, `AssessmentDetails`,
`DecisionBlockDetails`, `OverflowDetails`.

### `st_run_standalone_coverage_pipeline`

```matlab
info = st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);
```

Harness를 **독립 실행 가능한 모델**로 떼어내 실행하고, 커버리지 결과와 부속 파일을
제출물로 묶습니다. 받는 쪽에 원본 Top Model이 없어도 열립니다.

| 옵션 | 왜 이 값인가 |
| --- | --- |
| `'Action','ALL'` | EXECUTE → PACKAGE → SUMMARY를 한 번에 |
| `'ContinueOnFailure', true` | 한 CUT이 실패해도 나머지를 계속 처리 |
| `'FailOnNonPass', false` | 실패해도 MATLAB 오류를 내지 않고 결과 표로 판정 |

#### 실행 전 조건

준비가 끝난 Harness와 Test Case를 입력으로 씁니다. **먼저
`st_run_from_harness`를 끝내십시오.**

- 원본 Top Model과 Test File을 **저장**했는가
- **Top Model과 열린 Harness를 닫았는가** — 복사본과 모델 이름이 충돌합니다.
  이 명령은 사용자 모델을 강제로 닫지 않습니다
- Excel의 각 활성 행이 아래 조합을 갖추었는가

```text
CoverageFilterMode      = ALL_CONTENT
CoverageBoundaryMode    = CUT_ONLY
CoverageFilterAction    = EXCLUDE
CoverageFilterRationale = (비어 있지 않은 사유)
```

`CoverageFilterRationale`이 비어 있으면 실행되지 않습니다.

기대값은 갱신하지 않습니다. 준비된 자산을 복사해 실행만 합니다.

#### 만들어지는 것

CUT 폴더 `{NUM}_UT_REQ_{TC_NAME}` 안에:

- standalone 모델 (`.slx`)
- Signal Editor Input MAT
- `UT_REQ_{TC_NAME}.cvf` — 적용한 커버리지 필터
- `UT_REQ_{TC_NAME}.cvt` — 커버리지 원본 데이터
- `UT_REQ_{TC_NAME}.html` — Coverage 보고서 (부속 asset 포함)
- target manifest

root에는 재배선된 Test File과 11열짜리 `CoverageSummary.xlsx`가 생깁니다.
저장 위치는 `result/standalone_coverage/`입니다.

> 결과를 전달할 때는 **폴더 전체**를 복사하십시오. HTML은 옆의 리소스 파일 없이
> 제대로 렌더링되지 않습니다.

### `st_check_standalone_coverage`

```matlab
[code, summary, details] = st_check_standalone_coverage();
disp(code)
disp(summary)
disp(details)
```

방금 만든 제출물이 제대로 됐는지 **읽기 전용으로** 검사합니다. 모델·Test
File·CVF를 저장하거나 바꾸지 않습니다.

- 인자 없이 부르면 가장 최근 실행을 검사합니다.
- 특정 실행은 `'PipelineId', info.PipelineId`로 지정합니다.
- 화면 출력은 최대 20줄이고, 전체 CUT 결과는 `details` 표에 있습니다.

#### 판정

| 결과 | 뜻 |
| --- | --- |
| `1111111111` + `summary.Status = 'PASS'` | 정상 |
| 비트에 `0`이 있음 | 그 항목 실패. `details`에서 원인 확인 |
| 비트에 `-`가 있음 | 아직 적용할 수 없는 검사. 전체는 `PARTIAL` |
| 전부 `1`인데 `PARTIAL` | `EXCEPT`로 끝난 대상이 있음 |

| 비트 | 검사 |
| --- | --- |
| B1 | manifest, Action, Result 저장·재개 정책 |
| B2 | Harness명 = standalone 모델명 = `.slx` stem |
| B3 | SUT / iteration / input / assessment readback |
| B4 | `RunCount=1`, 재실행 없음 |
| B5 | CVF 생성, rule/file/hash, Result 등록 1회 |
| B6 | 필수 패키지 존재, 금지 산출물 없음 |
| B7 | Decision/Execution 수치와 metric source |
| B8 | Summary 파일, 11개 열, CUT 행 수 |
| B9 | 원본 model/Test File/Harness/Input/Excel 불변 |
| B10 | filter 복원, model/path 정리, CUT 폴더 격리 |

## 4. 상황별로 무엇을 부를까

| 상황 | 명령 |
| --- | --- |
| MATLAB을 새로 켰다 | `st_setup` |
| 대상 모델을 바꾼다 | `st_select_target_model(true)` |
| Excel을 고쳤다 | `st_pre_validate_targets` → `st_run_from_harness` |
| Harness가 이미 다 있다 | `st_run_after_harness` |
| 입력 MAT을 바꿨다 | `st_run_from_harness('PreparationMode','FORCE','FromStage','SLDV')` |
| Assessment를 바꿨다 | `st_run_from_harness('PreparationMode','FORCE','FromStage','ASSESSMENT')` |
| 준비만 하고 실행은 나중에 | `st_run_from_harness('ExecuteTests', false)` |
| 혼자 돌려야만 되는 Test Case가 있다 | `st_run_from_harness('ExecutionMode','PER_CUT')` |
| 보고서를 보고 싶다 (BATCH로 돌림) | `st_generate_test_report` |
| 보고서를 보고 싶다 (PER_CUT으로 돌림) | `st_collect_per_cut_results` |
| Coverage 필터 설정만 바꿨다 | 준비는 그대로. 결과 정리만 다시 하면 됩니다 |
| 명세서 Excel이 필요하다 | `st_export_test_specification` |
| 제출물을 만든다 | Top Model 닫고 → `st_run_standalone_coverage_pipeline('Action','ALL',...)` |
| 제출물이 맞는지 본다 | `st_check_standalone_coverage` |

## 5. 자주 막히는 곳

| 증상 | 원인과 대처 |
| --- | --- |
| `st_setup` 후 명령을 못 찾는다 | Current Folder가 저장소 루트가 아닙니다 |
| `CUTPath`를 찾을 수 없다 | 모델 이름부터 시작하는 전체 경로여야 합니다 |
| SLDV MAT을 찾을 수 없다 | `SldvDataFile` 상대 경로 기준은 **Excel 파일이 있는 폴더**입니다 (Current Folder 아님) |
| 같은 이름의 모델이 열려 있다 | 저장하고 닫으십시오. 확실하게 하려면 MATLAB 재시작 |
| 기대값이 마음대로 바뀌었다 | `ExpectedUpdateMode`가 비어 있으면 `APPLY`입니다. `OFF`로 내리십시오 |
| 필터 사유가 없다고 중단 | `CoverageFilterRationale`은 필터를 켜면 필수입니다 |
| Atomic이 아니라고 중단 | `FILE+SLDV`/`GENERATE`는 Atomic Subsystem이 필요합니다. 라이브러리 링크된 CUT은 원본 라이브러리에서 고쳐야 합니다 |
| `Scenario`와 `Iteration` 수가 안 맞는다 | `FromStage','SLDV'`로 다시 돌리십시오 |
| 커버리지가 `0/0`, `N/A` | 필터가 objective를 다 뺀 정상 상태일 수 있습니다 |
| CVF 뷰어 이름이 `n/a` | 정상입니다. 그 CVF 옆의 standalone 모델을 먼저 여십시오 (원본 Top Model 아님) |
| 준비가 너무 오래 걸린다 | Harness 생성과 SLDV `GENERATE`는 원래 느립니다. 마지막 `START` 로그가 현재 위치입니다 |
| 경로가 너무 길다는 오류 | `st_set_standalone_coverage_root('D:\st_out')`로 짧은 경로 지정 |
| 실행은 끝났는데 보고서가 없다 | 정상입니다. `st_generate_test_report`(BATCH) 또는 `st_collect_per_cut_results`(PER_CUT)를 부르십시오. PER_CUT에서 매번 자동으로 하려면 `AutoCollect`를 쓰십시오 |
| `RunRecordPointerMissing` | 아직 실행한 적이 없습니다. 먼저 `st_run_from_harness`를 돌리십시오 |
| `RemovedExecutionMode` | `ExecutionMode='AUTO'`는 없어졌습니다. `'BATCH'` 또는 `'PER_CUT'`을 쓰십시오 |
| 커버리지에 필터가 안 걸린 것 같다 | 실행 결과가 아니라 **결과 정리 후** 보고서를 보십시오. 필터는 그때 붙습니다 |

오류 식별자별 대처는 [문제 해결](troubleshooting.md)에 있습니다.

## 6. 반드시 지킬 것

- `st_run_from_harness` / `st_run_after_harness`는 **모델과 Test File을 저장합니다.**
  처음 돌리기 전에 백업하십시오.
- 실행이 끝나도 보고서는 **자동으로 만들어지지 않습니다.** 결과 정리 명령을
  부르거나 standalone 제출물을 만드십시오.
- 기대값 기본 정책은 `APPLY`입니다. 승인된 기준값이 있으면 먼저 `OFF`로 내리십시오.
- standalone pipeline 전에 **원본 Top Model과 열린 Harness를 닫으십시오.**
- 제출물은 폴더 전체를 복사해 전달하십시오.
- 실제 모델·Excel·MAT·MLDATX와 `result/`는 **Git에 올리지 않습니다.**

## 7. 더 필요할 때

| 찾는 것 | 문서 |
| --- | --- |
| 용어가 낯설다 (CUT, Harness, CVF, SLDV…) | [용어집](glossary.md) |
| Excel 열의 뜻과 기본값 | [관리 Excel 열 사전](workbook-reference.md) |
| `st_config` 설정 | [설정 사전](config-reference.md) |
| 오류 대처 | [문제 해결](troubleshooting.md) |
| 단계를 끊어서 실행 | [단계별로 끊어서 실행하기](manual/step-by-step.md) |
| 제출물을 Test Manager에서 열기 | [결과 열기](manual/open-results.md) |
| 명세서 Excel의 열 구성 | [테스트 명세서 추출](test-specification.md) |
| 전체 문서 목록 | [문서 지도](README.md) |
