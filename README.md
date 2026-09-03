# Simulink Test Automation Toolkit

Excel로 관리하는 CUT 정보를 바탕으로 Simulink Test Harness, 입력 Scenario,
Test Assessment, Test Manager Test Case를 구성하고 테스트 실행, 기대값 갱신,
Coverage 수집, 결과 보고서와 재실행 번들까지 만드는 MATLAB 자동화 도구입니다.

저장소: [Huelune/Simulink-Test-Automation-Toolkit](https://github.com/Huelune/Simulink-Test-Automation-Toolkit)

| 항목 | 현재 기준 |
| --- | --- |
| 버전 | `0.9.6` candidate 이후 `Unreleased` |
| 기본 브랜치 | `main` |
| 이 README의 작업 브랜치 | `feat/per-cut-filtered-execution` |
| 기본 기대값 정책 | `APPLY` |
| 기본 실행 정책 | `AUTO` |
| 현재 검증 상태 | 코드·정적 검토 단계, MATLAB R2025b 전체 인증 미완료 |

이 문서는 현재 작업 브랜치의 동작을 설명합니다. 아직 `main`에 병합되지 않은
기능을 기본 브랜치의 제공 기능으로 간주하지 않으며, 실제 MATLAB에서 실행하지
않은 항목을 검증 완료로 표시하지 않습니다.

## 1. 주요 기능

```text
TestManagement.xlsx
  → 모델과 CUT 경로 확인
  → Harness·SLDV·Signal Editor·Assessment 준비
  → Test Manager 구성
  → BATCH 또는 CUT별 격리 실행
  → 기대값 갱신과 재실행
  → Decision·Execution Coverage와 보고서 저장
  → 상태 검증 또는 재실행 번들 내보내기
```

| 영역 | 제공 기능 |
| --- | --- |
| 대상 관리 | Excel 행별 CUT, Harness, Test Case, SLDV, 기대값, CVF 정책 |
| 준비 자동화 | 누락 Harness 생성, Signal Editor Scenario, Assessment, Iteration 구성 |
| 증분 처리 | 대상·단계별 fingerprint와 checkpoint를 사용한 준비 결과 재사용 |
| 테스트 실행 | 모든 Test Case 일괄 실행 또는 Excel 순서의 CUT별 독립 실행 |
| 기대값 처리 | 실패 결과의 지원 가능한 실제값을 Assessment expected value에 반영 후 재실행 |
| Coverage | Decision과 Block Execution 수집, CUT별 transient CVF 적용·복원 |
| 보고서 | Excel, JSON manifest, MLDATX, HTML, 선택적 공식 PDF |
| 검증 | `QUICK`, `RUNTIME`, `CERTIFY` 프로필과 Excel·JSON·JUnit 결과 |
| 내보내기 | 선택 결과 자산 묶음과 원본을 보존하는 반복 실행 번들 |

## 2. 요구 환경과 입력 파일

### 2.1 제품

| 구성 요소 | 필요 범위 | 비고 |
| --- | --- | --- |
| MATLAB R2025b | 현재 검증 기준 | 실제 지원 릴리스 범위는 아직 확정하지 않음 |
| Simulink | 필수 | 모델과 Harness 처리 |
| Simulink Test | 필수 | Harness, Test Sequence, Test Manager |
| Simulink Coverage | Coverage·CVF·보고서 사용 시 필수 | Decision·Execution 수집과 `.cvf` 처리 |
| Simulink Design Verifier | `SldvMode=GENERATE`에서 필수 | `OFF`와 기존 파일을 쓰는 `FILE`은 새 SLDV 생성에 사용하지 않음 |

### 2.2 프로젝트 입력

- 대상 Top Model과 필요한 model dependency
- 저장소 루트의 `TestManagement.xlsx`
- 기존 Harness를 사용할 경우 Harness가 저장된 모델
- 기존 Test Manager 파일을 사용할 경우 `{TopModel}.mldatx`
- `SldvMode=FILE` 행에서 지정한 SLDV MAT 파일

실제 모델, 관리 Excel, MAT, MLDATX와 실행 결과는 업무 정보가 포함될 수 있으므로
Git에 추가하지 않습니다.

## 3. 가장 빠른 시작

MATLAB에서 저장소 루트를 Current Folder로 연 뒤 다음 순서로 실행합니다.

```matlab
st_setup
st_select_target_model
st_pre_validate_targets
st_run_from_harness
```

- `st_setup`: `src/`와 MATLAB 진단 명령을 path에 추가합니다.
- `st_select_target_model`: 대상 모델을 선택하고 `runtime_target.mat`에 로컬 선택을
  저장합니다. 이미 유효한 선택이 있으면 재사용합니다.
- `st_pre_validate_targets`: Excel의 활성 CUT 경로와 필수 설정을 실행 전에
  확인합니다.
- `st_run_from_harness`: 누락 Harness 생성부터 테스트와 보고서까지 전체 workflow를
  실행합니다.

Harness가 이미 모두 존재하면 생성 단계를 건너뛰는 진입점을 사용합니다.

```matlab
st_run_after_harness
```

모델 계층에서 CUT 경로를 준비하는 보조 명령은 다음과 같습니다.

```matlab
st_export_subsystem_paths          % 전체 Subsystem 경로를 Excel로 내보내기
st_fill_temp_paths_from_indent     % Excel indentation으로 빈 CUTPath 채우기
st_find_target_paths              % 같은 이름의 후보를 문맥으로 순위화해 선택
```

`st_find_target_paths`는 한 Subsystem을 여러 Excel 행에 중복 배정하지 않습니다.
기존 경로 중복 또는 해결하지 못한 행이 있으면 workbook을 부분 수정하지 않고
중단합니다.

## 4. 관리 Excel: `Targets` Sheet

기본 파일은 저장소 루트의 `TestManagement.xlsx`, Sheet 이름은 `Targets`입니다.
모든 활성 행은 동일한 Top Model을 사용하므로 `ModelName` 열을 추가하지 않습니다.

| 열 | 필수 | 기본값 | 설명 |
| --- | --- | --- | --- |
| `CUTName` | 예 | 없음 | 대상 Subsystem 이름 |
| `CUTPath` | 예 | 없음 | Top Model 아래의 전체 CUT 경로 |
| `HarnessName` | 예 | 없음 | 생성하거나 재사용할 Harness 이름 |
| `TestCaseName` | 예 | 없음 | Test Manager Test Case 이름 |
| `No` | 아니요 | Excel 순서 | 결과 폴더와 manifest 식별 번호 |
| `Enabled` | 아니요 | `true` | `cfg.OnlyEnabled=true`일 때 대상 선택 |
| `SldvMode` | 아니요 | `OFF` | `OFF`, `FILE`, `GENERATE` |
| `SldvDataFile` | 조건부 | 빈 값 | `FILE`에서 필수인 절대 또는 workbook 상대 경로 |
| `ExpectedUpdateMode` | 아니요 | `DEFAULT` | `DEFAULT`, `OFF`, `APPLY` |
| `CoverageFilterMode` | 아니요 | `OFF` | `OFF`, `SUBSYSTEM`, `ALL_CONTENT` |
| `CoverageFilterAction` | 조건부 | 빈 값 | CVF 사용 시 `EXCLUDE` 또는 `JUSTIFY` |
| `CoverageFilterRationale` | 조건부 | 빈 값 | CVF 사용 시 필수 근거 |
| `PreparationMode` | 아니요 | `DEFAULT` | `DEFAULT`, `AUTO`, `FORCE` |
| `PreparationFromStage` | 아니요 | `DEFAULT` | `FORCE`가 시작할 준비 단계 |

`CUTName`과 `CUTPath`는 실제 블록 이름의 공백을 보존합니다. `HarnessName`과
`TestCaseName`은 식별자이므로 앞뒤 공백을 제거합니다.

## 5. Workflow와 실행 모드

### 5.1 공개 진입점

| 명령 | 용도 |
| --- | --- |
| `st_run_from_harness` | Harness가 없을 수 있는 전체 workflow |
| `st_run_after_harness` | 기존 Harness를 검증한 뒤 SLDV 단계부터 실행 |
| `st_run_tests_per_cut` | 이미 준비된 Test File을 CUT별로 직접 실행 |

두 workflow 진입점은 다음 네 개의 결과를 반환할 수 있습니다.

```matlab
[resultObj, updateResult, workflowResult, reportInfo] = ...
    st_run_from_harness();
```

`PER_CUT`에서 `resultObj`는 CUT별 `InitialResult`, `FinalResult`를 가진 struct
배열입니다. `BATCH`에서는 기존 단일 최종 ResultSet 동작을 유지합니다.

### 5.2 기본 `AUTO` 정책

| `ExecutionMode` | 동작 |
| --- | --- |
| `AUTO` | 활성 CVF 행이 하나라도 있으면 모든 활성 CUT을 `PER_CUT`, 전부 `OFF`이면 `BATCH` |
| `BATCH` | 모든 활성 Test Case를 기존 `run(tf)`로 실행. 활성 CVF가 있으면 실행 전에 오류 |
| `PER_CUT` | CVF가 `OFF`인 행까지 포함해 모든 활성 CUT을 Excel 순서로 개별 실행·보고 |

일반적으로 `AUTO`를 유지하면 됩니다. CUT별 결과를 항상 분리하려면 다음처럼
명시합니다.

```matlab
[results, updates, workflow, report] = st_run_from_harness( ...
    'ExecutionMode', 'PER_CUT', ...
    'ContinueOnFailure', true, ...
    'ReportMode', 'SUMMARY', ...
    'FailOnNonPass', true);
```

준비가 끝난 Test File만 직접 실행할 수도 있습니다.

```matlab
[results, updates, summary] = st_run_tests_per_cut( ...
    'ContinueOnFailure', true, ...
    'ReportMode', 'SUMMARY', ...
    'FailOnNonPass', true);
```

| 옵션 | 기본값 | 설명 |
| --- | --- | --- |
| `ContinueOnFailure` | `true` | 테스트·보고서 실패 후 필터 복원이 확인되면 다음 CUT 진행 |
| `ReportMode` | `SUMMARY` | `SUMMARY` 또는 `FULL` |
| `FailOnNonPass` | `true` | 안전하게 처리 가능한 CUT을 모두 기록한 뒤 최종 실패가 있으면 오류 |

필터 복원 또는 복원 검증에 실패하면 설정 누출 위험이 있으므로
`ContinueOnFailure=true`여도 전체 실행을 즉시 중단합니다. 병렬 CUT 실행은
지원하지 않습니다.

### 5.3 설정 우선순위

옵션 종류마다 적용 범위가 다릅니다.

| 정책 | 우선순위 |
| --- | --- |
| 실행 모드 | workflow 호출의 `ExecutionMode` > `cfg.ExecutionMode` |
| 준비 모드와 시작 단계 | 호출 옵션 > Excel 행 > `st_config` |
| 기대값 갱신 | Excel 행 > `cfg.ExpectedUpdateMode` |
| CVF 선택 | Excel 행의 `CoverageFilter*` 값 |

`ExecutionMode=AUTO`는 Excel 행의 CVF 설정을 읽어 BATCH/PER_CUT을 결정하지만,
Excel에 행별 `ExecutionMode` 열을 두지는 않습니다.

## 6. 증분 준비와 단계 재실행

기본 준비 모드는 `AUTO`입니다. Excel 행, 설정, 모델, Test File, SLDV 입력과
자동화 코드의 fingerprint가 이전 성공 checkpoint와 같으면 해당 준비 단계를
재사용합니다.

```matlab
cfg.PreparationMode = 'AUTO';
cfg.PreparationFromStage = 'START';
```

상태는 다음 두 파일에 저장됩니다.

```text
result/state/workflow_state.mat
result/state/workflow_state.json
```

특정 단계부터 다시 적용하려면 호출 옵션을 사용합니다.

```matlab
st_run_from_harness( ...
    'PreparationMode', 'FORCE', ...
    'FromStage', 'SLDV');
```

지원 단계는 `START`, `HARNESS`, `SLDV`, `HARNESS_CONFIG`, `SIGNAL_EDITOR`,
`ASSESSMENT`, `COVERAGE_FILTER`, `TEST_MANAGER`, `ALIGNMENT`입니다. 준비 단계가
모두 캐시되어도 `cfg.RunGeneratedTests=true`이면 테스트는 매번 실행합니다.

성공한 대상은 즉시 checkpoint합니다. 준비 중 한 대상이 실패하면 가능한 다른
대상의 준비 결과는 남기지만, 일관되지 않은 Test File 실행은 시작하지 않습니다.

## 7. 대상 준비 동작

### 7.1 Harness와 Test Manager

- 기존 Harness는 삭제하지 않고, 없는 Harness만 생성합니다.
- Harness 생성은 compile을 포함하므로 수 분 이상 걸릴 수 있습니다.
- 기본 Test Manager 정책은 `cfg.OverwriteTestFile=false`인 증분 갱신입니다.
- 기존 Test File과 Test Case를 보존하고 없는 Test Case만 추가합니다.
- SLDV 행은 대상 Test Case의 Iteration만 Scenario 수에 맞게 다시 구성합니다.
- 다른 열린 Test Manager 파일은 전역으로 제거하지 않습니다.

### 7.2 SLDV

| `SldvMode` | 동작 |
| --- | --- |
| `OFF` | 기존 단일 `UT_REQ_{CUTName}_001` Scenario 사용 |
| `FILE` | 지정된 `sldvData` MAT를 검증하고 Dataset Scenario로 변환 |
| `GENERATE` | Top Model의 Design Verifier 설정을 복사해 CUT용 테스트 생성 |

`FILE`과 `GENERATE` 대상은 Atomic Subsystem이어야 합니다. 기본
`cfg.AutoConvertSldvTargetsToAtomic=true`는 비-Atomic CUT을
`TreatAsAtomicUnit=on`으로 변경하며, 이 모델 변경은 유지됩니다. 자동 변경을
원하지 않으면 설정을 `false`로 바꾸고 모델을 미리 준비해야 합니다.

각 CUT의 최장 SLDV 종료 시각을 `Tmax`로 사용합니다. 기본적으로 0.01초 격자에
올림하여 Harness StopTime, Assessment transition, expected-value sampling에
동일하게 적용합니다.

공유 Signal Editor MAT 전체 검사는 비용 때문에 기본
`cfg.CheckSharedSignalEditorDataFile=false`입니다. 여러 Harness가 같은 MAT를
공유할 가능성이 있으면 인증 전에 `true`로 설정하십시오.

### 7.3 Signal Editor와 Assessment

- direct CUT Inport가 없는 `OFF` 대상은 Signal Editor 설정을 건너뛰지만
  Assessment와 Test Sequence Scenario는 계속 구성합니다.
- SLDV 대상은 direct Inport 유무와 관계없이 Scenario와 Iteration을 일대일로
  연결합니다.
- Assessment는 실제 Input symbol의 Port 순서에서 Signal Editor 입력 수를
  건너뛴 뒤 Harness Outport와 위치로 연결합니다.
- 이름에서 `/`를 제거하거나 임의로 정규화해 signal을 추측하지 않습니다.
- scalar, numeric array, Bus, nested Bus Assessment를 지원합니다. Bus array는
  기본적으로 첫 Bus instance만 검증합니다.

상세한 Scenario와 Assessment 매핑 규칙은
[운영자 매뉴얼](docs/operator-manual.md)을 참조하십시오.

## 8. 기대값 갱신

기본값은 다음과 같습니다.

```matlab
cfg.ExpectedUpdateMode = 'APPLY';
cfg.ExpectedValueSampleTime = 0.01;
cfg.RerunAfterExpectedUpdate = true;
```

| Excel 값 | 실제 동작 |
| --- | --- |
| 빈 값 또는 `DEFAULT` | 전역 기본값 `APPLY` 사용 |
| `OFF` | 실패해도 expected value를 변경하지 않음 |
| `APPLY` | 지원 가능한 실패 결과를 실제 출력값으로 갱신 |

`APPLY`는 Failed Iteration만 처리하고 실제값과 RHS가 다를 때만 Assessment의
`verify(... == RHS)`를 수정합니다. 현재 자동 갱신 값은 real numeric scalar와
logical scalar입니다. array와 Bus Assessment 생성 지원이 array·Bus 기대값의
자동 갱신까지 의미하지는 않습니다.

하나 이상의 값이 바뀌고 `cfg.RerunAfterExpectedUpdate=true`이면 동일 범위를
다시 실행합니다. `PER_CUT`에서는 같은 CVF를 유지한 채 해당 Test Case만
재실행한 뒤 필터를 복원합니다. 후보 검토 후 승인하는 `REVIEW` 모드는 아직
지원하지 않습니다.

## 9. CUT별 CVF 격리와 Coverage

Test File Coverage는 Decision으로 설정하며, 이에 포함되는 Block Execution을
함께 수집합니다.

```matlab
cfg.CoverageStructuralLevel = 'Decision';
cfg.CoverageMetricSettings = 'dwe';
cfg.CoverageFilterApplicationMode = 'RUNTIME';
```

| Excel 설정 | 의미 |
| --- | --- |
| `CoverageFilterMode=OFF` | 자동 CVF를 만들지 않음 |
| `SUBSYSTEM` | `CUTPath`의 Subsystem 블록 자체를 필터 대상으로 선택 |
| `ALL_CONTENT` | `CUTPath`의 Subsystem과 그 내부 전체를 필터 대상으로 선택 |
| `CoverageFilterAction=EXCLUDE` | 대상 outcome을 Coverage에서 제외 |
| `CoverageFilterAction=JUSTIFY` | 대상 outcome을 justified로 기록 |

CVF를 사용할 때는 `CoverageFilterRationale`이 필수입니다. CVF는 저장 직후 다시
열어 규칙 수와 action을 검증하며, 올바르게 열리지 않으면 해당 CUT을 `FAIL`로
기록합니다. 필터 설정이 안전한 상태이면 다음 CUT은 계속 처리합니다.

`PER_CUT`의 안전 순서는 다음과 같습니다.

```text
CVF 생성
→ Test File·Suite·Test Case 기존 필터 목록 백업
→ 현재 Test Case에 수동 필터와 실행 전용 CVF 결합
→ 초기 run(testCase)와 결과 저장
→ APPLY 변경 시 같은 CVF로 재실행과 최종 결과 저장
→ 원래 필터 복원
→ 실제 설정 재조회·일치 확인
→ 다음 CUT
```

다른 Test Case의 Enabled 상태는 변경하지 않습니다. 기존 수동 필터는 보존하며,
자동 CVF는 실행별 CUT 폴더에 따로 저장합니다. `PER_CUT`은 항상 transient
필터를 사용하므로 `CoverageFilterApplicationMode=PERSIST`를 거부합니다.

Coverage 분모가 0이면 `N/A`, justified outcome은 별도 수치로 기록합니다.
다른 checksum의 Coverage를 하나의 합계로 섞지 않으며, Coverage 미달 자체는
테스트 실패로 바꾸지 않습니다.

## 10. 실행 결과와 보고서

### 10.1 BATCH 통합 보고서

모든 활성 행이 CVF `OFF`인 `AUTO` 또는 명시적 `BATCH` 실행은 기존 통합 결과
경로를 사용합니다.

```text
result/runs/{timestamp}_{run-id}/
├── TestSummary.xlsx
├── manifest.json
├── official/
│   ├── InitialTestResults.pdf
│   └── FinalTestResults.pdf
├── coverage/
│   └── {coverage-root}.html
└── raw/
    ├── InitialResults.mldatx
    └── FinalResults.mldatx
```

`TestSummary.xlsx`는 `Overview`, `Targets`, `Iterations`, `Coverage`,
`CoverageFilters`, `ExpectedUpdates`, `Workflow`, `Metadata` Sheet를 포함합니다.
`result/latest.json`과 `result/TestSummary.xlsx`가 최신 통합 실행을 가리킵니다.

### 10.2 PER_CUT 개별 보고서

```text
result/per_cut_runs/{run-id}/
├── TestSummary.xlsx
├── manifest.json
├── targets/
│   └── {No}_{CUTName}_{hash}/
│       ├── target-manifest.json
│       ├── filter/
│       │   └── {TestCaseName}.cvf
│       ├── initial/
│       │   ├── TestSummary.xlsx
│       │   ├── raw/InitialResults.mldatx
│       │   ├── coverage/CoverageSummary.html
│       │   └── official/InitialTestResults.pdf
│       └── final/
│           ├── TestSummary.xlsx
│           ├── raw/FinalResults.mldatx
│           ├── coverage/CoverageSummary.html
│           └── official/FinalTestResults.pdf
└── logs/execution.log
```

- `SUMMARY`: Excel, MLDATX, 경량 Coverage HTML을 생성합니다.
- `FULL`: `SUMMARY` 산출물에 공식 PDF와 전체 Coverage HTML을 추가합니다.
- `final/`은 기대값 변경 후 실제 재실행한 경우에만 생성됩니다.
- `filter/{TestCaseName}.cvf`는 CVF 활성 CUT에만 생성됩니다. Test Case 실행 전에
  해당 폴더를 MATLAB path에 등록하고 ResultSet coverage에도 절대 경로로 연결합니다.
- root Excel은 모든 CUT의 최종 상태와 초기·최종 결과 연결을 인덱싱합니다.
- target manifest는 CVF SHA-256, action, rationale, 적용·복원 상태를 기록합니다.

`result/per_cut_latest.json`은 최신 CUT별 실행만 가리킵니다. 이 경로는 기존
`result/latest.json`과 `result/runs/`를 변경하지 않습니다. 보고서는 로컬
내부용이며 Notion이나 외부 저장소로 자동 전송하지 않습니다.

## 11. 전체 기능 상태 검증

기본 상태 점검은 원본을 저장하거나 시뮬레이션하지 않는 `QUICK + CURRENT`입니다.

```matlab
summary = st_verify_all( ...
    'Profile', 'QUICK', ...
    'Target', 'CURRENT', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', true);
```

| `Profile` | 범위 |
| --- | --- |
| `QUICK` | 단위 테스트, 환경·설정·저장 상태·산출물 무결성. 시뮬레이션 없음 |
| `RUNTIME` | QUICK에 더해 실제 업무 모델의 격리 사본에서 기존 Test File 실행 |
| `CERTIFY` | 자동 fixture 전체 workflow, 캐시·복구·보고서·내보내기·재실행 인증 |

| `Target` | 범위 |
| --- | --- |
| `CURRENT` | `runtime_target.mat`이 가리키는 업무 모델 |
| `FIXTURE` | 실행별로 자동 생성하는 익명 검증 모델 |
| `BOTH` | 업무 모델과 fixture 모두 |

전체 상태는 `FAIL > BLOCKED > PASS_WITH_WARNINGS > PASS` 순으로 집계합니다.
필수 제품, 라이선스, 입력 또는 수동 증거가 없으면 `BLOCKED`, 적용되지 않는
검사는 `SKIP`, Coverage 미달 같은 비차단 항목은 `WARN`입니다.

```text
result/verification/
├── latest.json
└── runs/{timestamp}_{run-id}/
    ├── VerificationSummary.xlsx
    ├── verification.json
    ├── junit.xml
    ├── environment.json
    ├── manifest.json
    ├── logs/
    ├── evidence/
    └── workspace/
```

상세 실행 순서, 수동 증거 작성과 결과 해석은
[종합 검증 사용자 매뉴얼](docs/user-manual.md)과
[검증 기술 문서](docs/verification.md)를 참조하십시오.

## 12. 테스트 자산과 재실행 번들 내보내기

두 내보내기 기능의 목적은 다릅니다.

| 명령 | 목적 | 기본 출력 |
| --- | --- | --- |
| `st_export_test_asset_bundle` | 선택한 결과, Test Case, standalone Harness, 입력과 보고서 보관 | `result/exports/assets/` |
| `st_export_test_bundle` | 다른 PC에서 같은 시작 상태로 반복 실행할 self-contained template | `result/exports/`와 ZIP |

현재 Test Manager 결과나 저장된 toolkit run을 선택해 자산을 모으려면:

```matlab
info = st_export_test_asset_bundle('SelectResult', true);
```

기본 `CoverageReportMode=SUMMARY`는 Coverage를 넣지 않은 공식 PDF와 경량
Coverage HTML을 만들고 전체 Coverage 원본을 MLDATX에 보존합니다. `FULL`은
공식 PDF에 Coverage를 포함하고 상세 `cvhtml` 보고서를 추가합니다.

```matlab
info = st_export_test_asset_bundle( ...
    'SelectResult', true, ...
    'CoverageReportMode', 'FULL', ...
    'CreateArchive', true);
```

완전한 반복 실행 번들은 다음 명령으로 만듭니다.

```matlab
info = st_export_test_bundle;
```

내보내기는 원본 모델과 Test File을 수정하지 않습니다. 받은 사람은 번들의
`run_exported_tests`를 실행할 때마다 immutable `template/`에서 새로운
`executions/` 작업 사본을 만듭니다. 따라서 원본 프로젝트와 내보낸 template을
보존한 채 여러 번 다시 테스트할 수 있습니다.

저장하지 않은 모델·Test File 변경이나 누락 dependency가 있으면 재현 가능한
번들을 만들지 않고 중단합니다. 수집 범위와 제한은
[내보내기 설계 문서](docs/export-bundle.md)를 참조하십시오.

## 13. 운영, 로그와 결과 정리

### 13.1 생성 결과 정리

정리 명령은 기본적으로 dry-run입니다.

```matlab
plan = st_cleanup_results('Scope', 'PER_CUT_RUNS');
plan = st_cleanup_results('Scope', 'PER_CUT_RUNS', 'Apply', true);
```

지원 범위는 `REPORTS`, `SLDV`, `STATE`, `RUNS`, `PER_CUT_RUNS`, `EXPORTS`,
`VERIFICATION`, `FILTERS`, `ALL`입니다. 알려진 `result/` 하위 산출물만 대상으로
하며 모델, Excel, runtime target, Test File과 사용자 SLDV 입력은 선택하지
않습니다.

### 13.2 진행 로그

```matlab
cfg.VerboseLogging = true;
```

장시간 MATLAB API 호출 전후에 timestamp, 단계, 대상과 경과 시간을 출력합니다.
blocking API 내부의 실제 percentage는 알 수 없으므로 마지막 `START` 로그가 현재
대기 위치입니다. PER_CUT의 상세 순서는 각 run의 `logs/execution.log`에서
확인합니다.

### 13.3 Excel 접근 진단

관리 환경에서 workbook 접근이 실패하면 원본을 바꾸지 않는 진단을 실행합니다.

```matlab
st_diagnose_excel_access
st_diagnose_excel_access(true)   % disposable workbook 쓰기까지 확인
```

결과는 `result/ExcelAccessDiagnostic.json`에 저장됩니다.

## 14. 저장소 구조와 문서

| 경로 | 역할 |
| --- | --- |
| `st_setup.m` | 프로젝트 bootstrap |
| `src/config/` | 전역 설정과 정책 정규화 |
| `src/workflow/` | 전체·기존 Harness workflow와 증분 계획 |
| `src/targets/` | Excel 로드, 모델 선택, CUT 경로 검증 |
| `src/harness/`, `src/signal_editor/` | Harness와 입력 Scenario 구성 |
| `src/sldv/`, `src/assessment/` | SLDV 준비와 Assessment 생성 |
| `src/test_manager/`, `src/execution/` | Test Case 구성과 BATCH/PER_CUT 실행 |
| `src/coverage/`, `src/reporting/` | CVF 세션, Coverage와 보고서 |
| `src/exporting/` | 자산 및 재실행 번들 내보내기 |
| `src/verification/` | QUICK/RUNTIME/CERTIFY 검증 |
| `src/maintenance/` | 안전한 결과 정리 |
| `diagnostics/` | MATLAB·Python 읽기/접근 진단 |
| `tests/unit/`, `tests/fixtures/` | 단위 테스트와 실행 시 생성 fixture |
| `docs/` | 운영, 검증, 구조, TODO, 인수인계 문서 |

| 문서 | 사용할 때 |
| --- | --- |
| [운영자 매뉴얼](docs/operator-manual.md) | 명령별 전제조건, 부작용, 결과와 복구 방법 확인 |
| [종합 검증 사용자 매뉴얼](docs/user-manual.md) | QUICK부터 CERTIFY까지 단계별 실행 |
| [검증 기술 문서](docs/verification.md) | 검사 catalog, 상태와 결과 schema 확인 |
| [내보내기 설계 문서](docs/export-bundle.md) | 번들 구조, checksum과 재현성 범위 확인 |
| [저장소 아키텍처](docs/architecture.md) | 모듈 책임과 향후 `+simtest` 이전 방향 확인 |
| [TODO](docs/TODO.md) | 아직 결정·검증되지 않은 작업 확인 |
| [다른 PC에서 이어서 작업하기](docs/cross-machine-handoff.md) | 원격 브랜치와 R2025b 인수인계 절차 확인 |

기존 공개 `st_*` 함수명은 호환성을 위해 유지합니다. 향후 `src/+simtest`
package 이전 범위와 호환 기간은 아직 결정되지 않았습니다.

## 15. Git 산출물 정책

| 종류 | Git 정책 | 이유 |
| --- | --- | --- |
| MATLAB 소스, 테스트, 문서 | 추적 | 제품과 검증 코드 |
| 익명화된 예제 | 정책 확정 후 `examples/`에서 추적 | 재현 가능한 onboarding |
| 실제 `TestManagement.xlsx`, MAT, MLDATX | 제외 | 모델 경로와 업무 데이터 포함 가능 |
| `runtime_target.mat` | 제외 | PC별 로컬 모델 선택 |
| `result/`, `slprj/`, 코드 생성물 | 제외 | 실행마다 재생성되는 산출물 |
| 승인 baseline/test artifact | 보관 정책 확정 전 제외 | 승인·검토 절차 미결정 |

자동 생성 보고서는 로컬 파일이며 외부 시스템에 자동 게시하지 않습니다.
공유 전에는 모델 경로, CUT 이름과 진단 오류의 민감정보를 검토해야 합니다.

## 16. 현재 검증 상태와 남은 작업

현재 브랜치에는 증분 준비, 통합 보고서, 내보내기, 종합 검증 프레임워크와
CUT별 CVF 격리 실행 구현 및 단위 테스트 코드가 포함되어 있습니다. 그러나
현재 개발 환경에서 MATLAB을 실행할 수 없으므로 다음 항목은 실제 R2025b
결과가 확보되기 전까지 미검증입니다.

- `SUBSYSTEM+JUSTIFY`, `ALL_CONTENT+EXCLUDE`, `OFF` CUT의 순차 실행
- `APPLY → RUN → EXPORT → RESTORE → NEXT` 실제 API 동작과 필터 무누출 확인
- 기대값 최초 실패, 갱신, 같은 CVF 재실행과 최종 PASS
- Test File·Suite·Test Case 수동 필터의 저장·재개방 후 동일성
- Decision·Execution CUT 매핑과 Excel·HTML·PDF·MLDATX 생성
- SLDV `FILE`/`GENERATE`, Scenario·Iteration과 정확한 `Tmax` timing
- `QUICK → RUNTIME → CERTIFY` 전체 인증과 재실행 번들 반복 실행

MATLAB R2025b 장비에서는 먼저 단위 테스트를 실행합니다.

```matlab
st_setup
results = runtests(fullfile(st_project_root(), 'tests', 'unit'));
```

그다음 [다른 PC에서 이어서 작업하기](docs/cross-machine-handoff.md)에 적힌
순서로 `QUICK + CURRENT`부터 `CERTIFY + BOTH`까지 진행하고 실행별 결과를
보존합니다. R2025b fixture 결과가 확보되기 전에는 이 기능을 인증 완료 또는
PR 준비 완료로 표시하지 않습니다.

추가로 결정해야 할 `REVIEW` 기대값 승인 흐름, baseline 보관 정책, 검증 재개와
실패 검사만 재실행, 보고서 redaction, CI 연결과 `+simtest` 구조 이전은
[TODO](docs/TODO.md)에 유지합니다.
