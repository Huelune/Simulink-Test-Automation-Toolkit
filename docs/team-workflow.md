# 팀 작업 절차 — Harness 생성부터 최종 문서까지

CUT 목록이 적힌 Excel 한 장에서 시작해 **고객 제출용 최종 문서 Excel과 제출 폴더가
나오기까지**를 순서대로 따라가는 절차서입니다. 한 단계마다 무엇을 입력하고,
무엇이 만들어지고, 어떻게 끝났는지 확인하는지를 적었습니다.

명령 하나하나의 옵션이 궁금하면 [내부 표준 명령](team-commands.md)을,
MATLAB이 처음이면 [처음 시작하기](getting-started.md)를 옆에 두십시오. 이 문서는
**순서와 확인 방법**에 집중합니다.

## 0. 한눈에 보기

```text
 준비        TestManagement.xlsx 작성 → st_pre_validate_targets
   │
 1단계       st_run_from_harness('AutoCollect', true)
   │         Harness 생성 → 입력 → verify → Test Case → 실행 → 결과 정리
   │
 2단계       (선택) st_export_test_specification      명세서 Excel
   │
 3단계       Top Model·Harness 저장 후 닫기
   │         st_run_standalone_coverage_pipeline('Action','ALL', ...)
   │         st_check_standalone_coverage   →  1111111111 PASS
   │
 4단계       python classify_standalone_results.py    팀 제출 트리
   │
 5단계       st_export_final_document                 고객 제출용 최종 문서
```

| 단계 | 명령 | 만들어지는 것 | 끝났다는 증거 |
| --- | --- | --- | --- |
| 준비 | `st_pre_validate_targets` | `result/reports/PreValidationResult.ini` | 모든 행이 통과 |
| 1 | `st_run_from_harness('AutoCollect', true)` | Harness, Test File, `result/run_records/`, `result/per_cut_runs/` | 마지막 로그가 `EXECUTE` 완료, 결과 요약 Excel이 열림 |
| 2 | `st_export_test_specification` | `result/test_specification_<시각>.xlsx` | 파일이 열리고 행 수가 시나리오 수와 같음 |
| 3 | `st_run_standalone_coverage_pipeline` + `st_check_standalone_coverage` | `result/standalone_coverage/<PipelineId>/` | 검사 코드 `1111111111`, `Status = PASS` |
| 4 | `classify_standalone_results.py` | `result/standalone_coverage/<TopModel>/` 세 갈래 | 건너뛴 목록에 `.slx`·`.cvf`·`.cvt`·`.html`·`.mat`이 없음 |
| 5 | `st_export_final_document` | `result/final_document_<시각>.xlsx` | `TestResults` 시트에 `확인 필요 = Y`가 없거나 전부 검토됨 |

한 번에 끝내는 복사용 코드는 [8절](#8-복사용-전체-코드)에 있습니다. 처음 하는
분은 단계별로 읽으면서 하나씩 실행하십시오.

## 1. 시작 전에 한 번만

### 1.1 툴킷을 최신으로

MATLAB이 쓰는 툴킷은 **모델 프로젝트 안에 둔 클론**입니다. 개발 폴더가 아닙니다.
시작할 때마다 그 클론에서 최신을 받으십시오.

```bash
git pull
```

같은 오류가 이미 고쳐졌는데 다시 나면, 십중팔구 MATLAB이 예전 커밋에서 돌고 있는
것입니다. MATLAB에서 `which -all st_setup`으로 어느 폴더가 잡혔는지 확인하십시오.

### 1.2 준비물

| 항목 | 확인 |
| --- | --- |
| MATLAB R2025b, Simulink, Simulink Test | 필수 |
| Simulink Coverage | 커버리지·standalone 제출물에 필수 |
| Simulink Design Verifier | `SldvMode = GENERATE`를 쓸 때만 |
| Python 3.8 이상 | 4단계 제출 트리 재배치에만 |
| 원본 모델·Test File 백업 | **1단계는 모델과 Test File을 저장합니다** |

### 1.3 `TestManagement.xlsx` 작성

저장소 루트의 `TestManagement.xlsx`, `Targets` 시트가 유일한 입력입니다. 한 행이
CUT 하나입니다. 열 순서는 상관없고 이름으로 찾습니다.

**필수 4열**

| 열 | 적는 것 | 예 |
| --- | --- | --- |
| `CUTName` | Subsystem 블록 이름 | `Controller` |
| `CUTPath` | Top Model 이름부터 시작하는 전체 경로 | `TopModel/Logic/Controller` |
| `HarnessName` | 만들거나 재사용할 Harness 이름 | `Controller_Harness1` |
| `TestCaseName` | Test Manager에 만들 Test Case 이름 | `Controller_12345` |

**같이 정해 두는 열**

| 열 | 권장 값 | 왜 |
| --- | --- | --- |
| `Enabled` | `TRUE` | 이번에 처리할 행만 `TRUE` |
| `SldvMode` | `OFF` / `FILE` / `GENERATE` | 입력을 어디서 가져올지. `FILE`이면 `SldvDataFile`도 적습니다 |
| `ExpectedUpdateMode` | 승인된 기준값이 있으면 **`OFF`** | 기본은 `APPLY`라서 실패하면 실제 출력값으로 기대값을 덮어씁니다 |
| `CoverageFilterMode` | `ALL_CONTENT` | 3단계 standalone이 요구하는 조합 |
| `CoverageBoundaryMode` | `CUT_ONLY` | 〃 |
| `CoverageFilterAction` | `EXCLUDE` | 〃 |
| `CoverageFilterRationale` | 비어 있지 않은 사유 | 비어 있으면 3단계가 시작하지 않습니다 |

같은 `CUTPath`를 두 활성 행에 적지 마십시오. 서로의 Harness 설정을 덮어씁니다.
열의 뜻과 오답 시 동작은 [관리 Excel 열 사전](workbook-reference.md)에 있습니다.

### 1.4 MATLAB 세션 열기

Current Folder를 **툴킷 클론 루트**(`st_setup.m`이 보이는 폴더)로 맞춘 뒤 실행합니다.

```matlab
st_setup                    % MATLAB을 켤 때마다 1회
st_select_target_model      % 처음 1회, 또는 모델을 바꿀 때만
```

`st_select_target_model`은 목록에서 Top Model을 고르고 `runtime_target.mat`에
저장합니다. 이후 모든 명령이 이 선택을 씁니다. 다시 고르려면
`st_select_target_model(true)`입니다.

### 1.5 Excel 검사

```matlab
R = st_pre_validate_targets();
disp(R)
```

`CUTPath`가 실제로 존재하는 Subsystem인지 확인합니다. 모델을 바꾸지 않습니다.

> **여기서 걸리면 다음으로 넘어가지 마십시오.** Harness를 엉뚱한 블록에 만들게
> 됩니다. 대부분 경로 오타이거나 모델 이름부터 시작하지 않는 경로입니다.

Excel을 고칠 때마다 다시 실행합니다.

## 2. 1단계 — Harness 생성부터 실행과 결과 정리까지

```matlab
st_run_from_harness('AutoCollect', true)
```

이 한 줄이 아래를 순서대로 합니다.

| 단계 | 하는 일 | 바뀌는 것 |
| --- | --- | --- |
| `HARNESS` | 없는 Harness를 만듭니다. **있는 Harness는 그대로 둡니다** | 모델 |
| `SLDV` | 입력 데이터를 준비합니다 (`OFF`/`FILE`/`GENERATE`) | 입력 MAT |
| `HARNESS_CONFIG` | StopTime 등 Harness 설정 | Harness |
| `SIGNAL_EDITOR` | 입력 Scenario를 만들어 Harness에 연결 | Harness |
| `ASSESSMENT` | `verify` 문장 구성 | Harness |
| `TEST_MANAGER` | Test File, Test Case, Iteration 구성 | Test File |
| `ALIGNMENT` | 네 곳의 Scenario 이름이 일치하는지 검사만 | 없음 |
| `EXECUTE` | 실행 → 실패 시 기대값 갱신 → 재실행 → 실행 기록 저장 | Harness, `result/run_records/` |
| 결과 정리 | `st_collect_per_cut_results`를 이어서 실행 | `result/per_cut_runs/` |

Harness가 **이미 전부 있으면** `st_run_after_harness('AutoCollect', true)`를
써도 됩니다. `HARNESS` 단계 하나만 빠지고 나머지는 같습니다.

### 2.1 왜 `AutoCollect`를 켜는가

실행은 **기록만 남기고 끝납니다.** 판정과 커버리지를 파일로 정리하는 것은 결과
정리 단계이고, 기본 설정에서는 자동으로 돌지 않습니다. 결과 정리를 빼먹으면

- 5단계 최종 문서의 `판정 결과`가 전부 빈 칸이 되고,
- `Description` 열이 커버리지가 잡은 분기 대신 정적 스캔 결과로 채워집니다.

그래서 실행할 때마다 정리까지 한 번에 하는 것을 표준으로 합니다. 따로 하려면
실행 뒤 `st_collect_per_cut_results`를 부르면 됩니다.

> **정리한 뒤 테스트를 다시 돌리면 정리 결과가 무효가 됩니다.** 새 실행이
> 포인터를 새 실행으로 옮기기 때문입니다. 다시 돌렸으면 다시 정리하십시오.

### 2.2 실행 중 볼 것

- 로그의 마지막 `START`가 지금 진행 중인 단계입니다. Harness 생성과 SLDV
  `GENERATE`는 CUT 하나에 수 분이 걸리는 것이 정상입니다.
- 기본 실행 방식은 `PER_CUT`입니다. Test Case를 하나씩 돌리고, 한 CUT이 터져도
  기록하고 다음 CUT으로 넘어갑니다(`ContinueOnFailure` 기본 `true`).

### 2.3 끝났는지 확인

```matlab
cfg = st_config();
latest = jsondecode(fileread(cfg.PerCutLatestPointer));
disp(latest.Status)          % 전체 상태
winopen(latest.Summary)      % CUT별 결과 요약 Excel
```

| 볼 것 | 정상 |
| --- | --- |
| `latest.Status` | `PASS`. `PASS_WITH_WARNINGS`는 경고를 읽고 넘어가고, `PARTIAL`·`FAIL`은 아래 표에서 원인을 찾습니다 |
| 요약 Excel의 `Targets` 시트 | 모든 CUT의 `Status`가 `PASS` |
| CUT 폴더의 `TestSummary.xlsx` → `Iterations` 시트 | 모든 iteration이 `Passed` (재실행이 있었으면 `final/` 쪽) |
| Simulink 모델 창 | Harness가 Excel의 `HarnessName`대로 생겼음 |
| Test Manager | `TestCaseName`대로 Test Case가 있고 Iteration 수가 Scenario 수와 같음 |

`Failed`가 있으면 `result/per_cut_runs/` 아래 그 CUT 폴더의 `.mldatx`를 Test Manager에서 열어 어느 verify가
틀렸는지 봅니다. `ExpectedUpdateMode`가 `APPLY`였다면 첫 실행 실패는 기대값이
갱신되고 재실행에서 `Passed`로 바뀌어야 정상입니다. 재실행도 실패했으면 모델이나
verify 자체를 봐야 합니다.

### 2.4 다시 돌려야 할 때

두 번째 실행부터는 바뀌지 않은 단계를 건너뜁니다. 무엇을 고쳤는지에 따라 어디서
부터 강제할지 정합니다.

| 무엇을 고쳤나 | 명령 |
| --- | --- |
| Excel의 CUT 목록 (행 추가·삭제) | `st_pre_validate_targets` → `st_run_from_harness('AutoCollect', true)` |
| 입력 MAT, `SldvMode` | `st_run_from_harness('PreparationMode','FORCE','FromStage','SLDV','AutoCollect',true)` |
| verify 대상, Assessment | `... 'FromStage','ASSESSMENT' ...` |
| Test Case 이름, Iteration | `... 'FromStage','TEST_MANAGER' ...` |
| `Coverage*` 네 열만 | **다시 돌리지 않습니다.** `st_collect_per_cut_results`만 다시 하면 됩니다 |
| 전부 처음부터 | `st_run_from_harness('PreparationMode','FORCE','AutoCollect',true)` |

특정 CUT만 다시 돌리려면 나머지 행의 `Enabled`를 `FALSE`로 내리는 것이 가장
간단합니다.

## 3. 2단계 (선택) — 테스트 명세서 Excel

테스트를 돌리지 않고 저장된 Harness에서 시나리오·입력 마지막 값·verify 문장을
Excel로 뽑습니다. 검토용이며 5단계 최종 문서는 이 파일을 읽지 않고 같은 내용을
다시 추출합니다. 필요 없으면 건너뛰어도 됩니다.

```matlab
[T, specFile] = st_export_test_specification();
winopen(specFile)
```

모델·Harness·Test File이 **저장**되어 있어야 합니다. 저장되지 않은 것이 있으면
어느 모델인지 알려 주고 멈춥니다. 열 구성은 [테스트 명세서 추출](test-specification.md)에
있습니다.

## 4. 3단계 — standalone 제출물

Harness를 원본 모델 없이도 열리는 **독립 모델**로 떼어내 실행하고, 커버리지
결과와 부속 파일을 제출물로 묶습니다.

### 4.1 실행 전 — 반드시

1. 원본 Top Model, Harness, Test File을 **저장**합니다.
2. Top Model과 열려 있는 Harness를 **닫습니다.** 복사본과 이름이 충돌하기
   때문이고, 이 명령은 사용자 모델을 강제로 닫지 않습니다. 확실하게 하려면
   MATLAB을 재시작하고 `st_setup`부터 다시 합니다.
3. Excel의 활성 행마다 `Coverage*` 네 열이 [1.3절](#13-testmanagementxlsx-작성)의
   조합인지 확인합니다. `CoverageFilterRationale`이 비면 시작하지 않습니다.

### 4.2 실행

```matlab
info = st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);
disp(info.PipelineId)
```

`EXECUTE → PACKAGE → SUMMARY`를 한 번에 합니다. 기대값은 갱신하지 않고, 준비된
자산을 복사해 **한 번만** 실행합니다. `info.PipelineId`는 4단계와 5단계에서
쓰니 적어 두십시오.

### 4.3 검사

```matlab
[code, summary, details] = st_check_standalone_coverage();
disp(code)
disp(summary)
```

| 결과 | 뜻 |
| --- | --- |
| `1111111111` + `summary.Status = 'PASS'` | 정상. 다음 단계로 |
| 비트에 `0` | 그 항목 실패. `details` 표에서 어느 CUT인지 확인 |
| 비트에 `-` 또는 `PARTIAL` | 적용할 수 없는 검사가 있거나 `EXCEPT`로 끝난 CUT이 있음 |

읽기 전용 검사이므로 몇 번을 돌려도 무엇도 바뀌지 않습니다. 비트별 검사 내용은
[내부 표준 명령](team-commands.md#st_check_standalone_coverage)에 있습니다.

### 4.4 만들어진 것

`result/standalone_coverage/<PipelineId>/` 아래입니다. 경로가 너무 길다는 오류가
나면 `st_set_standalone_coverage_root('D:\st_out')`처럼 짧은 경로를 지정하고
다시 돌립니다.

```text
<PipelineId>/
├── 001_UT_REQ_{TestCaseName}/        CUT 폴더
│   ├── {HarnessName}.slx               standalone 모델
│   ├── {...}_HarnessInputs.mat         Signal Editor 입력
│   ├── UT_REQ_{TestCaseName}.cvf       적용한 커버리지 필터
│   ├── UT_REQ_{TestCaseName}.cvt       커버리지 원본 데이터
│   ├── UT_REQ_{TestCaseName}.html      커버리지 보고서 (+ 부속 asset 폴더)
│   └── target-manifest.json
├── 002_UT_REQ_.../
├── TestManager/{TopModel}.mldatx      standalone 모델로 재배선된 Test File
└── CoverageSummary.xlsx               11열 커버리지 요약
```

받은 사람이 Test Manager에서 열어 보는 방법은 `st_open_standalone_test_manager`
하나입니다. 우리가 먼저 열어 확인할 때도 같은 명령을 씁니다.

```matlab
st_open_standalone_test_manager                          % 가장 최근 제출물
st_open_standalone_test_manager('PipelineId', info.PipelineId)
```

같은 이름의 Test File이 이미 열려 있다고 멈추면 `'ClearTestManager', true`를
붙입니다. 열린 Test File과 Result를 모두 닫으니 저장할 것이 있으면 먼저 저장하십시오.

## 5. 4단계 — 팀 제출 트리로 재배치

파이프라인 폴더는 CUT별로 파일 종류가 섞여 있지만, 팀 제출은 **파일 종류별 세
갈래**를 씁니다. Python 스크립트가 파일 이름을 바꾸지 않고 복사만 합니다.
MATLAB이 필요 없고 표준 라이브러리만 씁니다.

툴킷 클론 루트에서 실행합니다.

```bash
python tools/python/classify_standalone_results.py result/standalone_coverage/<PipelineId>
```

먼저 계획만 보려면 `--dry-run`을 붙입니다. 출력 위치를 바꾸려면 `--out <폴더>`,
이미 있는 출력 폴더를 덮어쓰려면 `--overwrite`입니다.

파이프라인 폴더 **옆에** `{TopModel}/`이 생깁니다.

```text
result/standalone_coverage/{TopModel}/
├── 테스트 케이스/{NUM}_UT_REQ_{TestCaseName}/    Input .mat
├── 테스트 보고서/{TopModel}.mldatx
├── 테스트 보고서/{NUM}_UT_REQ_{TestCaseName}/    .cvf .cvt .html + 부속 asset 폴더
└── 프로젝트/{NUM}_UT_REQ_{TestCaseName}/         standalone 모델 .slx
```

`CoverageSummary.xlsx`, manifest, 로그, launcher, CUT 폴더 안의 `scv_images`는
복사하지 않고 **건너뛴 목록으로 출력**합니다. 그 목록에 `.slx`·`.mat`·`.cvf`·
`.cvt`·`.html`이 보이면 CUT 폴더 이름이 `NNN_UT_REQ_` 규칙을 벗어난 것이니 원인을
확인하십시오. 종료 코드는 `0` 성공, `1` 복사 중 예외, `2` 입력·출력 검증 실패입니다.

원본 파이프라인 폴더는 그대로 남으므로 `st_open_standalone_test_manager`와
`st_export_final_document`는 계속 원본에 대해 동작합니다. **HTML은 옆의 부속
폴더 없이 렌더링되지 않으니** 전달할 때는 CUT 폴더 단위로 통째로 복사하십시오.

## 6. 5단계 — 고객 제출용 최종 문서

명세서 내용, 1단계 결과 정리의 판정, 3단계 `CoverageSummary.xlsx`를 한 Excel로
모읍니다. 테스트를 돌리지 않고 모델을 바꾸지 않습니다.

### 6.1 실행 전 확인

| 조건 | 안 되어 있으면 |
| --- | --- |
| 1단계 결과 정리가 끝났고, 그 뒤 테스트를 다시 돌리지 않았다 | `판정 결과`가 전부 빈 칸, `TestResults`에 `NOT_COLLECTED` |
| 3단계 제출물이 있다 | `Coverage` 시트가 전부 `N/A`, `NO_COVERAGE_SOURCE` |
| 모델·Harness·Test File이 저장되어 있다 | `simtest:SpecificationUnsaved`로 중단 |

> 결과 정리 명령은 커버리지를 읽으려고 모델을 여는데, 그 과정에서 원래 열려 있던
> 모델이 **미저장 상태**가 될 수 있습니다. "방금 정리했는데 저장하라고 한다"가
> 실제로 일어납니다. 오류 메시지에 적힌 모델을 저장하고 다시 부르십시오.

### 6.2 실행

```matlab
[T, finalFile] = st_export_final_document();
winopen(finalFile)
```

기본 출력은 `result/final_document_<시각>.xlsx`입니다. 판정은 가장 최근 실행
(`PER_CUT`과 `BATCH` 중 더 최근 쪽)에서, 커버리지는 가장 최근 standalone
제출물(`LATEST`)에서 읽습니다. 특정 제출물을 쓰려면
`'CoveragePipelineId', info.PipelineId`를 줍니다.

빈 판정이나 빈 커버리지를 허용하지 않으려면 `'RequireTestResults', true`,
`'RequireCoverage', true`를 붙입니다. 조건이 안 맞으면 파일을 만들지 않고 중단합니다.

### 6.3 제출 전 검토

| 시트 | 볼 것 |
| --- | --- |
| `TestResults` | **`확인 필요`가 `Y`인 행만** 봅니다. `FAILED`면 `확인 위치`의 `.mldatx`를 Test Manager에서 엽니다 |
| `Metadata` | `ResultRunId`가 방금 돌린 1단계 실행인지, `CoveragePipelineId`가 방금 만든 3단계 제출물인지 |
| `TestCase` | `Test Case ID`가 `UT_REQ_{CUT}_{ID}_{NUM}`, `ID`가 codeBeamer ID로 나뉘어 있는지. `TESTCASE_ID_PATTERN_UNMATCHED`가 있으면 그 행은 이름 규칙 밖입니다 |
| `Coverage` | CUT 수가 Excel 활성 행 수와 같은지, 분자·분모가 `CoverageSummary.xlsx`와 같은지 |

판정과 커버리지는 **서로 다른 실행**에서 옵니다. standalone은 독립 모델로 돌아
PASS/FAIL이 다를 수 있으므로 판정은 1단계에서, 커버리지만 3단계에서 가져옵니다.
`Metadata` 시트에 두 실행의 식별자가 모두 남습니다.

시트별 열 구성과 `확인 사유` 코드 전체는 [최종 문서 추출](final-document.md)에
있습니다.

## 7. 제출 묶음

| 무엇 | 어디서 | 비고 |
| --- | --- | --- |
| 최종 문서 Excel | `result/final_document_<시각>.xlsx` | 5단계 |
| 제출 트리 `{TopModel}/` 세 갈래 | `result/standalone_coverage/{TopModel}/` | 4단계. 폴더 단위로 통째로 |
| `CoverageSummary.xlsx` | `result/standalone_coverage/<PipelineId>/` | 4단계가 복사하지 않으므로 필요하면 따로 |
| 명세서 Excel (요청 시) | `result/test_specification_<시각>.xlsx` | 2단계 |

실제 모델·Excel·MAT·MLDATX와 `result/` 폴더는 **Git에 올리지 않습니다.**

## 8. 복사용 전체 코드

처음부터 끝까지 한 세션에서 하는 경우입니다. 3단계 앞에서 **모델을 저장하고 닫는
것**만 손으로 합니다.

```matlab
%% 준비 — MATLAB을 켤 때마다
st_setup
st_select_target_model          % 처음 1회, 또는 모델을 바꿀 때만
R = st_pre_validate_targets();  % Excel을 고칠 때마다
disp(R)

%% 1단계 — Harness 생성 → 실행 → 결과 정리
st_run_from_harness('AutoCollect', true)
% Harness가 이미 전부 있으면: st_run_after_harness('AutoCollect', true)

cfg = st_config();
latest = jsondecode(fileread(cfg.PerCutLatestPointer));
disp(latest.Status)
winopen(latest.Summary)

%% 2단계 (선택) — 명세서 Excel
[T, specFile] = st_export_test_specification();
disp(specFile)

%% 3단계 — 원본 Top Model과 Harness를 저장하고 닫은 뒤
info = st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);
disp(info.PipelineId)

[code, summary, details] = st_check_standalone_coverage();
disp(code)                      % 1111111111 이어야 합니다
disp(summary)

%% 4단계 — 팀 제출 트리 (MATLAB 밖 명령 프롬프트에서)
% python tools/python/classify_standalone_results.py result/standalone_coverage/<PipelineId>

%% 5단계 — 고객 제출용 최종 문서
[T, finalFile] = st_export_final_document('CoveragePipelineId', info.PipelineId);
winopen(finalFile)
```

## 9. 자주 막히는 곳

| 증상 | 대처 |
| --- | --- |
| `st_setup` 뒤에도 명령을 못 찾는다 | Current Folder가 클론 루트가 아닙니다 |
| 고쳐진 오류가 다시 난다 | 클론이 예전 커밋입니다. `git pull` 후 MATLAB에서 `which -all st_setup` |
| `CUTPath`를 찾을 수 없다 | 모델 이름부터 시작하는 전체 경로여야 합니다 |
| 기대값이 마음대로 바뀌었다 | `ExpectedUpdateMode`가 비어 있으면 `APPLY`입니다. `OFF`로 내리십시오 |
| 실행은 끝났는데 판정이 빈 칸 | 결과 정리를 안 했거나, 정리 뒤 다시 돌렸습니다. `st_collect_per_cut_results` |
| 필터 사유가 없다고 중단 | `CoverageFilterRationale`을 채우십시오 |
| 같은 이름의 모델이 열려 있다 | 저장하고 닫으십시오. 확실하게는 MATLAB 재시작 |
| 검사 코드에 `0`이 있다 | `details` 표에서 그 CUT의 원인을 보고 3단계를 다시 |
| 경로가 너무 길다 | `st_set_standalone_coverage_root('D:\st_out')` |
| 재배치 스크립트가 종료 코드 `2` | 입력 폴더가 파이프라인 루트가 아니거나 출력 폴더가 이미 있습니다. `--overwrite` |
| 최종 문서가 저장하라고 한다 | 결과 정리가 모델을 미저장으로 남겼습니다. 저장 후 다시 |
| `Metadata`의 `ResultRunId`가 옛 실행이다 | 1단계 뒤 결과 정리를 다시 하고 최종 문서를 다시 만듭니다 |

오류 식별자별 대처는 [문제 해결](troubleshooting.md)에, 명령별 옵션은
[내부 표준 명령](team-commands.md)에 있습니다.
