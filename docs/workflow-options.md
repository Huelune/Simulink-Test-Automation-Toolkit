# 전체 흐름과 단계별 옵션

팀 작업 절차의 순서대로, 각 단계에서 부르는 명령과 그 명령이 받는 옵션을 한 곳에
모았습니다. 옵션 기본값은 **아무것도 주지 않았을 때의 값**입니다. 기본 흐름은 모든
단계를 옵션 없이 부르면 되도록 맞춰져 있습니다.

단계별 확인 방법과 결과물 설명은 [팀 작업 절차](team-workflow.md)에, 명령마다의
자세한 동작은 [내부 표준 명령](team-commands.md)에 있습니다.

## 1. 전체 흐름

```text
준비        st_setup                               MATLAB을 켤 때마다
   │        st_select_target_model                 처음 1회, 모델을 바꿀 때
   │        st_set_standalone_coverage_root        결과 루트 D:\model_result\<Top Model>
   │        st_pre_validate_targets                Excel을 고칠 때마다
   │
1단계       st_run_from_harness                    준비 + 실행 (PER_CUT)
   │          HARNESS → SLDV → HARNESS_CONFIG → SIGNAL_EDITOR
   │          → ASSESSMENT → TEST_MANAGER → ALIGNMENT → EXECUTE
   │        (Harness가 이미 있으면 st_run_after_harness: SLDV부터)
   │
1-2단계     st_collect_per_cut_results             CVF + CUT별 보고서 (필수)
   │
2단계       st_export_test_specification           (선택) 명세서 Excel
   │
3단계       st_run_standalone_coverage_pipeline    standalone 제출물
   │          EXECUTE → PACKAGE → SUMMARY
   │        st_check_standalone_coverage           1111111111이면 통과
   │
4단계       st_classify_standalone_results         팀 제출 트리 (세 갈래)
   │
5단계       st_export_final_document               고객 제출용 최종 문서
```

| 단계 | 명령 | 만들어지는 곳 |
| --- | --- | --- |
| 준비 | `st_pre_validate_targets` | `result/reports/PreValidationResult.ini` |
| 1 | `st_run_from_harness` | 모델 안 Harness, Test File, `result/per_cut_runs/<RunId>/` |
| 1-2 | `st_collect_per_cut_results` | `result/per_cut_runs/<RunId>/targets/` 아래 CUT별 보고서 |
| 2 | `st_export_test_specification` | `result/test_specification_<시각>.xlsx` |
| 3 | `st_run_standalone_coverage_pipeline` | `D:\model_result\<Top Model>\<PipelineId>\` |
| 4 | `st_classify_standalone_results` | `D:\model_result\<Top Model>\<TopModel>\` |
| 5 | `st_export_final_document` | `result/final_document_<시각>.xlsx` |

1단계의 SLDV·Harness 생성·실행과 3단계 실행은 Windows 260자 경로 제한을 피하려고
`%TEMP%\stt_build` 아래 짧은 폴더에서 돌고, 끝나면 원래 폴더로 돌아옵니다. 위치는
`cfg.StandaloneBuildCacheDir`로 바꿀 수 있습니다([설정 사전](config-reference.md)).

## 2. 기본 코드

모든 단계를 기본 옵션으로 부르는 코드입니다. 결과 확인을 넣은 전체 코드는
[팀 작업 절차 8절](team-workflow.md#8-복사용-전체-코드)에 있습니다.

```matlab
st_setup
st_select_target_model
st_set_standalone_coverage_root
R = st_pre_validate_targets();

st_run_from_harness
st_collect_per_cut_results

info = st_run_standalone_coverage_pipeline();
[code, summary, details] = st_check_standalone_coverage();
tree = st_classify_standalone_results('PipelineId', info.PipelineId);

[T, finalFile] = st_export_final_document('CoveragePipelineId', info.PipelineId);
```

## 3. 준비

| 명령 | 인자 | 기본 | 뜻 |
| --- | --- | --- | --- |
| `st_setup` | 없음 | | 툴킷 경로를 MATLAB path에 올립니다. 클론 루트에서 부릅니다 |
| `st_select_target_model` | `forceSelectModel` | `false` | `true`면 저장된 선택을 무시하고 모델 선택 창을 다시 띄웁니다 |
| `st_set_standalone_coverage_root` | `rootDir` | 생략 | 생략하면 `D:\model_result\<Top Model>`, 경로를 주면 그 경로, `''`면 지정 해제(`result/standalone_coverage`) |
| `st_pre_validate_targets` | 없음 | | Excel의 활성 행을 모델에 대 보고 문제를 표로 돌려줍니다 |

`st_select_target_model`과 `st_set_standalone_coverage_root`의 선택은 로컬
`runtime_target.mat`에 저장되므로 MATLAB을 다시 켜도 유지됩니다.

## 4. 1단계 — `st_run_from_harness`

`st_run_after_harness`도 같은 옵션을 받습니다. 차이는 HARNESS 단계를 건너뛰고
SLDV부터 시작한다는 것뿐입니다. 빈 값(`''`, `[]`)은 `st_config.m`의 값을 씁니다.

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `PreparationMode` | `'AUTO'` | `AUTO`는 입력이 그대로인 단계를 건너뜁니다. `FORCE`는 `FromStage`부터 다시 합니다 |
| `FromStage` | 처음 단계 | `FORCE`로 다시 할 첫 단계. `HARNESS`, `SLDV`, `HARNESS_CONFIG`, `SIGNAL_EDITOR`, `ASSESSMENT`, `TEST_MANAGER`, `ALIGNMENT`. `EXECUTE`는 준비 없이 실행만 합니다 |
| `ExecuteTests` | `true` | `false`면 Test Case까지 만들고 실행하지 않습니다 |
| `ExecutionMode` | `'PER_CUT'` | `PER_CUT`은 Test Case마다 따로, `BATCH`는 `run(tf)` 한 번에 전부 |
| `ContinueOnFailure` | `true` | PER_CUT에서 한 CUT이 **예외**로 죽어도 다음 CUT으로 넘어갑니다. verify FAIL은 예외가 아니라 이 옵션과 상관없이 넘어갑니다 |
| `FailOnNonPass` | `false` | `true`면 끝난 뒤 FAIL·EXCEPT·WARN인 CUT이 있을 때 MATLAB 오류를 냅니다 |
| `ReportMode` | `'SUMMARY'` | CUT별 보고서 수준. `FULL`은 공식 Test Manager PDF까지 만듭니다 |
| `AutoCollect` | `false` | `true`면 실행 끝에 `st_collect_per_cut_results`까지 이어서 합니다 |
| `IgnoreUnexpectedSldvInputs` | `false` | SLDV가 만든 입력 중 Harness에 없는 신호를 버립니다. 이 실행에만 적용됩니다 |
| `StrictRestart` | `false` | 앞 단계를 건드리지 않는 엄격 재시작. `st_run_from_stage`가 쓰므로 직접 줄 일은 없습니다 |

무엇을 바꿨을 때 어디부터 다시 하는지는
[내부 표준 명령](team-commands.md)의 "두 번째 실행부터는 빨라집니다"에 있습니다.

## 5. 1-2단계 — `st_collect_per_cut_results`

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `RunId` | `'LATEST'` | 정리할 PER_CUT 실행 |
| `ReportMode` | 실행 때 값 | `SUMMARY` 또는 `FULL`. 비우면 그 실행이 기록한 값을 씁니다 |

정리는 실행 때 저장한 ResultSet에 CVF를 붙여 CUT별 보고서를 만듭니다. 실행을 다시
하지 않으므로 Excel의 Coverage 열만 고쳤다면 이 명령만 다시 부르면 됩니다.

## 6. 2단계 — `st_export_test_specification` (선택)

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `OutputFile` | `result/test_specification_<시각>.xlsx` | 출력 파일. 이미 있으면 거부합니다 |
| `VerifyMode` | `'STEP2'` | `STEP2`는 Step 2의 verify만, `ALL_STEPS_COLUMNS`는 verify가 있는 모든 스텝을 열로 |
| `DecisionBlockScope` | `'EXPLICIT'` | `EXPLICIT`는 조건이 적힌 블록만, `ALL`은 커버리지 목표를 만드는 블록까지, `NONE`은 비움 |

## 7. 3단계 — standalone 제출물

### `st_run_standalone_coverage_pipeline`

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `Action` | `'ALL'` | `ALL`은 EXECUTE → PACKAGE → SUMMARY. 나눠 돌릴 때 `EXECUTE`, `PACKAGE`, `SUMMARY`. `PREPARE`는 재배선한 Test File만 만들고 실행하지 않습니다 |
| `PipelineId` | `'LATEST'` | `PACKAGE`·`SUMMARY`가 이어 받을 실행 |
| `ContinueOnFailure` | `true` | 한 CUT이 예외로 죽어도 다음 CUT으로 넘어갑니다 |
| `FailOnNonPass` | `false` | `true`면 PASS가 아닌 CUT이 있을 때 오류를 내고, 뒤의 PACKAGE·SUMMARY를 하지 않습니다 |
| `CloseSourceModel` | `true` | 실행 전에 원본 Top Model·Harness·Test File을 저장하고 닫습니다. 복사본과 모델 이름이 겹치기 때문입니다 |
| `ClassifyResults` | `false` | `true`면 `ALL` 끝에 4단계 팀 제출 트리를 자동으로 만들고 `info.SubmissionTree`에 위치를 돌려줍니다 |
| `SaveTestResult` | `ALL`은 `false`, `EXECUTE`는 `true` | Test Result를 파일로 남깁니다. 다른 세션에서 PACKAGE를 이어 하거나 제출물의 Results를 볼 때 필요합니다 |
| `OutputRoot` | 결과 루트 | 비우면 `st_set_standalone_coverage_root`로 정한 곳 |

### `st_check_standalone_coverage`

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `PipelineId` | `'LATEST'` | 검사할 실행 |
| `OutputRoot` | 결과 루트 | 비우면 `st_set_standalone_coverage_root`로 정한 곳 |

읽기만 하는 검사입니다. 돌려주는 코드의 각 자리가 검사 하나이고, 전부 `1`이면
통과입니다. 자리별 뜻은 [내부 표준 명령](team-commands.md#st_check_standalone_coverage)에
있습니다.

## 8. 4단계 — `st_classify_standalone_results`

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `PipelineId` | `'LATEST'` | 정리할 실행 |
| `PipelineRoot` | `''` | id 대신 파이프라인 폴더를 직접 지정 |
| `OutputDir` | 파이프라인 폴더 옆 `{TopModel}` | 출력 폴더 |
| `Replace` | `true` | 출력 폴더가 있으면 지우고 다시 만듭니다. 세 갈래 폴더만 있을 때만 지우고, 다른 것이 섞여 있으면 멈춥니다 |
| `DryRun` | `false` | 계획만 출력하고 복사하지 않습니다 |

MATLAB이 없는 PC에서는 같은 규칙의
`python tools/python/classify_standalone_results.py <파이프라인 폴더>`를 씁니다.

## 9. 5단계 — `st_export_final_document`

| 옵션 | 기본 | 뜻 |
| --- | --- | --- |
| `CoveragePipelineId` | `'LATEST'` | 커버리지를 가져올 standalone 실행 |
| `CoverageSource` | `'STANDALONE'` | `STANDALONE`은 3단계 결과, `TEST_RUN`은 1단계 실행의 커버리지, `NONE`은 비움 |
| `ResultRun` | `'AUTO'` | 판정을 가져올 실행. `AUTO`는 BATCH·PER_CUT 중 더 최근 것. `BATCH`, `PER_CUT`, 폴더 경로도 됩니다 |
| `DecisionBlockScope` | `'ALL'` | 명세서와 달리 기본이 `ALL`입니다 |
| `RequireTestResults` | `false` | `true`면 판정이 없을 때 오류 |
| `RequireCoverage` | `false` | `true`면 커버리지가 없을 때 오류 |
| `IncludeUsageSheet` | `false` | 사용법 시트를 맨 뒤에 붙입니다 |
| `OutputFile` | `result/final_document_<시각>.xlsx` | 출력 파일 |

판정은 1단계에서, 커버리지는 3단계에서 가져옵니다. 시트 구성은
[최종 문서 추출](final-document.md)에 있습니다.

## 10. 그 밖에 자주 쓰는 명령

| 명령 | 주요 옵션 | 뜻 |
| --- | --- | --- |
| `st_open_standalone_test_manager` | `PipelineId`(`LATEST`), `ImportResults`(`false`), `ClearTestManager`(`false`), `LoadModels`(`false`), `ApplyFilters`(`false`), `View`(`true`) | standalone 제출물을 Test Manager에서 엽니다. 파일은 바꾸지 않습니다 |
| `st_run_from_stage` | `Workflow`, `FromStage` (둘 다 필수), `SourcePipelineId` | 앞 단계를 건드리지 않고 그 단계부터 다시 합니다([재시작](manual/restart.md)) |

## 11. 상황별 조합

| 하고 싶은 것 | 코드 |
| --- | --- |
| 입력 MAT이나 SLDV 설정을 바꿨다 | `st_run_from_harness('PreparationMode','FORCE','FromStage','SLDV')` |
| Assessment를 바꿨다 | `st_run_from_harness('PreparationMode','FORCE','FromStage','ASSESSMENT')` |
| 준비만 하고 실행은 나중에 | `st_run_from_harness('ExecuteTests', false)` |
| 준비는 그대로 두고 실행만 | `st_run_from_harness('FromStage','EXECUTE')` |
| 실행과 결과 정리를 한 번에 | `st_run_from_harness('AutoCollect', true)` |
| SLDV 입력이 Harness와 안 맞는다 | `st_run_from_harness('IgnoreUnexpectedSldvInputs', true)` |
| 하나라도 실패하면 멈춰야 한다 | `st_run_from_harness('FailOnNonPass', true)` |
| 3단계에서 팀 제출 트리까지 한 번에 | `st_run_standalone_coverage_pipeline('ClassifyResults', true)` |
| 제출물의 Results까지 본다 | `st_run_standalone_coverage_pipeline('SaveTestResult', true)` 후 `st_open_standalone_test_manager('ImportResults', true)` |
| 팀 제출 트리를 다시 만든다 | `st_classify_standalone_results` |
