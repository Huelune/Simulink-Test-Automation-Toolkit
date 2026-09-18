# 단계별로 끊어서 실행하기

`st_run_from_harness`는 Harness 생성부터 테스트 실행까지를 한 번에 합니다. 이
문서는 그것을 **단계별로 나눠 실행하고, 각 단계 결과를 확인한 뒤 다음으로
넘어가는** 방법을 설명합니다.

평소에는 [준비 및 실행](prepare.md)의 한 번에 실행하는 방식이 더 안전하고
빠릅니다. 아래 경우에만 이 문서를 쓰십시오.

- 한 단계의 결과를 눈으로 확인하고 다음으로 넘어가고 싶을 때
- 어느 단계에서 문제가 생기는지 좁히고 싶을 때
- Harness만 먼저 만들어 두고 나중에 이어서 하고 싶을 때
- 자동 생성 결과를 손으로 고친 뒤 그 다음 단계부터 진행하고 싶을 때

> **먼저 알아 둘 것:** 단계 명령을 직접 부르면 **checkpoint가 남지 않습니다.**
> checkpoint를 쓰는 것은 `st_run_from_harness` 계열뿐입니다. 이 차이가
> [5장](#5-여기까지-했는데-그-다음부터-진행하려면)에서 중요해집니다.

## 1. 전체 단계 지도

| # | 단계 | 명령 | 무엇을 만드는가 | 결과 파일 |
| --- | --- | --- | --- | --- |
| 0 | 사전 검증 | `st_pre_validate_targets` | (확인만) | `PreValidationResult.ini` |
| 1 | Harness 생성 | `st_create_harnesses` | Test Harness | `HarnessCreateResult.ini` |
| 2a | 입력 데이터 준비 | `st_prepare_sldv_targets` | SLDV/MAT 입력과 manifest | `SldvGenerationResult.ini`, `SldvScenarioResult.ini` |
| 2b | Harness 설정 | `st_configure_harnesses` | StopTime 등 | `HarnessConfigResult.ini` |
| 2c | 입력 연결 | `st_configure_signal_editors` | Signal Editor MAT와 Scenario | `SignalEditorResult.ini` |
| 3 | Assessment 설정 | `st_configure_assessments` | `verify` 문장 | `AssessmentResult.ini` |
| 5a | Test Case 생성 | `st_create_test_manager` | Test File, Test Case, Iteration | `TestManagerResult.ini` |
| 5b | 정렬 검사 | `st_validate_scenario_alignment` | (확인만) | `ScenarioAlignmentResult.ini` |
| 6 | 실행 + verify 수정 | `st_run_tests_per_cut` 또는 `st_run_generated_tests` | 결과와 보고서 | `result/per_cut_runs/` 또는 `result/runs/` |
| 7 | 제출물 | `st_run_standalone_coverage_pipeline` | standalone 제출물 | `result/standalone_coverage/` |

결과 INI는 전부 `result/reports/` 아래에 있습니다.

모든 단계 명령은 **인자 없이** 부르며, 관리 Excel의 활성 행 전체를 대상으로
합니다. 단계 하나만 골라 실행할 수는 있지만 CUT 하나만 골라 실행하는 인자는
없습니다. 특정 CUT만 처리하려면 Excel의 `Enabled` 열로 나머지를 내리십시오.

## 2. 0단계 — 준비와 사전 검증

```matlab
st_setup
st_pre_validate_targets
```

처음이거나 대상 모델을 바꿀 때만 `st_select_target_model`을 사이에 넣습니다.

`st_pre_validate_targets`는 모델을 바꾸지 않고 `CUTPath`가 실제로 존재하는
Subsystem을 가리키는지만 확인합니다. 여기서 걸리면 다음 단계를 진행하지
마십시오. Harness를 엉뚱한 블록에 만들게 됩니다.

```matlab
R = st_pre_validate_targets();
disp(R)
```

## 3. 단계별 실행

### 1단계 — Harness 생성

```matlab
R = st_create_harnesses();
disp(R)
```

CUT마다 Test Harness를 만듭니다.

- **이미 있는 Harness는 건너뜁니다.** 지우고 다시 만들지 않습니다.
- 모델 컴파일을 포함하므로 CUT 하나에 수 분 이상 걸릴 수 있습니다. 진행 상황은
  각 대상의 시작 시각과 경과 시간으로 출력됩니다.
- 라이브러리에 링크된 CUT은 `SyncOnOpen`으로 만들어 Harness를 닫을 때 CUT
  복사본이 원본 모델로 역전파되지 않게 합니다.

**확인:** 모델을 열어 CUT에 Harness 배지가 붙었는지 봅니다. `HarnessCreateResult.ini`의
`Status` 열이 전부 `OK` 또는 `SKIP`이어야 합니다.

**실패 시:** `HarnessChangedLibraryLink`가 나오면 **모델을 저장하지 말고** 닫으십시오.
자세한 내용은 [문제 해결](../troubleshooting.md)에 있습니다.

### 2단계 — 입력 설정

입력 설정은 세 명령으로 나뉘며 **이 순서로** 실행해야 합니다.

```matlab
[R, ScenarioR] = st_prepare_sldv_targets();   % 2a. 입력 데이터 준비
disp(R)

R = st_configure_harnesses();                  % 2b. Harness StopTime 등 설정
disp(R)

R = st_configure_signal_editors();             % 2c. Signal Editor에 연결
disp(R)
```

#### 2a. `st_prepare_sldv_targets` — 입력 데이터를 만들거나 읽습니다

Excel의 `SldvMode`에 따라 동작이 다릅니다.

| `SldvMode` | 하는 일 |
| --- | --- |
| `OFF` | Harness에 이미 있는 입력을 그대로 씁니다 |
| `FILE` | `SldvDataFile`의 MAT을 검증해 Scenario로 변환합니다 |
| `GENERATE` | SLDV 분석을 돌려 입력을 새로 만듭니다 (오래 걸립니다) |

만들어진 내용은 `result/sldv/sldv_manifest.mat`에 기록되고 **이후 모든 단계가 이
manifest를 읽습니다.** 그래서 이 단계를 건너뛰면 뒤 단계가 실패합니다.

두 번째 출력 `ScenarioR`에 Scenario 이름과 개수가 들어 있습니다.

#### 2b. `st_configure_harnesses` — Harness 설정

각 Harness의 Solver `StopTime`을 정합니다. `FILE`/`GENERATE` 대상은 입력의
`Tmax`를, `OFF` 대상은 `cfg.HarnessStopTime`을 씁니다.

#### 2c. `st_configure_signal_editors` — 입력을 Harness에 연결

| `SldvMode` | 하는 일 |
| --- | --- |
| `OFF` | 기존 ActiveScenario 이름을 `UT_REQ_{CUTName}_001`로 바꾸고 선택합니다 |
| `FILE`/`GENERATE` | 전용 Signal Editor MAT에 Scenario를 써 넣고, Filename을 저장한 뒤 Harness를 다시 열어 그 Scenario를 선택합니다 |

**확인:** Harness를 열어 Signal Editor 블록의 파일 경로와 선택된 Scenario 이름이
`UT_REQ_`로 시작하는지 봅니다.

**실패 시:** `MatHarnessInterfaceMismatch`는 Dataset과 Harness의 입력 구성이 다르다는
뜻입니다. 개수·순서·이름·자료형·차원이 모두 같아야 합니다.

### 3단계 — Assessment 설정

```matlab
R = st_configure_assessments();
disp(R)
```

Harness 안의 Test Assessment 블록에 `verify` 문장을 만듭니다.

- 실제 Input symbol의 Port 순서에서 Signal Editor 입력 수만큼 건너뛴 뒤, Harness
  Outport와 **위치로** 연결합니다. 이름으로 추측하지 않습니다.
- 만들어지는 구조는 `step1`(대기) → `step2`(`verify(출력 == 기대값)`)입니다.
- scalar, numeric array, Bus, nested Bus를 지원합니다.

기대값의 초기값은 이 시점에 정해지며, 실제 값으로 맞추는 것은 6단계입니다.

**확인:** Harness의 Test Assessment 블록을 열어 `step2`의 `verify` 줄을 봅니다.
실행 없이 표로 뽑아 보려면:

```matlab
[T, file] = st_export_test_specification();
```

**정상인데 verify가 비어 있는 경우:** `cfg.VerifyHarnessOutportsOnly=true`(기본)이고
쓸 수 있는 Harness 출력이 하나도 없으면 빈 Action으로 구성됩니다. 오류가 아닙니다.

### Coverage 필터는 단계가 아닙니다

CVF는 **실행하는 쪽이 만듭니다.** `BATCH`는 `st_run_generated_tests`가 실행
직전에, `PER_CUT`은 `st_run_tests_per_cut`이 CUT 폴더 안에서, standalone은
내보낸 번들 안에서 만듭니다. 그래서 준비 단계에서 미리 만들 것이 없습니다.

내용을 미리 눈으로 확인하고 싶을 때만 직접 부릅니다. 실행이 어차피 다시
만들기 때문에 결과는 참고용입니다.

```matlab
R = st_prepare_coverage_filters();
disp(R)
```

### 5단계 — Test Case 생성

```matlab
R = st_create_test_manager();
disp(R)

R = st_validate_scenario_alignment();
disp(R)
```

#### 5a. `st_create_test_manager`

Test File(`{TopModel}.mldatx`)에 Test Case와 Iteration을 만듭니다.

- 기본값 `cfg.OverwriteTestFile=false`는 **증분 갱신**입니다. 기존 Test File과 Test
  Case를 보존하고 없는 것만 추가합니다.
- SLDV 행은 그 Test Case의 Iteration만 Scenario 수에 맞게 다시 구성합니다.
- 다른 열린 Test Manager 파일을 전역으로 제거하지 않습니다.

#### 5b. `st_validate_scenario_alignment`

입력 Scenario 수와 Iteration 수가 일대일로 맞는지 확인합니다. **확인만 하고
고치지 않습니다.**

여기서 걸리면 보통 입력 MAT을 바꾼 뒤 5a를 다시 돌리지 않은 경우입니다. 2단계부터
다시 하십시오.

**확인:** Test Manager를 열어 Test Case와 Iteration 목록을 봅니다.

```matlab
sltest.testmanager.view
```

### 6단계 — 실행 및 verify 수정

**어느 명령을 쓸지는 Coverage 필터 사용 여부로 정해집니다.**

| 상황 | 명령 |
| --- | --- |
| Excel에 활성 CVF 행이 하나라도 있다 | `st_run_tests_per_cut` |
| 전부 `OFF`다 | `st_run_generated_tests` |

```matlab
% CVF를 쓰는 경우 (standalone 제출물을 만들 예정이면 이쪽)
[results, updates, summary] = st_run_tests_per_cut( ...
    'ContinueOnFailure', true, ...
    'ReportMode', 'SUMMARY', ...
    'FailOnNonPass', false);

% CVF가 전혀 없는 경우
[resultObj, updateResult, runContext] = st_run_generated_tests();
```

> `st_run_generated_tests`는 BATCH 경로라서 **활성 CVF가 있으면 실행 전에
> `BatchExecutionWithCoverageFilter` 오류를 냅니다.** 그때는
> `st_run_tests_per_cut`을 쓰십시오.

#### 이 단계에서 일어나는 일

`ExpectedUpdateMode`가 `APPLY`인 대상이 하나라도 있으면 다음 순서로 진행합니다.

```text
1. Harness Outport 신호 로깅 준비
2. 테스트 실행
3. 실패한 Iteration에서 기준 시점의 실제값 추출
4. verify(... == 기대값)의 기대값을 그 값으로 갱신
5. 갱신된 값이 있고 cfg.RerunAfterExpectedUpdate=true이면 재실행
```

기준 시점은 `OFF` 대상은 `cfg.ExpectedValueSampleTime`(기본 0.01초), `FILE`/`GENERATE`
대상은 그 CUT의 `Tmax`입니다.

전부 `OFF`면 1회 실행하고 끝냅니다.

#### 반환값

| 값 | 내용 |
| --- | --- |
| `resultObj` / `results` | 최종 실행 결과. 재실행하지 않았으면 최초 결과 |
| `updateResult` / `updates` | 어떤 verify의 기대값이 무엇으로 바뀌었는지 |
| `runContext` / `summary` | 보고서용 최초·최종 ResultSet |

**확인:** `updateResult`를 먼저 보십시오. 의도하지 않은 기대값이 바뀌었다면 Excel의
`ExpectedUpdateMode`를 `OFF`로 내리고 모델을 되돌린 뒤 다시 하십시오.

```matlab
disp(updateResult)
```

#### verify를 손으로 고치고 싶다면

기대값 자동 갱신을 끄고 Test Assessment 블록에서 직접 고친 뒤 실행만 다시
하십시오.

```matlab
% Excel의 ExpectedUpdateMode를 모두 OFF로 바꾼 뒤
[resultObj, updateResult] = st_run_generated_tests();
```

### 7단계 — standalone 제출물

```matlab
info = st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);

[code, summary, details] = st_check_standalone_coverage();
```

원본 Top Model과 열린 Harness를 **저장하고 닫은 뒤** 실행합니다. 자세한 내용은
[Standalone 실행](standalone-run.md)에 있습니다.

## 4. 순서를 지켜야 하는 이유

각 단계가 앞 단계의 산출물을 읽기 때문에 임의 순서로 부르면 실패합니다.

```text
st_create_harnesses        → Harness가 생김
        ↓ (Harness 필요)
st_prepare_sldv_targets    → sldv_manifest.mat이 생김
        ↓ (manifest 필요)
st_configure_harnesses     → StopTime이 정해짐
st_configure_signal_editors→ Scenario가 Harness에 연결됨
        ↓ (Scenario 개수 필요)
st_configure_assessments   → verify 문장이 생김
        ↓ (Harness와 Scenario 필요)
st_create_test_manager     → Test Case와 Iteration이 생김
        ↓ (Test File 필요)
st_run_tests_per_cut       → 결과와 보고서가 생김
```

가장 자주 하는 실수는 `st_prepare_sldv_targets`를 건너뛰는 것입니다. manifest가
없으면 그 뒤 단계가 전부 실패합니다.

## 5. 여기까지 했는데, 그 다음부터 진행하려면

선택지가 셋입니다. **셋의 동작이 서로 다르므로 표를 먼저 보십시오.**

| 방법 | 앞 단계를 다시 실행하나 | checkpoint를 남기나 | 언제 |
| --- | --- | --- | --- |
| A. 남은 단계 명령을 계속 부른다 | 아니요 | **아니요** | 단계별 확인을 계속할 때 |
| B. `st_run_from_harness('PreparationMode','FORCE','FromStage',X)` | **가능성 있음** | 예 | 남은 과정을 한 번에 끝낼 때 |
| C. `st_check_readiness` + `st_run_from_stage` | 아니요 (검증 후 차단) | 예 | 앞 단계를 절대 다시 돌리면 안 될 때 |

### 방법 A — 남은 단계 명령을 계속 부르기

가장 단순합니다. [1장 표](#1-전체-단계-지도)의 남은 행을 순서대로 실행하면
됩니다. 예를 들어 Assessment까지 끝냈다면:

```matlab
R = st_create_test_manager();
R = st_validate_scenario_alignment();
[results, updates, summary] = st_run_tests_per_cut( ...
    'ContinueOnFailure', true, 'ReportMode','SUMMARY', 'FailOnNonPass', false);
```

> 이 방식은 **checkpoint를 남기지 않습니다.** 나중에 `st_run_from_harness`를 부르면
> 이 도구는 "준비된 적 없음"으로 판단해 SLDV 단계부터 다시 실행합니다. `GENERATE`
> 대상이 있으면 그만큼 오래 걸립니다.

### 방법 B — 나머지를 한 번에 끝내기

```matlab
st_run_from_harness('PreparationMode','FORCE', 'FromStage','TEST_MANAGER');
```

지정한 단계부터 끝까지 강제로 실행하고 checkpoint도 남깁니다.

> **`FromStage`는 앞 단계를 "건너뛰라"는 뜻이 아닙니다.** 지정한 단계부터 강제로
> 다시 하라는 뜻일 뿐이고, 그보다 앞 단계는 여전히 fingerprint로 판정됩니다.
> 단계 명령을 직접 불러서 checkpoint가 없는 상태라면 **앞 단계도 함께
> 실행됩니다.** 앞 단계 재실행을 확실히 막으려면 방법 C를 쓰십시오.

`FromStage`에 넣을 수 있는 값:

```text
HARNESS, SLDV, HARNESS_CONFIG, SIGNAL_EDITOR, ASSESSMENT,
TEST_MANAGER, ALIGNMENT
```

### 방법 C — 앞 단계를 절대 다시 돌리지 않기

```matlab
[ready, checks] = st_check_readiness( ...
    'Workflow','FROM_HARNESS', 'FromStage','TEST_MANAGER');
disp(checks)
assert(ready.Ready, 'checks의 RequiredFromStage를 확인하십시오.');

info = st_run_from_stage('Workflow','FROM_HARNESS', 'FromStage','TEST_MANAGER');
```

동작이 방법 B와 다릅니다.

1. `st_check_readiness`가 앞 단계 산출물을 **읽기 전용으로 검증**합니다.
2. 유효하지 않으면 자동으로 고치지 않고 `RestartBlocked`로 **중단**합니다.
   `checks.RequiredFromStage`에 어디부터 시작해야 하는지가 적혀 있습니다.
3. 유효하면 지정 단계 앞은 `CACHED`로 못 박고 그 단계부터만 실행합니다.

Harness 생성이나 SLDV `GENERATE`처럼 오래 걸리는 앞 단계를 보존해야 할 때
이 방법을 쓰십시오.

`Workflow`는 `FROM_HARNESS`(Harness 생성 포함)와 `AFTER_HARNESS`(Harness 생성 제외)
중에서 고릅니다.

## 6. 자주 쓰는 조합

### Harness만 먼저 만들어 두기

```matlab
st_setup
st_pre_validate_targets
st_create_harnesses
```

며칠 뒤 이어서 할 때:

```matlab
st_setup
st_run_from_harness   % Harness는 이미 있으므로 건너뛰고 나머지를 진행합니다
```

### 준비만 하고 실행은 Test Manager에서 직접

```matlab
st_setup
st_run_from_harness('ExecuteTests', false);
sltest.testmanager.view
```

### 입력 MAT을 바꾼 뒤 2단계부터

```matlab
st_run_from_harness('PreparationMode','FORCE', 'FromStage','SLDV');
```

### Assessment만 다시 만들기

```matlab
R = st_configure_assessments();
R = st_create_test_manager();
R = st_validate_scenario_alignment();
```

Assessment 구조가 바뀌면 Iteration 연결도 다시 확인해야 하므로 5단계까지 함께
돌립니다.

### 실행만 다시 하기

준비는 그대로 두고 테스트만 다시 돌립니다.

```matlab
[results, updates, summary] = st_run_tests_per_cut( ...
    'ContinueOnFailure', true, 'ReportMode','SUMMARY', 'FailOnNonPass', false);
```

## 7. 주의사항

- **단계 명령은 관리 Excel의 활성 행 전체를 대상으로 합니다.** 일부 CUT만
  처리하려면 `Enabled` 열을 쓰십시오.
- **단계 명령은 checkpoint를 남기지 않습니다.** 증분 실행의 이점을 쓰려면
  `st_run_from_harness` 계열로 마무리하십시오.
- **1~5단계는 모델과 Test File을 실제로 저장합니다.** 되돌리려면 백업이 필요합니다.
- **6단계는 기대값을 바꿀 수 있습니다.** `ExpectedUpdateMode`를 먼저 확인하십시오.
- 중간에 `Ctrl+C`로 멈췄다면 열린 Harness와 모델의 Dirty 상태를 확인하고 저장 여부를
  판단한 뒤 그 단계부터 다시 실행하십시오.
- 단계별 결과 INI의 `Status`와 `Message` 열이 가장 빠른 진단 수단입니다.

각 명령이 받는 옵션의 전체 목록은 [실행 명령 사전](../execution-commands.md),
단계별 내부 동작은 [운영자 매뉴얼](../operator-manual.md)에 있습니다.
