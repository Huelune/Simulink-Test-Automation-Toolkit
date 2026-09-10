# Template Harness clone

`st_run_from_harness`의 Targets 행에서 `TestPreparationSource=HARNESS_CLONE`을
선택한다. `SourceCUTPath`에는 모델 이름을 포함한 전체 CUT 경로를,
`SourceHarnessName`에는 저장된 Template Harness 이름을 넣는다.
두 열은 Template 선택에만 쓰이며 대상 `CUTPath`, `HarnessName`, `TestCaseName`은
기존 규칙을 그대로 따른다. 일반 행은 열을 비우거나 `EXISTING`으로 둔다.

```text
TestPreparationSource : HARNESS_CLONE
SourceCUTPath         : TEST_TARGET_MODEL_NAME/TemplateCUT
SourceHarnessName     : TemplateHarness
```

원본 모델은 MATLAB 경로에서 로드할 수 있어야 한다. 서로 다른 상위 모델 및
CUT 이름을 허용하며 컴파일된 포트 순서·이름·타입·차원·버스 정의·샘플 시간을
기존 인터페이스 분석기로 비교한다. 지원하지 않는 물리/event 포트나 호환되지
않는 인터페이스는 해당 CUT 실패로 보고한다. Template은 저장하고 닫아 두며,
Template을 변경할 수 있는 행은 활성 대상 목록에서 제외한다.

## 처리와 기존 설정

1. 기존 Harness를 확인한다. `cfg.OverwriteHarness=false`가 기본값이며 기존
   Harness의 clone 및 입력·Assessment 보정을 건너뛴다.
2. Template의 Signal Editor, Test Assessment와 입력 MAT를 확인한다.
3. `sltest.harness.clone`에 `DestinationOwner=대상 CUT 전체 경로`와 기존
   Harness 이름을 전달한다. Harness 파일 복사나 블록 재구축은 사용하지 않는다.
4. 입력 MAT를 `result/harness_clone/<transaction>/input.mat`로 분리한다.
   이 파일은 실행에 필요한 산출물이므로 해당 Harness를 사용하는 동안 보존한다.
5. 기존 SLDV 준비, Signal Editor 매칭, Assessment verify 생성과 Harness 설정
   함수를 대상별로 실행한다. SLDV `OFF/FILE/GENERATE`, 기대값 갱신 설정은 유지한다.
6. Clone 대상의 Step1은 Action 없이 `after(ExpectedValueSampleTime, sec)`로
   Step2에 진입한다. 기본 0.01초이며 Step2 verify는 대상 출력 기준으로 만든다.
   일반 대상의 `VerifyAtSampleTimeOnly` 동작은 바꾸지 않는다.
7. Harness update, 저장 및 닫기를 완료하고 다음 CUT를 처리한다.

원본 Template 또는 대상 CUT가 library-linked block이면 각 Harness를 처음 열기 전에
동기화 모드를 `SyncOnOpen`으로 바꿉니다. 따라서 Harness를 닫을 때 CUT 복사본이 원본
모델로 push되지 않습니다. Template close, clone, 대상의 첫 close와 최종 update/close 전후의
`StaticLinkStatus`와 `ReferenceBlock`도 비교하며 변경이 감지되면 자동 rollback이
손상 상태를 저장하지 않도록 즉시 중단합니다.

`FILE+SLDV` 또는 `GENERATE`가 비-Atomic linked CUT를 대상으로 하면 자동으로
`TreatAsAtomicUnit`을 변경하지 않습니다. 원본 library block을 Atomic으로 만든 뒤
instance link를 갱신해야 합니다. `FILE+MAT`는 Atomic 변환이 필요하지 않습니다.

`st_create_harnesses`를 직접 호출해도 clone 대상의 입력·Assessment 보정까지
수행한다. `st_run_after_harness`는 기존 Harness 후속 준비 진입점이며 새 clone이
필요하면 `st_run_from_harness`를 사용한다. Test Manager는 기존 생성기를 사용한다.
기존 `OverwriteTestFile` 설정은 Harness 교체와 독립적이다.

## 실패와 복구

`OverwriteHarness=true`이면 기존 Harness를 같은 owner의 임시 recovery Harness로
clone하고 저장한 뒤 교체한다. 후처리 실패 시 recovery Harness에서 원래 이름으로
복원하고 SLDV manifest도 복원한다. 신규 생성 실패 시 불완전 Harness를 제거한다.
복구 실패 시 로그에 recovery Harness 이름과 transaction 폴더를 남긴다.
실패 transaction의 파일은 진단을 위해 보존하며 자동 삭제하지 않는다.

Clone 실패 대상은 나머지 준비·Test Manager 생성·실행에서 제외한다. 다른 CUT는
계속 처리하며 `HarnessCreateResult`와 `reportInfo.CloneFailures`에서 실패를 확인한다.
사용자 중단은 전파한다. 일반 생성 행의 기존 오류 정책은 유지한다.

## 이전 Import에서 전환

완전 복사/Import 구현은 `backup/harness-full-copy`의 `b6d30a8`에 보존했다.
개발 브랜치는 `feat/harness-template-clone`이다. `09b16ee`와 `b6d30a8`의
Import 전용 변경을 선별 되돌렸으며 후속 명세서 출력 개선과 CVF 기능은 유지한다.
`HARNESS_IMPORT`는 자동 전환하지 않고 명시적인 설정 변경을 요구한다.
`SkipImportCompile`, Import 전용 API·manifest·프로필은 새 실행 경로에서 사용하지 않는다.

재사용 함수는 `st_normalize_cut_path`, `st_prepare_sldv_targets`,
`st_configure_signal_editors`, `st_configure_assessments`,
`st_collect_assessment_input_specs`, `st_collect_harness_output_signals`,
`st_build_verify_action`, `st_prepare_assessment_scenario`,
`st_configure_harnesses`, `st_create_test_manager` 등이다.
컴파일된 포트·버스 비교는 기존 분석기를 `st_clone_cut_interfaces`로 분리했다.

## 검증

MATLAB R2025b와 필요한 제품/라이선스가 있는 PC에서 실행한다.

```matlab
st_setup
runtests('tests/unit/test_harness_clone.m')
runtests('tests/unit/test_incremental_workflow.m')
runtests('tests/unit/test_export_test_specification.m')
runtests('tests/integration/test_harness_clone_runtime.m')
runtests('tests/integration/test_library_link_harness_runtime.m')
```

통합 테스트는 임시 프로젝트와 서로 다른 두 모델을 만든다. 원래 프로젝트의
관리 Excel 및 runtime 설정을 수정하지 않는다. 소유자/CUT 내용, 입력 독립성,
Assessment, 중간 실패 후 다음 대상 진행, 기존 Harness 건너뜀, 후처리 실패 복구와
Test Manager 연결을 검사한다. 내부/외부 Harness, 버스·배열, SLDV FILE/GENERATE,
실제 실행 및 bundle 재실행은 실제 R2025b 환경에서도 확인해야 한다.
현재 개발 PC에서는 MATLAB 런타임 검증을 수행하지 않았다.

정적 검증: 변경·추가 MATLAB 파일 중 37개가 MISS_HIT UTF-8 검사에 통과했다.
Signal Editor의 `import(reader)` 파서 오류는 Import 이전 기준 `7f0825e`에서도
동일하게 재현되는 기존 도구 제한이다. MATLAB 단위·통합 테스트 실행 결과와 구분한다.

## 파일 변경 목록

### 추가

- `docs/harness-template-clone.md`
- `src/harness/st_clone_cut_interfaces.m`
- `src/harness/st_clone_template_harness.m`
- `src/harness/st_clone_template_signature.m`
- `src/harness/st_is_harness_clone.m`
- `src/harness/st_resolve_harness_clone_settings.m`
- `src/harness/st_validate_clone_mapping.m`
- `src/sldv/st_merge_scoped_sldv_profiles.m`
- `src/targets/st_target_scope.m`
- `tests/integration/test_harness_clone_runtime.m`
- `tests/unit/test_harness_clone.m`

### 수정

- `CHANGELOG.md`
- `docs/codex-handoff.md`
- `docs/execution-commands.md`
- `docs/operator-manual.md`
- `docs/user-manual.md`
- `resources/export_bundle/run_exported_tests.m`
- `src/assessment/st_configure_assessments.m`
- `src/config/st_config.m`
- `src/exporting/st_collect_asset_inputs.m`
- `src/exporting/st_collect_specification_target.m`
- `src/exporting/st_export_test_bundle.m`
- `src/exporting/st_specification_usage_table.m`
- `src/harness/st_configure_harnesses.m`
- `src/harness/st_create_harnesses.m`
- `src/maintenance/st_cleanup_results.m`
- `src/signal_editor/st_configure_signal_editors.m`
- `src/sldv/st_empty_sldv_profile.m`
- `src/sldv/st_get_sldv_profile.m`
- `src/sldv/st_prepare_sldv_targets.m`
- `src/sldv/st_validate_sldv_verify_results.m`
- `src/targets/st_load_targets.m`
- `src/test_manager/st_create_test_manager.m`
- `src/test_manager/st_validate_scenario_alignment.m`
- `src/verification/st_verification_quick_checks.m`
- `src/verification/st_verification_source_inventory.m`
- `src/workflow/st_build_execution_plan.m`
- `src/workflow/st_force_plan_downstream.m`
- `src/workflow/st_invalidate_workflow_state.m`
- `src/workflow/st_parse_workflow_options.m`
- `src/workflow/st_run_workflow.m`
- `tests/unit/test_cleanup_results.m`
- `tests/unit/test_export_test_specification.m`
- `tests/unit/test_incremental_workflow.m`

### 제거 (백업 브랜치에 보존)

- `src/harness/st_apply_harness_content.m`
- `src/harness/st_export_import_profiles.m`
- `src/harness/st_get_test_profile.m`
- `src/harness/st_harness_content_snapshot.m`
- `src/harness/st_harness_import_file.m`
- `src/harness/st_import_cut_interfaces.m`
- `src/harness/st_import_harness_contents.m`
- `src/harness/st_is_harness_import.m`
- `src/harness/st_resolve_harness_import_settings.m`
- `src/harness/st_restore_import_backup.m`
- `src/harness/st_skip_import_preparation.m`
- `src/harness/st_validate_import_iterations.m`
- `src/harness/st_validate_import_mapping.m`
- `tests/integration/test_harness_import_runtime.m`
- `tests/unit/test_harness_import.m`
