# 실행 명령 사전

사용자가 직접 실행하는 공개 명령과 **각 명령이 받는 옵션의 역할**을 정리했습니다.
내부 helper와 호환용 alias는 넣지 않았습니다.

- Excel 열의 역할: [관리 Excel 열 사전](workbook-reference.md)
- 전역 설정의 역할: [설정 사전](config-reference.md)
- 복사해서 바로 쓸 코드: [수동 실행 안내](manual/README.md)

`st_export_test_specification`이 만드는 Excel의 첫 번째 `사용법` 탭에도 같은 기준의
표가 들어갑니다.

## 0. 옵션 적는 법

명령의 옵션은 전부 `'이름', 값` 쌍입니다. 순서는 상관없고, 필요한 것만 적으면
나머지는 기본값이 쓰입니다.

```matlab
st_run_from_harness('ExecutionMode','PER_CUT', 'ReportMode','SUMMARY')
```

명령 옵션은 그 **한 번의 실행에만** 적용됩니다. 영구적으로 바꾸려면
`src/config/st_config.m`을 고치십시오.

## 1. 명령 한눈에 보기

### 평소 쓰는 명령

```matlab
st_setup
st_pre_validate_targets
st_run_from_harness

st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', 'ContinueOnFailure', true, 'FailOnNonPass', false);
```

| 구분 | 명령 | 역할 |
| --- | --- | --- |
| 초기화 | `st_setup` | MATLAB path와 `result/` 폴더 준비 |
| 대상 선택 | `st_select_target_model` | Top Model 선택과 로컬 저장 |
| 사전 검증 | `st_pre_validate_targets` | Harness 생성 전 CUT 경로 검사 |
| Workflow | `st_run_from_harness` | Harness 생성부터 준비·테스트까지 전체 실행 |
| Workflow | `st_run_after_harness` | 기존 Harness 검증 후 SLDV부터 실행 |
| Pipeline | `st_run_standalone_coverage_pipeline` | standalone 제출물 생성 |
| 점검 | `st_check_standalone_coverage` | standalone 결과를 10비트 코드로 검사 |
| 점검 | `st_check_actual_system` | 환경·실행·CVF를 18비트 코드로 검사 |

### 필요할 때만 쓰는 명령

| 구분 | 명령 | 역할 |
| --- | --- | --- |
| 경로 준비 | `st_export_subsystem_paths` | Subsystem 경로 전체를 Excel로 내보내기 |
| 경로 준비 | `st_fill_temp_paths_from_indent` | Excel 들여쓰기로 빈 CUTPath 채우기 |
| 경로 준비 | `st_find_target_paths` | 같은 이름 후보를 순위화해 선택 |
| 사전 검증 | `st_validate_targets` | 기존 Harness와 CUT 연결 검사 |
| 명세서 | `st_export_test_specification` | 실행 없이 입력·verify를 Excel로 추출 |
| 점검 | `st_check_per_cut_cvf` | 최신 PER_CUT CVF를 6비트 코드로 검사 |
| 정리 | `st_cleanup_results` | 생성 결과 미리보기 또는 삭제 |
| 테스트 | `st_run_tests_per_cut` | 준비된 Test File을 CUT별로만 실행 |
| 테스트 | `st_run_generated_tests` | 필터 없는 Test File을 BATCH 실행 |

### 선택 기능

| 구분 | 명령 | 역할 |
| --- | --- | --- |
| 모델 profile | `st_save_model_profile` | 모델별 경로 묶음을 이름으로 저장 |
| 모델 profile | `st_list_model_profiles` | 저장된 profile 목록 보기 |
| 모델 profile | `st_select_model_profile` | profile 전환 |
| 단계 재시작 | `st_check_readiness` | 선택 단계부터 실행 가능한 상태인지 검사 |
| 단계 재시작 | `st_run_from_stage` | 선행 단계 검증 후 선택 단계부터 끝까지 실행 |
| 내보내기 | `st_export_test_asset_bundle` | 선택 결과와 자산을 한 폴더로 |
| 내보내기 | `st_export_test_bundle` | 다른 PC에서 재실행할 전체 번들 |
| 검증 | `st_verify_all` | 환경·단위·fixture·실제 모델 종합 검증 |
| 예제 | `st_create_example` | 익명 모델·입력·Excel 생성 |

## 2. 초기화와 대상 선택

### `st_setup`

MATLAB이 이 도구의 명령을 찾을 수 있게 경로를 등록하고 `result/` 폴더를 만듭니다.
옵션이 없습니다. **MATLAB을 새로 켤 때마다 한 번씩 실행해야 합니다.**

### `st_select_target_model`

```matlab
cfg = st_select_target_model();      % 유효한 선택이 있으면 그대로 재사용
cfg = st_select_target_model(true);  % 무조건 다시 고르기
```

설정된 검색 루트에서 `.slx`/`.mdl`을 찾아 목록을 보여 주고, 고른 결과를
`runtime_target.mat`에 저장합니다.

| 인자 | 기본값 | 역할 |
| --- | --- | --- |
| 첫 번째 (선택) | `false` | `true`면 기존 선택을 무시하고 다시 고릅니다 |

### `st_save_model_profile` (선택 사항)

> 모델을 하나만 쓴다면 필요 없습니다. `st_select_target_model`로 충분합니다.
> 여러 모델을 번갈아 쓰면서 결과가 섞이지 않게 하고 싶을 때만 씁니다.

모델 하나에 관련된 경로들을 이름으로 묶어 저장합니다. **저장만 하고 활성화하지
않으며, 모델을 열지도 않습니다.**

```matlab
st_save_model_profile('MODEL_A', ...
    'ModelFile',       'D:\models\MODEL_A\MODEL_A.slx', ...
    'ManagementExcel', 'D:\models\MODEL_A\TestManagement.xlsx', ...
    'OutputRoot',      'D:\results\MODEL_A');
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| 첫 번째 인자 (필수) | — | profile 이름. 이 이름으로 전환합니다 |
| `ModelFile` | — | Top Model 파일 경로. **이미 존재해야 합니다** |
| `ManagementExcel` | — | 관리 Excel 경로. **이미 존재해야 합니다** |
| `OutputRoot` | — | 이 모델의 결과가 저장될 루트. 다른 profile과 겹치면 거부합니다 |
| `TestFile` | `OutputRoot` 아래 | Test File(`.mldatx`) 경로. 준비 단계가 새로 만들 수 있으므로 없어도 됩니다 |
| `StandaloneCoverageRootDir` | `OutputRoot` 아래 | standalone 제출물 저장 위치 |
| `ManagementSheet` | `'Targets'` | 관리 Excel의 시트 이름 |
| `TestSuiteName` | `'New Test Suite 1'` | Test Case를 담을 Suite 이름 |
| `Overwrite` | `false` | 같은 이름의 profile을 덮어쓸 때 `true` |

### `st_list_model_profiles` / `st_select_model_profile`

```matlab
st_list_model_profiles();                    % 목록 보기
cfg = st_select_model_profile('MODEL_A');    % 이름으로 전환
cfg = st_select_model_profile();             % 목록에서 고르기 (취소하면 기존 유지)
cfg = st_select_model_profile('');           % profile 해제, 기존 단일 모델 방식으로
```

profile을 고르면 결과·상태·export 경로가 모두 그 `OutputRoot` 아래로 바뀝니다.
같은 이름의 다른 모델이 이미 로드돼 있으면 자동으로 닫지 않고 선택을 거부합니다.

자세한 내용은 [모델 profile](manual/model-profiles.md)에 있습니다.

## 3. CUT 경로 준비

### `st_export_subsystem_paths`

모델에서 찾을 수 있는 모든 Subsystem 경로를 관리 Excel의 `ModelSubsystems` 시트로
내보냅니다. 사람이 보고 `Targets.CUTPath`로 복사할 때 씁니다.

```matlab
R = st_export_subsystem_paths();
R = st_export_subsystem_paths(true);   % 모델을 다시 고르면서 실행
```

계층은 Excel 셀의 들여쓰기(IndentLevel)로 표시합니다. Excel의 들여쓰기 단계에는
한계가 있으므로 실제 깊이는 `Depth` 열에 따로 보존합니다.

### `st_fill_temp_paths_from_indent`

`CUTName` 셀의 들여쓰기를 계층으로 해석해 비어 있는 `CUTPath`를 채웁니다.

```matlab
R = st_fill_temp_paths_from_indent();      % 빈 셀만 채움 (기본)
R = st_fill_temp_paths_from_indent(true);  % 기존 경로도 덮어씀
```

계층의 근거는 **셀의 IndentLevel 속성**이지, 셀 값 앞의 공백 문자나 별도 Depth 열이
아닙니다.

### `st_find_target_paths`

같은 이름의 Subsystem이 여러 개일 때, 주변에 이미 확정된 CUT과 Excel 행 문맥을
이용해 후보 순위를 계산하고 고르게 합니다.

```matlab
R = st_find_target_paths();
```

- 한 행에서 확정된 Subsystem은 이후 행의 후보에서 제외합니다.
- **모든 행이 해결되고 검증을 통과한 경우에만** Excel에 한 번에 기록합니다.
- 기존 경로에 중복이 있거나 선택을 취소하면 Excel을 전혀 바꾸지 않습니다.

> Excel을 바꾸는 명령입니다. 실행 전에 workbook을 백업하고 저장 상태를 확인하십시오.

## 4. 실행 전 검증

세 명령 모두 모델이나 Test File을 **저장하거나 변경하지 않습니다.**

### `st_pre_validate_targets`

Harness 생성 전에 다음을 확인합니다. 결과는
`result/reports/PreValidationResult.ini`에 저장됩니다.

- `CUTPath`가 비어 있지 않은가
- 선택한 Top Model 기준으로 경로를 정규화할 수 있는가
- 그 경로에 블록이 있는가
- 그 블록이 Subsystem인가

### `st_validate_targets`

기존 Harness workflow 전에 CUT과 Harness의 연결을 확인합니다. 컴파일은 하지
않습니다. 결과는 `result/reports/ValidationResult.ini`에 저장됩니다.

### `st_check_readiness` (선택 사항)

`st_run_from_stage`와 짝으로 쓰는 명령입니다. **선택한 단계부터 실행해도 되는
상태인지**를 읽기 전용으로 검사합니다.

```matlab
[ready, checks] = st_check_readiness( ...
    'Workflow','FROM_HARNESS', 'FromStage','ASSESSMENT');
disp(checks)
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `Workflow` | `'STANDALONE'` | 어떤 workflow 기준으로 검사할지 |
| `FromStage` | `''` | 어느 단계부터 실행할 예정인지 |
| `SourcePipelineId` | `''` | `STANDALONE`의 `PACKAGE`/`SUMMARY` 재생성에서 원본 PipelineId |

`Workflow`가 받는 값과 그에 맞는 `FromStage`는 다음과 같습니다.

| `Workflow` | 선택 가능한 `FromStage` |
| --- | --- |
| `FROM_HARNESS` | `HARNESS`, `SLDV`, `HARNESS_CONFIG`, `SIGNAL_EDITOR`, `ASSESSMENT`, `COVERAGE_FILTER`, `TEST_MANAGER`, `ALIGNMENT`, `EXECUTE` |
| `AFTER_HARNESS` | 위 목록에서 `HARNESS` 제외 |
| `STANDALONE` | `EXECUTE`, `PACKAGE`, `SUMMARY` |

반환값:

| 값 | 내용 |
| --- | --- |
| `ready.Ready` | `true`면 실행해도 됩니다 |
| `ready.RecommendedFromStage` | `false`일 때 대신 시작하라고 권하는 단계 |
| `checks` | 검사 항목별 `Status`, `Message`, `RequiredFromStage` 표 |

> 이 명령은 필요한 모델과 Test File을 잠시 로드하고, **자신이 연 것만** 저장 없이
> 닫습니다. 출력 디렉터리는 임시 파일을 만들었다 지워 쓰기 가능 여부를 확인합니다.
> 모델 callback의 부작용과 라이선스 실제 checkout까지 막아 주는 sandbox는 아닙니다.

## 5. Workflow 진입점

### `st_run_from_harness` / `st_run_after_harness`

| 명령 | 언제 |
| --- | --- |
| `st_run_from_harness` | Harness가 없을 수 있는 전체 실행 |
| `st_run_after_harness` | Harness가 전부 있을 때. 기존 매핑을 검증하고 SLDV부터 |

```matlab
[resultObj, updateResult, workflowResult, reportInfo] = st_run_from_harness();
```

반환값 네 개는 각각 테스트 결과, 기대값 갱신 결과, workflow 단계 결과, 보고서
정보입니다. `PER_CUT`에서 `resultObj`는 CUT별 `InitialResult`와 `FinalResult`를 가진
struct 배열이고, `BATCH`에서는 단일 최종 ResultSet입니다.

두 명령이 받는 옵션은 같습니다.

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `PreparationMode` | `cfg` 값 (`'AUTO'`) | `'AUTO'`는 캐시 재사용, `'FORCE'`는 `FromStage`부터 다시 실행 |
| `FromStage` | `cfg` 값 (`'START'`) | `FORCE`가 시작할 준비 단계 |
| `ExecutionMode` | `cfg` 값 (`'AUTO'`) | `'AUTO'`/`'BATCH'`/`'PER_CUT'` |
| `ExecuteTests` | `cfg.RunGeneratedTests` | `false`면 준비까지만 하고 실행하지 않습니다 |
| `ContinueOnFailure` | `true` | `PER_CUT`에서 한 CUT이 실패해도 다음을 계속할지 |
| `ReportMode` | `'SUMMARY'` | `'SUMMARY'` 또는 `'FULL'`(PDF와 전체 Coverage HTML 추가) |
| `FailOnNonPass` | `false` | `true`면 통과하지 못한 Test Case가 있을 때 MATLAB 오류 |
| `StrictRestart` | `false` | 선택한 단계만 실행하고 앞 단계는 건드리지 않는 엄격 재시작 모드. `st_run_from_stage`가 내부적으로 켜므로 직접 줄 일은 거의 없습니다 |

```matlab
st_run_from_harness('PreparationMode','FORCE', 'FromStage','SLDV');

[results, updates, workflow, report] = st_run_from_harness( ...
    'ExecutionMode','PER_CUT', ...
    'ContinueOnFailure', true, ...
    'ReportMode','SUMMARY', ...
    'FailOnNonPass', false);
```

> `PreparationMode='FORCE'`는 증분 계산 때문에 **앞 단계까지 무효화할 수 있습니다.**
> 앞 단계를 절대 다시 실행하지 않아야 하면 `st_run_from_stage`를 쓰십시오.

### `st_run_from_stage` (선택 사항)

> 평소 재실행은 `st_run_from_harness('PreparationMode','FORCE','FromStage',...)`로
> 충분합니다. 이 명령은 **오래 걸리는 앞 단계를 절대 다시 실행하면 안 될 때**와
> standalone 결과를 재실행 없이 재생성할 때 씁니다.

선행 단계를 검증한 뒤 **선택한 단계부터 해당 workflow 끝까지** 실행합니다. 앞 단계가
유효하지 않으면 자동으로 고치지 않고 중단합니다.

```matlab
info = st_run_from_stage('Workflow','FROM_HARNESS', 'FromStage','ASSESSMENT');
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `Workflow` | `''` | `FROM_HARNESS`, `AFTER_HARNESS`, `STANDALONE` |
| `FromStage` | `''` | 시작할 단계. `st_check_readiness`와 같은 값 |
| `SourcePipelineId` | `''` | `STANDALONE`의 `PACKAGE`/`SUMMARY` 재생성 원본 |

`st_check_readiness`로 먼저 검사한 뒤 같은 인자로 이 명령을 실행하는 것이 표준
절차입니다. 자세한 제한은 [재시작](manual/restart.md)에 있습니다.

## 6. 테스트 실행

### `st_run_tests_per_cut`

이미 준비된 Test File을 CUT별로 실행합니다. 준비 단계를 수행하지 않습니다.

```matlab
[results, updates, summary] = st_run_tests_per_cut( ...
    'ContinueOnFailure', true, ...
    'ReportMode','SUMMARY', ...
    'FailOnNonPass', false);
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `ContinueOnFailure` | `true` | 필터 복원이 확인되면 다음 CUT을 계속 처리 |
| `ReportMode` | `'SUMMARY'` | `'SUMMARY'` 또는 `'FULL'` |
| `FailOnNonPass` | `false` | `true`면 모든 CUT 처리 후 통과 실패를 MATLAB 오류로 전달 |
| `ResultFilterMode` | `'DURING_RUN'` | `'POST_RUN_REQUIRED'`는 standalone pipeline 전용 |
| `GenerateResultArtifacts` | `true` | MLDATX·HTML 등 결과 산출물을 만들지 |
| `WriteRunSummaryExcel` | `true` | 실행 요약 Excel을 만들지 |
| `SaveTestResult` | `false` | aggregate Result를 파일로 저장할지 |
| `RunRootDirectory` | `''` | 결과를 쓸 루트를 직접 지정 |

Test Case 판정이 `FAILED`/`UNTESTED`/`INCOMPLETE`여도 실행 자체가 끝났으면
`FinalOutcome`에 보존하고 상태를 `WARN`으로 기록한 뒤 다음 CUT을 계속합니다.
실행기나 결과 저장에서 예외가 난 경우에만 `FAIL`입니다.

> 병렬 CUT 실행은 지원하지 않습니다.

### `st_run_generated_tests`

Coverage Filter가 없는 Test File을 BATCH로 실행합니다. 보통 workflow 진입점이
내부적으로 호출하므로 직접 쓸 일은 드뭅니다.

## 7. 테스트 명세서 추출

### `st_export_test_specification`

테스트를 실행하지 않고, 저장된 Assessment 시나리오·입력 마지막 값·verify 문장을
Excel로 뽑습니다.

```matlab
[T, outputFile] = st_export_test_specification();
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `OutputFile` | `result/test_specification_<timestamp>.xlsx` | 저장할 파일 경로. **이미 있으면 덮어쓰지 않고 실패합니다** |
| `VerifyMode` | `'STEP2'` | `'STEP2'`는 각 시나리오의 직계 Step 2만, `'ALL_STEPS_COLUMNS'`는 verify가 있는 모든 스텝을 오른쪽 열에 나눠 씁니다 |
| `DecisionBlockScope` | `cfg.DecisionBlockScope` (`'EXPLICIT'`) | `DecisionBlocks` 열에 어디까지 담을지. `'EXPLICIT'`/`'ALL'`/`'NONE'` |

```matlab
% 모든 스텝의 verify를 스텝별 열로
[T, file] = st_export_test_specification('VerifyMode','ALL_STEPS_COLUMNS');

% If/Switch가 없는데 Decision coverage가 나오는 이유를 찾을 때
[T, file] = st_export_test_specification('DecisionBlockScope','ALL');
```

모델을 읽기 위해 로드하지만 시뮬레이션·테스트 실행·SLDV 생성·기대값 갱신은 하지
않습니다. 자세한 열 구성과 판정 규칙은
[테스트 명세서 추출](test-specification.md)에 있습니다.

## 8. Standalone Coverage 파이프라인

### `st_run_standalone_coverage_pipeline`

준비가 끝난 Test Case로 standalone 제출물을 만듭니다. Harness·입력·Assessment·Test
Case 준비는 먼저 일반 workflow에서 끝내야 합니다.

```matlab
info = st_run_standalone_coverage_pipeline();                % ALL
info = st_run_standalone_coverage_pipeline('Action','EXECUTE');
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `Action` | `'ALL'` | `'EXECUTE'`/`'PACKAGE'`/`'SUMMARY'`/`'ALL'` |
| `PipelineId` | `'LATEST'` | `PACKAGE`/`SUMMARY`가 이어서 처리할 실행 id |
| `OutputRoot` | `cfg.StandaloneCoverageRootDir` | 결과를 쓸 루트 |
| `SaveTestResult` | `ALL=false`, `EXECUTE=true` | aggregate Result를 저장할지. `PACKAGE`/`SUMMARY`에는 지정할 수 없습니다 |
| `ContinueOnFailure` | `true` | 한 대상이 실패해도 다음을 계속할지 |
| `FailOnNonPass` | `false` | 통과 실패를 MATLAB 오류로 전달할지 |

Action의 역할:

| Action | 하는 일 |
| --- | --- |
| `EXECUTE` | standalone export, Test Case 1회 실행, CVF 1회 등록, 모델이 열린 동안 report/metric/CVT 임시 증거 캡처 |
| `PACKAGE` | 임시 증거를 검증해 Model/Input/CVF/CVT/HTML/Test File을 최종 산출물로 승격 |
| `SUMMARY` | manifest 값에서 `CoverageSummary.xlsx` 생성 |
| `ALL` | 세 Action 연속 실행 |

> 같은 `PipelineId`의 `PACKAGE`와 `SUMMARY`는 **각각 한 번만** 실행할 수 있습니다.
> 다시 만들려면 `st_run_from_stage`로 새 PipelineId를 만드십시오.

자세한 내용은 [Standalone Coverage 파이프라인](standalone-coverage-pipeline.md)에
있습니다.

## 9. 내보내기

### `st_export_test_asset_bundle`

선택한 Test Manager 결과와 그 결과에 대응하는 자산을 한 폴더에 모읍니다.
**보관·검토용**이며 다른 PC에서의 재실행을 보장하지 않습니다.

```matlab
info = st_export_test_asset_bundle('SelectResult', true);
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `SelectResult` | `false` | `true`면 현재 ResultSet과 저장된 run을 한 목록에 보여 주고 고르게 합니다 |
| `ResultSet` | `[]` | 스크립트에서 ResultSet 객체를 직접 지정 |
| `RunId` | `'LATEST'` | 저장된 toolkit run의 id를 직접 지정 |
| `CoverageReportMode` | `'SUMMARY'` | `'SUMMARY'`는 Coverage 없는 PDF와 경량 HTML, `'FULL'`은 Coverage 포함 PDF와 `cvhtml` 상세 보고서 |
| `CreateArchive` | `false` | `true`면 ZIP도 만듭니다 |
| `Destination` | `result/exports/assets/` 아래 | 출력 위치 |

### `st_export_test_bundle`

다른 PC에서 같은 시작 상태로 반복 실행할 수 있는 self-contained 번들을 만듭니다.

```matlab
info = st_export_test_bundle();
info = st_export_test_bundle('ExecutionModelMode','STANDALONE_HARNESS');
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `ExecutionModelMode` | `'ORIGINAL'` | `'ORIGINAL'`은 내부 Harness를 그대로, `'STANDALONE_HARNESS'`는 대상별 독립 모델로 재배선 |
| `Profile` | `'REPRODUCIBLE'` | 재현성 검사 수준. `STANDALONE_HARNESS`는 이 값에서만 쓸 수 있습니다 |
| `CreateArchive` | `true` | ZIP을 만들지 |
| `IncludeReferenceReport` | `true` | 비교용 기존 결과를 함께 넣을지 |
| `RunId` | `'LATEST'` | 참조 결과로 쓸 run id |
| `AnalyzeProducts` | `true` | 필요한 Toolbox 목록을 분석할지. **오래 걸리는 단계이며 manifest 안내용일 뿐이라 꺼도 됩니다** |
| `Destination` | `result/exports/` 아래 | 출력 위치 |

내보내기는 원본 모델과 Test File을 수정하지 않습니다. 받는 사람이
`run_exported_tests`를 실행할 때마다 immutable `template/`에서 새 작업 사본을
만듭니다. 자세한 구조는 [내보내기 번들](export-bundle.md)에 있습니다.

## 10. 상태 점검

세 명령 모두 **모델·Test File·CVF를 저장하거나 변경하지 않습니다.**

### `st_check_standalone_coverage`

standalone 결과를 10비트 코드와 최대 20줄 화면으로 검사합니다.

```matlab
[code, summary, details] = st_check_standalone_coverage('PipelineId', info.PipelineId);
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `PipelineId` | `'LATEST'` | 검사할 실행 id |
| `OutputRoot` | `cfg.StandaloneCoverageRootDir` | 결과가 있는 루트 |

전체 통과 코드는 `1111111111`입니다. 아직 적용할 수 없는 비트는 `-`로 표시하고
전체 상태는 `PARTIAL`을 반환합니다.

### `st_check_per_cut_cvf`

최신 `PER_CUT` 실행에서 만든 CVF의 rule 범주와 정책을 6비트로 검사합니다.

```matlab
[code, details] = st_check_per_cut_cvf();
[code, details] = st_check_per_cut_cvf('RunDirectory','result/per_cut_runs/<run-id>');
```

| 비트 | 통과 조건 |
| --- | --- |
| B1 | target manifest와 CVF의 SHA-256이 일치 |
| B2 | 생성·적용·복원 상태가 모두 `OK` |
| B3 | 실제 rule 수가 manifest와 같고 0보다 큼 |
| B4 | selector가 고유하고 SID가 비어 있지 않은 block selector |
| B5 | 활성화한 CUT-child/boundary rule 범주가 존재 |
| B6 | 각 범주의 selector, action, rationale 정책이 일치 |

`111111`만 전체 통과입니다. 문의할 때는 `CVF-CHECK-v2`로 시작하는 줄 전체와
`details` 표를 함께 전달하십시오.

### `st_check_actual_system`

환경·실행 결과·CVF를 한 번에 18비트로 검사합니다.

```matlab
summary = st_check_actual_system();
disp(summary.Environment); disp(summary.Run); disp(summary.CVF)
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `RunDirectory` | `'LATEST'` | 검사할 실행 폴더 또는 run id |

출력의 마지막 줄 형식은 다음과 같습니다.

```text
SYSTEM-CHECK-v1 ENV=111111 RUN=111111 CVF=111111 OVERALL=111111111111111111
```

| 묶음 | 비트 | 통과 조건 |
| --- | --- | --- |
| ENV | E1 | MATLAB 릴리스가 R2025b |
| ENV | E2 | MATLAB, Simulink, Simulink Test, Coverage, SLDV 설치 |
| ENV | E3 | 위 제품의 라이선스 존재 |
| ENV | E4 | `runtime_target.mat`, 모델, 관리 Excel, Test File 존재 |
| ENV | E5 | Harness, Test Manager, Coverage, dependency API 존재 |
| ENV | E6 | 주요 `st_*` 함수가 현재 저장소에서 하나씩만 해석됨 |
| RUN | R1 | latest pointer, root manifest, Excel과 run id 일치 |
| RUN | R2 | Excel 순서와 target manifest 순서·식별자 일치 |
| RUN | R3 | 모든 CUT이 실행 결과에 도달하고 실행기 실패·skip 없음 |
| RUN | R4 | 기대값 변경 수, APPLY, 최종 재실행·결과 연결 일치 |
| RUN | R5 | MLDATX, Excel, HTML, CVT 등 필수 산출물이 있고 실패 기록 없음 |
| RUN | R6 | 실행별 CVF가 Test File·Suite·Test Case에 남아 있지 않음 |
| CVF | C1~C6 | `st_check_per_cut_cvf`의 B1~B6과 같음 |

`OVERALL=111111111111111111`만 전체 자동 점검 통과입니다. **PDF/HTML의 시각적 내용과
Test Manager 화면 동작은 자동 코드로 판정하지 않으므로 사람이 따로 확인해야
합니다.**

## 11. 종합 검증

### `st_verify_all`

```matlab
summary = st_verify_all('Profile','QUICK', 'Target','CURRENT', 'FailOnNonPass', false);
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `Profile` | `'QUICK'` | 검사 깊이. `'QUICK'`/`'RUNTIME'`/`'CERTIFY'` |
| `Target` | `'CURRENT'` | 검사 대상. `'CURRENT'`(실제 모델)/`'FIXTURE'`(자동 생성)/`'BOTH'` |
| `ManualEvidence` | `''` | 수동 증거 JSON 경로. `CERTIFY + CURRENT/BOTH`에서 필요 |
| `KeepWorkspace` | `'ON_FAILURE'` | 격리 workspace 보존 정책. `'ALWAYS'`/`'ON_FAILURE'`/`'NEVER'` |
| `FailOnNonPass` | `true` | `true`면 `FAIL`/`BLOCKED`에서 MATLAB 오류를 냅니다 |

`FailOnNonPass`는 오류를 던질지만 바꿉니다. **검사 판정과 결과 파일 내용은 바뀌지
않습니다.** 원인을 찾는 중에는 `false`로 두고 결과를 전부 보십시오.

자세한 절차와 판정 기준은 [종합 검증](verification.md)에 있습니다.

## 12. 예제와 정리

### `st_create_example`

실제 모델 없이 2개 CUT, Dataset MAT, 관리 Excel을 새 폴더에 만듭니다. 테스트를
실행하지도, profile을 선택하지도 않습니다.

```matlab
demo = st_create_example(fullfile(tempdir,'st_demo'));
```

| 인자 | 역할 |
| --- | --- |
| 첫 번째 (필수) | 만들 위치. **비어 있는 새 폴더여야 합니다** |

반환 struct에는 `Root`, `ModelFile`, `ManagementExcel`, `InputFile`, `OutputRoot`가
들어 있습니다.

### `st_cleanup_results`

생성된 결과를 정리합니다. **기본은 dry-run이며 아무것도 지우지 않습니다.**

```matlab
plan = st_cleanup_results('Scope','STATE');               % 계획만
plan = st_cleanup_results('Scope','STATE','Apply',true);  % 실제 삭제
```

| 옵션 | 기본값 | 역할 |
| --- | --- | --- |
| `Scope` | `'ALL'` | 지울 범위. 문자열 하나 또는 cell 배열 |
| `Apply` | `false` | `true`일 때만 실제로 지웁니다 |

| Scope | 대상 |
| --- | --- |
| `REPORTS` | `result/reports` |
| `SLDV` | `result/sldv` (지우면 SLDV 준비를 다시 해야 합니다) |
| `STATE` | `result/state` (다음 `AUTO`에서 준비 단계를 다시 평가합니다) |
| `RUNS` | `result/runs`, `latest.json`, `TestSummary.xlsx` |
| `PER_CUT_RUNS` | `result/per_cut_runs`, `per_cut_latest.json` |
| `EXPORTS` | `result/exports` |
| `VERIFICATION` | `result/verification` |
| `FILTERS` | `result/coverage_filters` (다음 실행에서 재생성됩니다) |
| `ALL` | 위 전부 |

안전 경계:

- `result/` 자체는 지우지 않습니다.
- 알려진 하위 경로만 canonical path 검증 후 지웁니다.
- 모델, Excel, `runtime_target.mat`, `.mldatx`는 대상에 포함되지 않습니다.
- `result/` 밖에 있는 사용자 SLDV MAT은 포함되지 않습니다.
- `Apply=true`의 폴더 삭제는 재귀적이며 복구되지 않을 수 있습니다.

## 13. 진단 명령

원본을 변경하지 않는 읽기 전용 명령입니다.

| 명령 | 용도 |
| --- | --- |
| `st_diagnose_excel_access` | Excel 접근 경로 비교. `st_diagnose_excel_access(true)`는 버려도 되는 workbook으로 쓰기까지 확인 |
| `st_diagnose_sldv_timing` | SLDV 원본 시간과 Dataset 시간 비교 |
| `st_diagnose_assessment_port_mapping` | Harness 출력과 Assessment 입력의 물리 연결 확인 |
| `st_diagnose_assessment_port_mapping_range` | 여러 행의 mapping 범위 진단 |
| `st_show_assessment_mapping_order` | Assessment symbol/port 순서 표시 |
| `st_show_assessment_scenario_output_order` | Scenario 입력과 출력 순서 표시 |
| `st_collect_warning_ids` | 긴 실행이 내는 경고 식별자 수집 |

## 14. 단계별 실행 명령

정상 운영은 workflow 진입점을 씁니다. 다음 명령은 **단계를 끊어서 실행하거나
부분 재현이 필요할 때** 직접 실행합니다. 앞 단계 산출물이 없으면 실패합니다.

실행 순서와 각 단계의 확인 방법은
[단계별로 끊어서 실행하기](manual/step-by-step.md)에 있습니다. 전부 인자 없이
부르며 관리 Excel의 활성 행 전체를 대상으로 합니다.

> 단계 명령을 직접 부르면 **checkpoint를 남기지 않습니다.** 이후
> `st_run_from_harness`는 준비된 적 없는 것으로 판단해 SLDV 단계부터 다시
> 실행합니다.

| 명령 | 역할 | 결과 파일 |
| --- | --- | --- |
| `st_create_harnesses` | 누락 Harness 생성 | `HarnessCreateResult.ini` |
| `st_prepare_sldv_targets` | OFF/FILE/GENERATE 준비와 manifest 생성 | `SldvGenerationResult.ini`, `SldvScenarioResult.ini` |
| `st_configure_harnesses` | Harness StopTime 등 설정 | `HarnessConfigResult.ini` |
| `st_configure_signal_editors` | Signal Editor MAT와 Scenario 구성 | `SignalEditorResult.ini` |
| `st_configure_assessments` | Assessment Scenario와 verify 구성 | `AssessmentResult.ini` |
| `st_prepare_coverage_filters` | 공유 방식 Coverage Filter 준비 | — |
| `st_create_test_manager` | Test File, Test Case, Iteration 구성 | `TestManagerResult.ini` |
| `st_validate_scenario_alignment` | Scenario와 Iteration 정렬 검사 | `ScenarioAlignmentResult.ini` |

`st_run_workflow`, 보고서 작성 함수, 세부 변환 함수는 공개 명령을 지원하는 내부
구현이므로 직접 실행 목록에서 제외합니다.
