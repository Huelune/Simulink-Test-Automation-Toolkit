# Simulink Test Automation Toolkit 운영자 매뉴얼

이 문서는 MATLAB 사용자가 저장소를 처음 연 시점부터 모델 선택, CUT 경로
준비, Harness·SLDV·Test Case 생성, 테스트 실행, 검증, 번들 내보내기와 결과
정리까지 수행하는 순서를 설명합니다. 내부 helper가 아니라 사용자가 직접
호출하는 공개 `st_*` 명령을 중심으로 작성합니다.

실제로 실행하지 않은 단계는 완료된 것으로 판단하지 않습니다. 현재 기준
환경은 MATLAB R2025b이며 전체 runtime 인증 상태는 `docs/verification.md`를
따릅니다.

## 1. 가장 짧은 시작 순서

Harness가 없는 일반적인 최초 실행:

```matlab
st_setup
st_select_target_model
st_pre_validate_targets
st_run_from_harness
```

Harness가 이미 있는 실행:

```matlab
st_setup
st_select_target_model
st_validate_targets
st_run_after_harness
```

기존 SLDV MAT를 사용해 Test Case까지만 만들고 테스트를 실행하지 않는 경우:

1. `Targets.SldvMode`를 `FILE`로 설정합니다.
2. `Targets.SldvDataFile`에 `TestManagement.xlsx` 기준 상대경로 또는 절대경로를
   입력합니다.
3. `st_config.m`에서 `cfg.RunGeneratedTests = false`로 설정합니다.
4. 기존 Harness가 있으므로 다음을 실행합니다.

```matlab
st_setup
st_select_target_model
st_run_after_harness
```

## 2. 실행 전 필수 확인

### 2.1 제품

| 제품 | 필요한 경우 |
| --- | --- |
| MATLAB R2025b | 모든 기능 |
| Simulink | 모든 모델 작업 |
| Simulink Test | Harness, Test Manager, Test 실행 |
| Simulink Coverage | 통합 Coverage와 종합 검증 |
| Simulink Design Verifier | `SldvMode=GENERATE`; `FILE`은 기존 결과 사용 |

### 2.2 사용자 입력 파일

| 파일 | Git 관리 | 설명 |
| --- | --- | --- |
| Top Model 및 dependency | 보통 외부 | 테스트 대상 모델 |
| `TestManagement.xlsx` | 실제 업무 파일은 제외 | `Targets` 시트 관리 입력 |
| `runtime_target.mat` | 제외 | `st_select_target_model`이 생성 |
| `*_sldvdata.mat` | 제외 | `SldvMode=FILE` 입력 |
| `{TopModel}.mldatx` | 제외 | 생성 또는 증분 갱신되는 Test File |

모델, dependency, Test File과 Excel은 runtime 검증이나 번들 내보내기 전에
저장합니다.

### 2.3 변경 가능 범위

| 분류 | 예시 | 변경 여부 |
| --- | --- | --- |
| 읽기 전용 | `st_pre_validate_targets`, QUICK 검증, 진단 명령 | 원본 모델을 의도적으로 저장하지 않음 |
| 준비 변경 | Harness, Signal Editor, Assessment, Test Manager 구성 | 모델/Harness/Test File 변경 가능 |
| 실행 변경 | expected-value `APPLY` | Assessment 기대값 변경 가능 |
| 생성물 | `result/` 아래 report, state, SLDV, run, export, verification | 다시 생성 가능 |
| 정리 | `st_cleanup_results` | `Apply=true`일 때 선택한 생성물 삭제 |

## 3. 관리 Excel 핵심

`TestManagement.xlsx`의 `Targets` 시트에는 다음 열을 사용합니다.

| 열 | 필수 | 대표 값 |
| --- | --- | --- |
| `CUTName` | 예 | `Controller` |
| `CUTPath` | 예 | `TopModel/Controller` |
| `HarnessName` | 예 | `Controller_Harness` |
| `TestCaseName` | 예 | `TC_Controller` |
| `No` | 아니요 | `1` |
| `Enabled` | 아니요 | `TRUE` |
| `SldvMode` | 아니요 | `OFF`, `FILE`, `GENERATE` |
| `SldvDataFile` | `FILE`에서 필수 | `sldv_data/Controller_sldvdata.mat` |
| `ExpectedUpdateMode` | 아니요 | `DEFAULT`, `OFF`, `APPLY` |
| `PreparationMode` | 아니요 | `DEFAULT`, `AUTO`, `FORCE` |
| `PreparationFromStage` | 아니요 | `DEFAULT`, `SLDV`, `ASSESSMENT` 등 |

`SldvDataFile` 상대경로는 MATLAB Current Folder가 아니라
`TestManagement.xlsx`가 있는 폴더를 기준으로 해석합니다.

## 4. 초기화와 설정

### 4.1 `st_setup`

목적:

- 저장소 루트와 `src/` 전체를 MATLAB path에 추가합니다.
- `diagnostics/matlab/`을 path에 추가합니다.
- 없으면 `result/` 폴더를 만듭니다.

사용:

```matlab
st_setup
```

MATLAB을 새로 시작했거나 저장소 위치를 바꾼 뒤 가장 먼저 실행합니다.

### 4.2 `st_config`

`st_config`는 직접 실행하는 workflow가 아니라 전체 기본 설정을 반환합니다.
일반적으로 `src/config/st_config.m`을 검토하고 필요한 기본값만 수정합니다.

자주 확인하는 값:

```matlab
cfg = st_config();
cfg.RunGeneratedTests
cfg.OverwriteTestFile
cfg.ExpectedUpdateMode
cfg.PreparationMode
cfg.CheckSharedSignalEditorDataFile
cfg.SaveResultFiles
```

안전한 TC 생성 전용 설정 예시:

```matlab
cfg.RunGeneratedTests = false;
cfg.OverwriteTestFile = false;
cfg.ExpectedUpdateMode = 'OFF';
```

실제 기본값은 파일을 수정해야 변경됩니다. Command Window에서 반환된 `cfg`만
수정해도 다음 공개 명령의 새 `st_config()` 호출에는 반영되지 않습니다.

## 5. 모델 선택과 CUT 경로 준비

### 5.1 `st_select_target_model`

목적:

- 설정된 검색 루트에서 SLX/MDL을 찾습니다.
- 사용자가 Top Model을 선택하게 합니다.
- 선택 결과를 `runtime_target.mat`에 저장합니다.

사용:

```matlab
cfg = st_select_target_model();
```

모델을 다시 선택하려면:

```matlab
cfg = st_select_target_model(true);
```

생성물: 저장소 루트의 `runtime_target.mat`.

### 5.2 `st_find_target_paths`

목적:

- `CUTName`과 같은 이름의 Subsystem 후보를 모델에서 찾습니다.
- 주변에 이미 확정된 CUT와 Excel 행 문맥을 이용해 후보 순위를 계산합니다.
- 선택한 경로를 `Targets.CUTPath`에 기록합니다.

사용:

```matlab
R = st_find_target_paths();
```

Excel을 변경하는 명령이므로 실행 전 workbook 백업과 저장 상태를 확인합니다.

### 5.3 `st_export_subsystem_paths`

목적:

- 선택 모델에서 발견 가능한 Subsystem 경로 전체를 Excel의
  `ModelSubsystems` 시트로 내보냅니다.
- 사람이 확인해 `Targets.CUTPath`로 복사할 때 사용합니다.

사용:

```matlab
R = st_export_subsystem_paths();
```

모델을 강제로 다시 선택하면서 실행:

```matlab
R = st_export_subsystem_paths(true);
```

### 5.4 `st_fill_temp_paths_from_indent`

목적:

- Excel 셀의 native indentation을 계층으로 해석해 빈 `CUTPath`를 채웁니다.
- 기본값은 기존 수동 경로를 보존합니다.

사용:

```matlab
R = st_fill_temp_paths_from_indent();
```

기존 경로도 덮어쓰려면:

```matlab
R = st_fill_temp_paths_from_indent(true);
```

`st_fill_temp_paths_from_depth`는 이전 호출과의 호환 wrapper입니다. 새 작업은
indent 기반 명령을 사용합니다.

## 6. 실행 전 검증

### 6.1 `st_pre_validate_targets`

Harness 생성 전 다음을 확인합니다.

- `CUTPath`가 비어 있지 않음
- 선택한 Top Model 기준 경로 정규화 가능
- 블록 존재
- 블록이 Subsystem임

사용:

```matlab
R = st_pre_validate_targets();
```

결과: `result/reports/PreValidationResult.ini`.

### 6.2 `st_validate_targets`

기존 Harness workflow 전에 CUT와 Harness 연결을 확인합니다. 컴파일은 하지
않습니다.

```matlab
R = st_validate_targets();
```

결과: `result/reports/ValidationResult.ini`.

## 7. 권장 workflow 진입점

### 7.1 `st_run_from_harness`

Harness가 없을 수 있는 전체 workflow입니다.

```matlab
[resultObj, updateResult, workflowResult, reportInfo] = ...
    st_run_from_harness();
```

순서:

```text
CUT 사전 검증
→ Harness 생성
→ SLDV 준비
→ Harness 설정
→ Signal Editor
→ Assessment
→ Test Manager
→ Scenario 정렬 검증
→ 선택적 Test 실행
→ 선택적 통합 보고서
```

강제로 특정 단계부터 재적용하려면:

```matlab
st_run_from_harness( ...
    'PreparationMode', 'FORCE', ...
    'FromStage', 'SLDV');
```

### 7.2 `st_run_after_harness`

대상 Harness가 이미 존재할 때 사용합니다. Harness 생성 대신 기존 매핑을
검증하고 SLDV 단계부터 진행합니다.

```matlab
[resultObj, updateResult, workflowResult, reportInfo] = ...
    st_run_after_harness();
```

기존 SLDV MAT에서 TC까지만 만들 때는 `cfg.RunGeneratedTests=false`와 함께 이
명령을 사용합니다.

### 7.3 증분 실행

기본 `AUTO`는 `result/state`의 성공 checkpoint와 현재 입력 fingerprint가
같으면 준비 단계를 재사용합니다.

문제 분석이나 재생성이 필요하면 한 번의 호출에서 `FORCE`를 지정합니다.

```matlab
st_run_after_harness( ...
    'PreparationMode', 'FORCE', ...
    'FromStage', 'SLDV');
```

오래된 checkpoint만 제거하려면 전체 결과 대신 다음 정리 명령을 사용합니다.

```matlab
st_cleanup_results('Scope', 'STATE', 'Apply', true);
```

## 8. 고급 단계별 명령

정상 운영은 두 workflow 진입점을 권장합니다. 다음 명령은 단계별 진단이나
부분 재현이 필요한 경우에만 직접 호출합니다.

| 명령 | 역할 | 주요 결과 |
| --- | --- | --- |
| `st_create_harnesses` | 누락 Harness 생성 | `HarnessCreateResult.ini` |
| `st_prepare_sldv_targets` | OFF/FILE/GENERATE 준비와 manifest 생성 | `SldvGenerationResult.ini`, `SldvScenarioResult.ini` |
| `st_configure_harnesses` | StopTime 등 Harness 설정 | `HarnessConfigResult.ini` |
| `st_configure_signal_editors` | Scenario MAT 생성·연결 | `SignalEditorResult.ini` |
| `st_configure_assessments` | Test Assessment Scenario/verify 구성 | `AssessmentResult.ini` |
| `st_create_test_manager` | Test File, TC, Iteration 구성 | `TestManagerResult.ini` |
| `st_validate_scenario_alignment` | Scenario와 Iteration 정렬 확인 | `ScenarioAlignmentResult.ini` |
| `st_run_generated_tests` | 선택된 Test Case 실행과 기대값 정책 적용 | Test Manager 결과 및 실행 보고서 입력 |

단계별 명령을 임의 순서로 호출하면 SLDV manifest나 이전 단계 산출물이 없어
실패할 수 있습니다.

## 9. SLDV 운용

### 9.1 `OFF`

SLDV 없이 기존 단일 Scenario를 사용합니다.

### 9.2 `FILE`

기존 `*_sldvdata.mat`을 검증하고 사용합니다.

```text
SldvMode=FILE
SldvDataFile=sldv_data/Controller_sldvdata.mat
```

MAT는 일반 Signal Editor MAT가 아니라 Design Verifier가 생성한 `sldvData`
구조체 파일이어야 합니다. 자동화가 Dataset Scenario로 변환합니다.

`FILE`과 `GENERATE` 대상은 모두 Atomic Subsystem이어야 합니다. 기본 설정인
`cfg.AutoConvertSldvTargetsToAtomic=true`에서는 `TreatAsAtomicUnit=off`인 CUT을
SLDV 준비 전에 `on`으로 바꾸고 되돌리지 않습니다. 전체 workflow를 실행하면
뒤의 Harness 구성 단계가 모델을 저장합니다. `st_prepare_sldv_targets`만 단독으로
호출했다면 모델이 Dirty 상태로 남으므로 검토 후 직접 저장해야 합니다.
자동 변경을 금지하려면 이 설정을 `false`로 바꾸며, 이 경우 비-Atomic CUT은
명확한 오류로 중단됩니다. 처리 결과는 `SldvGenerationResult`의
`AtomicAction` 열에서 확인합니다.

### 9.3 `GENERATE`

Top Model의 현재 Design Verifier 설정을 복사해 CUT에 TestGeneration을
실행합니다. 성공한 데이터는 다음에 저장합니다.

```text
result/sldv/{No}_{CUTName}/latest_sldvdata.mat
```

### 9.4 공유 MAT 검사

기본값:

```matlab
cfg.CheckSharedSignalEditorDataFile = false;
```

따라서 SLDV 준비 시 모든 Harness를 열고 닫는 공유 검사를 생략합니다. 실제로
여러 Harness가 같은 Signal Editor MAT를 사용할 가능성이 있으면 `true`로
바꿉니다. 공유 상태에서 검사를 끄면 `_sldv.mat` Scenario가 충돌할 수 있습니다.

## 10. 테스트 실행과 expected-value 정책

`cfg.RunGeneratedTests=false`이면 준비와 Test Manager 구성까지만 수행합니다.

`ExpectedUpdateMode`:

| 값 | 동작 |
| --- | --- |
| `OFF` | 실패해도 expected 값을 변경하지 않음 |
| `APPLY` | 실패 결과의 실제 값을 verify RHS에 적용 |
| `DEFAULT` | `cfg.ExpectedUpdateMode` 사용 |

기대값 변경 의도가 없다면 Excel 행과 전역 기본값을 `OFF`로 설정합니다.

## 11. 종합 검증

### 11.1 `st_verify_all`

빠른 상태 확인:

```matlab
summary = st_verify_all( ...
    'Profile', 'QUICK', ...
    'Target', 'CURRENT', ...
    'FailOnNonPass', false);
```

실제 모델 격리 실행:

```matlab
summary = st_verify_all( ...
    'Profile', 'RUNTIME', ...
    'Target', 'CURRENT', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', false);
```

최종 fixture와 실제 모델 인증:

```matlab
summary = st_verify_all( ...
    'Profile', 'CERTIFY', ...
    'Target', 'BOTH', ...
    'ManualEvidence', 'manual-evidence.json', ...
    'KeepWorkspace', 'ON_FAILURE', ...
    'FailOnNonPass', false);
```

결과는 `result/verification/runs/`에 저장되며 `latest.json`이 최신 실행을
가리킵니다. 상세 판정은 `docs/user-manual.md`와 `docs/verification.md`를
참조합니다.

## 12. 재실행 번들 내보내기

### 12.1 `st_export_test_bundle`

저장된 모델, Test File, 관리 Excel, dependency와 입력을 독립 실행 번들로
복사합니다. 원본 모델과 Test File은 저장된 상태여야 합니다.

```matlab
info = st_export_test_bundle();
```

ZIP 없이 폴더만 생성:

```matlab
info = st_export_test_bundle('CreateArchive', false);
```

특정 run report를 참조 결과로 포함:

```matlab
info = st_export_test_bundle( ...
    'RunId', '20260830_120000_example');
```

출력: `result/exports/{timestamp}_{id}/`와 선택적 ZIP. 자세한 형식은
`docs/export-bundle.md`를 참조합니다.

## 13. 진단 명령

| 명령 | 용도 | 원본 변경 |
| --- | --- | --- |
| `st_diagnose_sldv_timing` | SLDV raw 시간과 Dataset 시간 비교 | 없음 |
| `st_diagnose_excel_access` | Python/xlwings Excel 접근 경로 비교 | 기본 읽기 전용 |
| `st_diagnose_assessment_port_mapping` | Harness 출력과 Assessment 입력 물리 연결 확인 | 없음 |
| `st_diagnose_assessment_port_mapping_range` | 여러 행의 mapping 범위 진단 | 없음 |
| `st_show_assessment_mapping_order` | Assessment symbol/port 순서 표시 | 없음 |
| `st_show_assessment_scenario_output_order` | Scenario 입력과 출력 순서 표시 | 없음 |

Excel 진단의 `writeProbe=true`도 원본 workbook을 저장하지 않지만 disposable
workbook을 같은 폴더에 생성해 쓰기 가능 여부를 확인합니다.

## 14. 결과 파일 구조

```text
result/
├── reports/          # 단계별 INI
├── sldv/             # generated latest data와 manifest
├── state/            # 증분 workflow checkpoint
├── runs/             # Test 실행 통합 보고서
├── exports/          # 재실행 번들과 ZIP
├── verification/     # QUICK/RUNTIME/CERTIFY 결과
├── latest.json       # 최신 normal run 포인터
└── TestSummary.xlsx  # 최신 normal run 요약
```

`result/`는 생성물 영역이지만 인증 증거, 전달 번들 또는 재현에 필요한 run을
삭제하기 전에 별도로 보관해야 합니다.

## 15. 결과 정리

### 15.1 `st_cleanup_results`

인자 없이 실행하면 아무것도 삭제하지 않고 계획만 출력합니다.

```matlab
plan = st_cleanup_results();
```

Scope:

| Scope | 정리 대상 |
| --- | --- |
| `REPORTS` | `result/reports` |
| `SLDV` | `result/sldv`; 삭제 후 SLDV 준비 필요 |
| `STATE` | `result/state`; 다음 AUTO에서 준비 단계 재평가 |
| `RUNS` | `result/runs`, `latest.json`, `TestSummary.xlsx` |
| `EXPORTS` | `result/exports` |
| `VERIFICATION` | `result/verification` |
| `ALL` | 위의 모든 알려진 생성물 |

선택 범위 dry-run:

```matlab
plan = st_cleanup_results( ...
    'Scope', {'REPORTS','STATE'});
```

계획을 확인한 뒤 실제 적용:

```matlab
plan = st_cleanup_results( ...
    'Scope', {'REPORTS','STATE'}, ...
    'Apply', true);
```

전체 생성물 적용:

```matlab
plan = st_cleanup_results( ...
    'Scope', 'ALL', ...
    'Apply', true);
```

안전 경계:

- `result/` 자체는 삭제하지 않습니다.
- 알려진 하위 경로만 canonical path 검증 후 삭제합니다.
- 모델, Excel, `runtime_target.mat`, `.mldatx`는 선택하지 않습니다.
- `result/` 밖에 있는 사용자 제공 SLDV MAT는 선택하지 않습니다.
- `Apply=true`의 폴더 삭제는 재귀적이며 복구되지 않을 수 있습니다.

## 16. 자주 사용하는 운영 조합

### 기존 Harness + 기존 SLDV MAT + TC까지만

```text
Targets.SldvMode=FILE
Targets.SldvDataFile=<Excel 기준 MAT 상대경로>
cfg.RunGeneratedTests=false
cfg.OverwriteTestFile=false
```

```matlab
st_setup
st_select_target_model
st_run_after_harness
```

### 준비 상태를 무시하고 SLDV부터 재적용

```matlab
st_run_after_harness( ...
    'PreparationMode', 'FORCE', ...
    'FromStage', 'SLDV');
```

### checkpoint만 제거하고 다시 판단

```matlab
st_cleanup_results('Scope', 'STATE')
st_cleanup_results('Scope', 'STATE', 'Apply', true)
st_run_after_harness
```

### 실행 후 빠른 검증

```matlab
summary = st_verify_all( ...
    'Profile', 'QUICK', ...
    'Target', 'CURRENT', ...
    'FailOnNonPass', false);
```

## 17. 실패 시 확인 순서

1. MATLAB Command Window의 마지막 `[단계/대상] FAIL` 메시지
2. `result/reports/WorkflowPlanResult.ini`
3. 해당 단계 INI 결과의 `Status`, `Message`
4. `PreparationMode=FORCE`가 필요한지 판단
5. SLDV FILE이면 subsystem path, TestCase, Dataset 이름·자료형·차원 확인
6. Test Manager 단계면 Scenario/Iteration 이름과 기존 TC 중복 확인
7. runtime 인증은 `VerificationSummary.xlsx`의 required FAIL/BLOCKED 확인

`Ctrl+C`로 중단했으면 열린 Harness와 모델의 Dirty 상태를 확인하고 저장 여부를
판단한 뒤 다시 실행합니다. 증분 checkpoint는 성공한 단계만 재사용합니다.
