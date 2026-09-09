# 실행 명령 사용법

이 문서는 사용자가 직접 실행하는 MATLAB 진입점과 필요할 때 단계별로 실행할 수
있는 기능 단위를 정리한다. 내부 helper와 호환용 alias는 포함하지 않는다.
`st_export_test_specification`이 생성하는 Excel의 첫 번째 `사용법` 탭에도 같은
기준의 표가 포함된다.

## 기본 실행 순서

전체 생성부터 실행:

```matlab
st_setup
st_select_target_model
st_run_from_harness('ExecutionMode', 'PER_CUT')
```

기존 Harness부터 실행:

```matlab
st_setup
st_run_after_harness('ExecutionMode', 'PER_CUT')
```

준비 없이 CUT별 테스트만 실행:

```matlab
st_setup
st_run_tests_per_cut( ...
    'ContinueOnFailure', true, ...
    'ReportMode', 'SUMMARY', ...
    'FailOnNonPass', false)
```

테스트를 실행하지 않고 명세서만 추출:

```matlab
st_setup
[T, outputFile] = st_export_test_specification( ...
    'VerifyMode', 'ALL_STEPS_COLUMNS');
```

## 사용자 실행 단위

| 구분 | 실행 파일 | 역할 |
| --- | --- | --- |
| 초기화 | `st_setup.m` | MATLAB Path와 result 폴더 준비 |
| 대상 선택 | `st_select_target_model.m` | Top Model을 선택하고 로컬 runtime target 저장 |
| 경로 준비 | `st_export_subsystem_paths.m` | Subsystem 경로 목록을 관리 Excel로 내보내기 |
| 경로 준비 | `st_fill_temp_paths_from_indent.m` | Excel 들여쓰기로 빈 CUTPath 임시 작성 |
| 사전 검증 | `st_pre_validate_targets.m` | Harness 생성 전 CUTPath와 Subsystem 검사 |
| 사전 검증 | `st_validate_targets.m` | 기존 Harness와 CUT 연결 검사 |
| Workflow | `st_run_from_harness.m` | Harness 생성부터 테스트와 보고서까지 전체 실행 |
| Workflow | `st_run_after_harness.m` | 기존 Harness 검증 후 나머지 Workflow 실행 |
| 테스트 | `st_run_tests_per_cut.m` | 준비된 Test File을 CUT별 CVF 격리 방식으로 실행 |
| 테스트 | `st_run_generated_tests.m` | Coverage Filter가 없는 Test File을 BATCH 실행 |
| 명세서 | `st_export_test_specification.m` | 실행 없이 input, verify, MaxTime, DecisionBlocks를 Excel로 추출 |
| 내보내기 | `st_export_test_asset_bundle.m` | 선택 결과와 Harness, CVT, CVF, Coverage 자산 복사 |
| 내보내기 | `st_export_test_bundle.m` | 다른 PC에서 재실행할 수 있는 전체 번들 생성 |
| 검증 | `st_verify_all.m` | 환경, 단위, fixture와 실제 모델 종합 검증 |
| 점검 | `st_check_actual_system.m` | 환경, 실행, CVF 상태를 18비트 코드로 검사 |
| 점검 | `st_check_per_cut_cvf.m` | 최신 PER_CUT CVF만 6비트 코드로 검사 |
| 정리 | `st_cleanup_results.m` | 생성 결과를 미리보기하거나 선택적으로 삭제 |

## 고급 단계 명령

정상 운영은 `st_run_from_harness` 또는 `st_run_after_harness`를 사용한다. 다음 명령은
단계별 진단이나 부분 재현이 필요할 때만 직접 실행한다. 앞 단계 산출물이 없으면
실패할 수 있다.

| 실행 파일 | 역할 |
| --- | --- |
| `st_create_harnesses.m` | 누락 Harness 생성 |
| `st_prepare_sldv_targets.m` | SLDV 데이터와 manifest 준비 |
| `st_configure_harnesses.m` | Harness StopTime 등 설정 |
| `st_configure_signal_editors.m` | Signal Editor MAT와 Scenario 구성 |
| `st_configure_assessments.m` | Assessment Scenario와 verify 구성 |
| `st_prepare_coverage_filters.m` | 공유 방식 Coverage Filter 준비 |
| `st_create_test_manager.m` | Test File, Test Case와 Iteration 구성 |
| `st_validate_scenario_alignment.m` | Scenario와 Iteration 정렬 검사 |

`st_run_workflow.m`, 보고서 작성 함수와 세부 변환 함수는 공개 실행 명령을 지원하는
내부 구현이므로 직접 실행 목록에서 제외한다.

Template clone 설정과 복구 절차는 [harness-template-clone.md](harness-template-clone.md)를 참고한다.
