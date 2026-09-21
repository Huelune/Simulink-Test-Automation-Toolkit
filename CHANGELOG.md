# Changelog

## Unreleased

- **SLDV manifest에 행이 없을 때 어느 행과 어떻게 다른지, 어떻게 고치는지 알려 줍니다.**
  `st_get_sldv_profile`은 지금까지 "No matching target row exists in the SLDV
  manifest."만 냈습니다. 이제 `SldvManifestRowMissing` 오류가 대상 행(No, CUT,
  Harness, Test Case, SldvMode)과 manifest 경로를 적고, 같은 No·CUT/Harness·Test Case를
  가진 가장 가까운 manifest 행과 다른 필드를 최대 3개까지 나열합니다. 닮은 행이 없으면
  "never prepared"(준비 당시 `Enabled=false`였던 행)로 표시하고 `st_prepare_sldv_targets`
  재실행을 안내합니다.

- **standalone 파이프라인에 실행 없이 Test File만 만드는 `Action='PREPARE'`를
  추가했습니다.** standalone 모델·Input·CVF가 이미 있고 그 모델들을 가리키는
  Test Manager 파일만 새로 필요할 때, 지금까지는 `EXECUTE`로 전체 시뮬레이션을
  다시 돌려야 했습니다. 재배선된 Test File은 번들 러너가 실행 직전에 만들어
  실행 workspace에만 남겼기 때문입니다. `PREPARE`는 `EXECUTE`와 같은 export와
  재배선을 거친 뒤 실행을 건너뛰고, 저장된 Test File을
  `<PipelineId>/TestManager/<TopModel>.mldatx`로 복사해 `info.TestManagerFile`로
  돌려줍니다.
  - 번들 러너 `run_exported_tests`에 `PrepareOnly` 옵션이 생겼습니다.
    STANDALONE_HARNESS 번들에서만 쓸 수 있고 `SaveTestResult`와 함께 쓸 수
    없습니다.
  - 실행 증거가 없으므로 같은 PipelineId의 `PACKAGE`/`SUMMARY`는
    `StandalonePipelinePrepareOnly`로 멈추고, `latest.json`을 갱신하지 않아
    `LATEST`가 되지 않습니다. `st_check_standalone_coverage`에 넘기면 `FAIL`입니다.
  - `SaveTestResult`는 지정할 수 없습니다.

- **standalone 제출물을 Test Manager에서 여는 `st_open_standalone_test_manager`를
  추가했습니다.** `open-results.md`의 수동 절차(manifest 읽기 → 대상 CUT 폴더 전부
  `addpath` → `sltest.testmanager.TestFile(TestManagerFile)` →
  `sltest.testmanager.view`)를 명령 하나로 묶었습니다. 기본 동작은 그 절차와
  같고, 모델을 로드하거나 파일을 만들거나 바꾸지 않습니다.
  - 옵션으로 켤 수 있는 것: `LoadModels`(standalone 모델 `load_system`),
    `ApplyFilters`(Test Case별 CVF 재적용과 readback 확인),
    `ImportResults`(`SaveTestResult=true`로 저장한 aggregate Result를 checksum
    확인 뒤 import). 셋을 모두 켜면 패키징된 launcher 스크립트와 같은 일을 합니다.
  - `PACKAGE`를 거치지 않은 PipelineId는 `StandaloneTestManagerNotPackaged`로,
    같은 이름의 Test File이 이미 열려 있으면
    `StandaloneTestManagerFileNameConflict`로 멈춥니다. 후자는
    `'ClearTestManager', true`로 열린 것을 모두 닫고 다시 열 수 있습니다.
  - `functionSignatures.json`에 자동완성을 등록했습니다.

- **standalone pipeline의 Simulink 빌드가 Windows 260자 제한에 걸리지 않게 했습니다.**
  번들 실행기는 `executions\<id>\workspace`로 `cd`한 뒤 Test Case를 돌리는데,
  Simulink는 `slprj`를 그 자리에 만듭니다. 짧은 출력 루트를 써도 workspace가
  150자에 가깝고 Stateflow 빌드는 그 밑에 `slprj\_sfprj\<Harness>\...`를 더
  만들어, `빌드 파일 이름이 ... 260자를 초과` 오류로 시뮬레이션이 실패했습니다.
  빌드가 실패한 Test Case는 커버리지가 없어 `ResultCoverageDataMissing`으로
  이어져 원인이 가려졌습니다.
  - 실행기가 `Simulink.fileGenControl`로 `CacheFolder`/`CodeGenFolder`를 실행마다
    짧은 폴더로 돌리고, 끝나면 원래 설정으로 되돌리고 폴더를 지웁니다.
  - 기본 위치는 `tempdir\stt_build\<id>`입니다. `cfg.StandaloneBuildCacheDir`(기본
    `''`)에 짧은 경로를 주면 그 아래에 만듭니다. `run_exported_tests`에는
    `BuildCacheFolder` 옵션으로 넘어갑니다.

- **`PER_CUT` 결과 수집이 CVF를 찾지 못하고 실패하던 문제를 고쳤습니다.**
  `st_collect_per_cut_results`는 CVF 경로를 char로 넘기는데, 커버리지 필터
  적용 함수가 `string(value(:))`로 읽고 있었습니다. char은 글자 하나가 한
  요소가 되어 `Coverage filter cannot be resolved for result data: D`처럼
  첫 글자만 이름으로 잡혔습니다. char은 `cellstr`을 거치도록 바꿔 경로 하나가
  요소 하나로 남습니다. `st_apply_result_coverage_filters`와
  `st_apply_test_case_coverage_filters` 둘 다 해당됩니다.

- **통합 보고서의 커버리지 객체 매칭을 선택할 수 있습니다.**
  `cfg.ReportMatchCoverageObjects`(기본 `false`)를 추가했습니다. `true`면
  `st_generate_test_report`가 CUT마다 그 CUT에 속한 커버리지 객체만 골라
  집계합니다. 이식용 결과 내보내기와 CUT별 최종 지표가 이미 쓰던 규칙입니다.
  - 기본값 `false`는 지금까지와 같이 CUT 행을 ResultSet의 모든 커버리지 객체로
    만듭니다. `decisioninfo`/`executioninfo`가 CUT 수 × 객체 수만큼 호출되어
    관리 Excel이 커지면 보고서에서 가장 오래 걸리는 단계가 됩니다.
  - **걸리는 시간만이 아니라 세는 대상이 바뀝니다.** 켜면 CUT 행에서 다른 CUT의
    객체가 빠지므로 커버리지 수치가 달라질 수 있습니다. 그래서 기본값을 바꾸지
    않고 선택하게 두었습니다. 기존 `TestSummary.xlsx`와 비교한 뒤 채택하십시오.
  - 켜고 만든 보고서는 실행 로그에 `Coverage | matched to each CUT`를 남깁니다.

- **고객 제출용 최종 문서를 명령 하나로 뽑습니다.** `st_export_final_document()`가
  고객 양식 시트 2장과 진단 시트 3장을 담은 Excel 하나를 만듭니다. 지금까지
  명세서 Excel, 결과 정리 산출물, `CoverageSummary.xlsx`를 열어 손으로 옮겨
  적던 일입니다.

  ```matlab
  [T, file] = st_export_final_document();
  ```

  - `TestCase` 시트는 14열입니다. `Test Case ID`(`UT_REQ_{CUT}_{ID}_{NUM}`),
    `ID`(codeBeamer ID만), `Pre Condition`(`MaxTime`), `Description`(분기 블록),
    `Test Steps.Action`, `Test Steps.Expected result`, `출력값`, `판정 결과`,
    `테스트 자료`, 그리고 고객 양식의 빈 칸 5개입니다.
  - **ID는 두 열로 나뉩니다.** `{ID}`는 테스트 케이스명 `{CUT}_{ID}`에서 CUT
    이름 접두사를 떼어 얻습니다. 마지막 밑줄 뒤를 자르면 `Motor_Ctrl_Unit`처럼
    밑줄이 있는 CUT 이름에서 틀립니다. 1열은 CUT 이름으로 다시 조립하지 않고
    시나리오명의 끝 `_{NUM}` 앞에 `_{ID}`를 끼워 넣어 만듭니다.
    `st_scenario_name`이 식별자로 쓸 수 없는 CUT 이름을 고쳐 쓰고 digest를
    붙이기 때문에, 조립하면 실제 시나리오와 어긋납니다.
  - 이름이 그 규칙과 다르면 두 열에 원문을 그대로 적고 `TestResults` 시트에
    `TESTCASE_ID_PATTERN_UNMATCHED`를 남깁니다. 손으로 만든 Test Case가 섞여
    있으면 이 경우가 나옵니다.
  - `Coverage` 시트는 CUT마다 한 줄이며 분자와 분모를 **각각 한 칸씩 숫자로**
    씁니다. `%` 열은 숫자를 박아 넣지 않고 **Excel 수식**(`=B2/C2`)에 표시형식
    `0.00%`를 줍니다. 계산된 값도 함께 저장하므로 LibreOffice처럼 열 때
    재계산하지 않는 프로그램에서도 바로 보입니다. 분모가 없거나 `0`이면 `N/A`로
    두고 수식을 넣지 않습니다.
  - `TestResults` 시트는 `TestCase`와 행이 1:1로 맞고 `확인 필요`, `확인 사유`,
    `확인 위치`를 줍니다. 고객 양식에 비고 열이 없어 진단을 여기에 모읍니다.

  **결과 정리를 먼저 해야 판정이 채워집니다.** `cfg.GenerateTestReport`가
  `false`, `cfg.PerCutResultCollection`이 `DEFERRED`이므로 실행만 하면 판정이
  파일에 없습니다. PER_CUT 뒤에는 `st_collect_per_cut_results`를, BATCH 뒤에는
  `st_generate_test_report`를 부르십시오. 안 부르면 판정이 빈 칸이고
  `TestResults` 시트에 `NOT_COLLECTED` 또는 `NOT_REPORTED` 안내가 남습니다.
  오류로 막지는 않으며, 막으려면 `RequireTestResults`를 켜십시오.

  - **이미 만든 명세서 xlsx를 읽지 않습니다.** `st_export_test_specification`과
    같은 방식으로 저장된 모델에서 다시 추출합니다. 판정과 커버리지만 기존 결과
    파일에서 읽습니다.
  - **실패한 verify의 내용은 뽑지 않습니다.** 어느 행을 봐야 하는지와 어느
    `.mldatx`를 Test Manager에서 열어야 하는지만 적습니다. `.mldatx`를 열지
    않으므로 추출이 빠르고 Simulink Test 세션에 기대지 않습니다.
  - **판정과 커버리지는 서로 다른 실행에서 옵니다.** 커버리지만 standalone
    pipeline 산출물을 씁니다. standalone은 SUT를 독립 모델로 바꾸고 기대값
    갱신을 강제로 끄므로 PASS/FAIL이 일반 실행과 다를 수 있습니다. 두 실행의
    식별자를 `Metadata` 시트에 **둘 다** 적습니다.
  - `result/TestSummary.xlsx` 복사본은 읽지 않습니다. 그 파일은 BATCH에서만
    갱신되어 PER_CUT 뒤에 읽으면 예전 BATCH 값이 나옵니다. 항상 실행 디렉터리
    안의 원본을 읽고 어느 실행이었는지 `Metadata`에 남깁니다.
  - 읽기 전용입니다. 시뮬레이션, 테스트 실행, SLDV 생성, 기대값 갱신을 하지
    않습니다. 미저장이거나 실행 중인 모델은 명세서 추출과 똑같이 거절합니다.
  - 옵션: `OutputFile`, `DecisionBlockScope`, `CoverageSource`,
    `CoveragePipelineId`, `ResultRun`, `RequireTestResults`, `RequireCoverage`,
    `IncludeUsageSheet`. 기본값은 `cfg.FinalDocument*` 네 개입니다.

- **명세서 추출의 정적 검사가 2026-09-08부터 계속 실패하고 있던 것을
  고쳤습니다.** `testExporterHasNoSimulationOrSourceMutationCalls`는
  `src/exporting`의 명세서 관련 파일에 시뮬레이션이나 원본 변경 호출이 없는지
  소스 원문에서 찾습니다. 그런데 `사용법` 탭을 추가하면서
  `st_specification_usage_table.m`에 대표 사용법 문자열
  `"st_run_from_harness('ExecutionMode','PER_CUT')"`가 들어갔고, 금지 패턴
  `\bst_run_\w*\s*\(`가 **주석과 문자열 안의 글자까지** 잡아 그때부터 이 검사가
  통과하지 못했습니다.
  - 이제 주석과 문자열 리터럴을 공백으로 지운 뒤 검사합니다
    (`tests/fixtures/st_executable_source.m`). 실제 호출은 그대로 잡고, 문서로
    적어 둔 명령 이름은 잡지 않습니다.
  - 지운 자리를 공백으로 채우므로 줄과 열이 그대로 남고, 검사가 알려 주는 위치가
    원본 파일과 어긋나지 않습니다.

- **기본 실행 방식이 `PER_CUT`이 되었습니다.** `cfg.ExecutionMode`의 기본값을
  `'BATCH'`에서 `'PER_CUT'`으로 바꿉니다. 모든 Test Case가 혼자 돌면 한 Test
  Case가 다른 Test Case에 영향을 주지 않고, 기대값을 고친 뒤에도 그 Test Case만
  다시 돌며, 결과가 CUT별 폴더로 나뉘어 남습니다.
  - `BATCH`는 그대로 있습니다. 더 빠르고 통합 보고서 하나로 끝내고 싶으면
    `st_run_after_harness('ExecutionMode','BATCH')`처럼 지정하거나
    `cfg.ExecutionMode`를 되돌리십시오.
  - **결과 정리 명령이 바뀝니다.** 기본 실행의 뒤처리는 이제
    `st_generate_test_report`가 아니라 `st_collect_per_cut_results`입니다.
    실행이 끝나면 워크플로가 그 명령을 안내하며, 이어서 자동으로 하려면
    `AutoCollect`를 쓰십시오.

- **`PER_CUT` 실행 뒤 결과 수집까지 워크플로가 이어서 하도록 할 수 있습니다.**
  `cfg.PerCutAutoCollect`(기본 `false`)와 실행 옵션 `AutoCollect`를 추가했습니다.
  `true`면 실행이 끝난 뒤 워크플로가 `st_collect_per_cut_results`를 그대로
  실행하므로 명령 하나로 CVF와 CUT별 보고서까지 끝납니다.
  - 기본값은 지금까지와 같습니다. 수집은 저장된 커버리지 데이터가 가리키는 모델을
    전부 다시 열기 때문에 시간이 걸리고, 별도 명령이어야 긴 실행을 끊어서 하거나
    다른 세션에서 이어 받을 수 있습니다. 그래서 켜는 쪽을 선택하게 두었습니다.
  - 수집이 실패하면 워크플로가 실패합니다. 수집까지 해 달라고 한 실행에서 수집
    실패를 통과로 보고할 수는 없습니다.
  - 산출물을 실행 안에서 이미 만드는 `'INLINE'` 실행에는 영향이 없습니다. 수집할
    것이 없으므로 `DEFERRED` 분기 안에서만 동작합니다.

- **BATCH 실행이 매번 터지던 것을 고쳤습니다.** CVF를 보고서 단계로 옮기면서
  `coverageFilterSession`을 만드는 줄이 사라졌는데, 그것을 쓰는 `Restore()` 호출
  세 곳이 `st_run_generated_tests`에 남아 있었습니다. 정상 경로가 그중 하나를 반드시
  지나므로 **모든 BATCH 실행이 `Undefined function or variable
  'coverageFilterSession'`으로 끝났고**, 기본 실행 방식이 BATCH이므로 기본
  워크플로 전체가 막혀 있었습니다.
  - 오류 처리 경로도 같은 변수를 건드려 원래 오류를 가리고 있었습니다.
  - 실행 중에는 필터를 붙이지 않으므로 되돌릴 것도 없습니다. 세 호출과, 그 복원만을
    위해 있던 `try/catch`, 그리고 아무도 쓰지 않게 된 `CoverageFilterApplyResult`·
    `CoverageFilterRestoreResult` 필드를 함께 걷어냈습니다.
  - 실행이 끝까지 가지 못해 `st_save_run_record`에 닿지 못했으므로, **실행 기록도
    저장되지 않고 있었습니다.**
  - 이 회귀를 잡았어야 할 `testExecutionKeepsSingleTestFileRun`은 오히려 제거된
    심볼이 남아 있기를 요구하고 있어 같이 실패했습니다. 같은 변경에서 추가된
    `testBatchRunnerNeitherFiltersNorRejectsFilters`와 정반대였습니다. 새 계약에
    맞춰 고쳤습니다.

- `st_run_from_harness`/`st_run_after_harness`가 **`FromStage='EXECUTE'`를
  지원합니다.** 준비는 이미 끝났고 테스트만 다시 돌리면 될 때, 단계 지문을 따지지
  않고 준비 단계를 하나도 실행하지 않습니다. 오래 걸리는 `ASSESSMENT`나 `SLDV`를
  건너뛰는 데 씁니다.
  - 지금까지 `EXECUTE`는 `StrictRestart`에서만 유효해서 `st_run_from_stage`를
    거쳐야 했습니다. 그쪽은 앞 단계를 읽기 전용으로 검증하고 유효하지 않으면
    중단하며, 실행 옵션을 하나도 받지 않습니다. 그냥 실행만 하고 싶을 때 치르기에
    비싼 값이었습니다. 검증이 필요하면 `st_run_from_stage`는 그대로 있습니다.
  - Harness의 `SynchronizationMode`를 바꾸는 library-link 보호 단계도 함께
    건너뜁니다. 준비의 일부이므로 실행만 하는 실행에서 모델을 건드리면 안 됩니다.
  - `ExecuteTests=false`와 같이 주면 아무 일도 하지 않는 실행이 되므로
    `simtest:ExecuteOnlyWithoutExecution`으로 막습니다. 같은 이유로 이 값일 때는
    `cfg.RunGeneratedTests=false`를 무시하고 실행합니다.
  - 자동완성(`functionSignatures.json`)이 파서와 어긋나 있던 것도 고쳤습니다.
    실행하지도 못하는 `EXECUTE`를 제안하면서 정작 기본값인 `START`는 빠뜨려,
    제안대로 고르면 `simtest:InvalidPreparationFromStage`로 막혔습니다.

- `OverwriteTestFile=true`가 실제로는 Test File 전체 재생성을 일으키지 못하고
  있었습니다. 위치 인덱스가 여덟 단계였던 시절 값으로 남아 있어, 트리거는
  `TEST_MANAGER`(6번) 대신 `ALIGNMENT`(7번)를 봤고 `7:8`을 세우면서 계획이 읽지
  않는 여덟 번째 열을 만들어 냈습니다. 그래서 **한 행이라도 Test File을 다시
  만들어야 할 때 나머지 행의 캐시된 Test Case가 함께 재생성되지 않았습니다.**
  이제 이름으로 `TEST_MANAGER`와 `ALIGNMENT`를 고릅니다.
  - 이 계열의 회귀를 막던 검사는 `dirty`와 `reasons`만 봐서 행렬 쪽에 남은 같은
    리터럴을 놓쳤습니다. `runValues`/`actionValues`/`reasonValues`까지 넓혔습니다.

- 실행 계획이 단계를 **위치가 아니라 이름으로** 표시합니다. `COVERAGE_FILTER`를
  단계 목록에서 뺀 뒤, 위치로 적어 둔 두 줄이 엉뚱한 단계를 가리키고 있었습니다.
  - Test File이 바뀌면 `dirty(7:8)`을 켰는데, 7~8은 여덟 단계일 때의
    `TEST_MANAGER`, `ALIGNMENT`였습니다. 일곱 단계가 된 뒤로는 7이 `ALIGNMENT`,
    8은 범위 밖이라 배열만 늘어났습니다. 결과적으로 **Test File을 바꿔도
    `TEST_MANAGER`가 다시 돌지 않았습니다.**
  - CVF 파일이 없으면 `dirty(6)`을 켰는데, 6은 이제 `TEST_MANAGER`입니다.
    커버리지 필터는 더 이상 준비 단계가 아니므로 이 검사 자체를 제거했습니다.
- 준비 단계에서 커버리지 필터 처리를 완전히 걷어내고 `PERSIST` 모드를 제거했습니다.
  이제 Excel의 커버리지 열 네 개는 **결과물 생성 단계에서만** 쓰입니다.
  - `st_create_test_manager`가 Test File을 저장한 뒤 필터를 붙였다 복원하던 블록을
    삭제했습니다. `RUNTIME`에서는 붙였다 바로 푸는 헛수고였고, `PERSIST`에서는
    CVF를 만들어 Test File에 박아 넣었습니다. `'DeferCoverageFilters'` 파라미터도
    함께 없앴습니다. 이제 PER_CUT만 예외로 둘 이유가 없습니다.
  - `cfg.CoverageFilterApplicationMode`와 `st_coverage_filter_application_mode`를
    제거했습니다. `PERSIST`는 필터를 Test File에 남겨 실행이 필터를 걸고 돌게
    하므로, "실행은 커버리지를 필터 없이 수집한다"와 정면으로 어긋납니다. 적용은
    언제나 임시입니다.
  - 커버리지 열이 `TEST_MANAGER` 지문에서 빠졌습니다. 준비 단계가 더 이상 그
    값을 읽지 않으므로, 필터 설정을 바꿔도 Harness나 Test File을 다시 만들지
    않습니다. 다음 결과물 생성에만 반영됩니다.
  - `st_verify_all`의 `CURRENT.COVERAGE_CONFIG` 검사에서 적용 모드 항목을
    뺐습니다.
- 실행 방식은 이제 **부르는 쪽이 정합니다.** Excel은 관여하지 않습니다.
  `cfg.ExecutionMode` 기본값이 `'AUTO'`에서 **`'BATCH'`**로 바뀌었고, 한 번만
  달리 돌리려면 명령에서 지정합니다.

  ```matlab
  st_run_after_harness('ExecutionMode', 'PER_CUT')
  ```

  - `'AUTO'`를 제거했습니다. 활성 CVF를 가진 대상이 하나라도 있으면 `PER_CUT`을
    고르는 규칙이었는데, 커버리지 필터가 결과물 생성 단계로 옮겨가면서 근거가
    사라졌습니다. 전달하면 `simtest:RemovedExecutionMode`로 대체 값을
    안내합니다. 조용히 `BATCH`로 바꾸면 기존 프로젝트의 실행 방식이 말없이
    달라지기 때문입니다.
  - `PER_CUT`은 **혼자 돌려야만 되는 Test Case**를 위해 씁니다. 남은 차이는 실행
    단위와, 기대값 갱신 후 재실행 범위입니다. `BATCH`는 Test File 전체를,
    `PER_CUT`은 해당 Test Case만 다시 돌립니다.
  - `CoverageFilterMode`/`CoverageBoundaryMode`는 실행 방식과 무관해졌습니다.
- BATCH 실행에서도 커버리지 필터를 걷어냈습니다. 이제 CVF는 어느 실행 경로에서도
  만들어지지 않습니다. 실행은 커버리지를 필터 없이 수집하고,
  `st_generate_test_report`가 CVF를 만들어 결과에 붙인 다음 보고서를 만듭니다.
  - `st_run_generated_tests`가 실행 직전에 부르던 `st_prepare_coverage_filters`와
    `st_apply_test_case_coverage_filters` 호출을 제거했습니다.
  - `simtest:BatchExecutionWithCoverageFilter`가 사라졌습니다. 활성 CVF를 가진
    대상을 BATCH로 돌리는 것을 막던 규칙인데, 실행 중에 모델을 필터링해야 했기
    때문에 있던 제약입니다. 이제 그런 일이 없으므로 막을 이유가 없습니다.
  - `AUTO`는 여전히 활성 CVF가 있으면 `PER_CUT`을 고릅니다. 다만 이건 **선호이지
    제약이 아닙니다.** 같은 대상을 `'BATCH'`로도 돌릴 수 있습니다.
  - 두 방식의 남은 차이는 실행 단위와 재실행 단위입니다. BATCH는 기대값 갱신 후
    Test File 전체를 재실행하고, PER_CUT은 해당 Test Case만 재실행합니다.
- `PER_CUT` 실행에서 커버리지 필터 처리를 결과물 생성 단계로 옮겼습니다.
  `PER_CUT`은 혼자 돌려야만 되는 Test Case를 위해 있는 것이고, CVF는 실행에
  필요한 것이 아니라 실행 결과로 만드는 산출물의 커버리지 데이터를 다듬는
  것입니다. 그래서 실행은 각 Test Case를 필터 없이 돌리고 ResultSet만 저장한 뒤
  끝납니다.
  - 새 명령 `st_collect_per_cut_results`가 저장된 ResultSet에서 CVF를 만들고
    부착한 다음 CUT별 보고서를 씁니다. 각 CUT 폴더의 `filter/`, `initial/`,
    `final/` 구조는 그대로입니다.
  - 새 설정 `cfg.PerCutResultCollection` (기본 `'DEFERRED'`). `'INLINE'`은
    예전처럼 실행 안에서 전부 처리합니다.
  - standalone 번들은 항상 `'INLINE'`입니다. 번들의 실행 모델은 일회용이라
    나중에 다시 열어서 CVF를 붙이거나 커버리지를 렌더링할 수 없습니다. 즉
    standalone은 EXECUTE가 곧 결과물 생성 단계입니다.
  - 실행 중 모델에 필터를 걸었다가 복원하는 절차가 기본 경로에서 사라지므로,
    `st_check_per_cut_cvf`의 B2 비트는 `OK/NOT_REQUIRED/NOT_REQUIRED`도
    정상으로 봅니다. 적용과 복원은 살아 있는 모델을 필터링할 때의 개념이고,
    이연된 실행은 둘 다 하지 않습니다.
- 테스트를 실행하는 것과 결과를 정리하는 것을 분리했습니다. `st_run_from_harness`와
  `st_run_after_harness`는 준비 → 실행 → 기대값 갱신 → 재실행까지 하고 끝납니다.
  그다음은 두 갈래입니다. Harness를 독립 모델로 내보내 제출물을 만드는
  `st_run_standalone_coverage_pipeline`, 또는 Harness를 내보내지 않고 결과만
  정리하는 `st_generate_test_report` → `st_export_test_asset_bundle`입니다.
  - Test Manager의 ResultSet은 그것을 만든 세션 안에서만 살아 있어서, 통합
    보고서는 테스트를 실행한 그 세션만 만들 수 있었습니다. 이제 실행이
    `result/run_records/{id}/`에 INITIAL/FINAL ResultSet과 표를 저장합니다.
    재실행이 없었으면 두 라벨이 같은 ResultSet을 가리키므로 파일 하나만 남깁니다.
  - `st_generate_test_report('RunRecord','LATEST')`가 저장된 기록에서 보고서를
    만듭니다. 인자 없이 불러도 같습니다. 기존 3인자 형태는 workflow가 쓰는 live
    경로로 남습니다.
  - `cfg.GenerateTestReport` 기본값이 `true`에서 **`false`로 바뀌었습니다.** 실행
    기록은 이 값과 무관하게 항상 저장하므로, 예전처럼 실행 직후 보고서가 필요하면
    `true`로 두면 됩니다.
  - 보고서가 아직 없을 때 `st_export_test_asset_bundle`과 `st_export_test_bundle`의
    오류 메시지가 무엇을 먼저 실행해야 하는지 알려 줍니다. `st_verify_all`의
    LATEST_REPORT 검사는 실행 기록이 있으면 그 사실을 함께 보고합니다.
  - `PER_CUT` 실행은 그대로입니다. 실행 중에 `result/per_cut_runs/`에 자체 보고서를
    쓰므로 이 경로를 쓰지 않습니다.
- `COVERAGE_FILTER`는 더 이상 준비 단계가 아닙니다. 커버리지 필터는 실행하는
  쪽이 만듭니다. `BATCH`는 `st_run_generated_tests`가 실행 직전에, `PER_CUT`은
  `st_run_tests_per_cut`이 CUT 폴더 안에서, standalone 파이프라인은 내보낸 번들
  안에서 생성합니다. 준비 단계가 만들던 공유 CVF는 어느 경로에서도 쓰이지
  않았습니다. `BATCH`는 실행 직전에 계획을 무시하고 전 행을 다시 만들었고,
  `PER_CUT` 단계는 파일을 하나도 만들지 않는 기록용이었으며, standalone은
  `CoverageFilterExistingPolicy=REPLACE`를 강제해 물려받은 CVF를 의도적으로
  버립니다.
  - 단계 어휘, 실행 계획, 재시작 경계, readiness 검사에서 단계를 제거했습니다.
    기록 전용이던 `st_defer_coverage_filters_to_per_cut`은 삭제했습니다.
  - 필터 설정은 `PERSIST`일 때 Test File에 기록되므로 `TEST_MANAGER` 지문에
    넣었습니다. Rationale만 바꿔도 Test File이 다시 만들어집니다. 지문 구성이
    바뀌었으므로 이 변경 이후 첫 실행에서 `TEST_MANAGER`와 `ALIGNMENT`가 한 번
    다시 돕니다.
  - `FromStage='COVERAGE_FILTER'`와 Excel의 `PreparationFromStage=COVERAGE_FILTER`는
    `simtest:RemovedPreparationStage`로 거절하고 `TEST_MANAGER`를 안내합니다.
    조용히 다른 단계에서 시작하지 않기 위해서입니다.
  - `st_prepare_coverage_filters`는 필터 내용을 미리 보는 단독 명령으로 남습니다.
- A workflow whose Test Manager stage is fully cached no longer fails right
  after the stage reports DONE. When no row needs the stage,
  `st_create_test_manager` returns before any Test File is opened and builds
  its own result table, but it built that table without a column name list,
  so MATLAB named the columns `Var1`..`Var9`. `st_checkpoint_workflow_state`
  looks for `Status` there and rejected the stage it had just skipped with
  `simtest:InvalidStageResult`. The cached table now declares the same names
  the full result uses. Every other stage already did.
- FILE mode no longer writes its Signal Editor scenarios to a sibling MAT
  named after the data format. The scenarios go into the Harness input the
  block already points at, so no `*_sldv.mat` or `*_mat.mat` appears beside
  it. The workbook's own data file is still never written; a target that
  resolves to it falls back to a `_prepared` sibling. A Harness prepared
  before this change keeps pointing at its old `*_sldv.mat` until the
  Harness is recreated.
- A scenario name is now derived so that it stays a valid MATLAB identifier.
  The name becomes a Test Sequence and Signal Editor identifier, but the CUT
  name it is built from is free text, and it broke that contract two ways at
  once: a character an identifier cannot hold, such as the `/` in a block
  named `..._AC/DC_Check`, and a length past `namelengthmax`. A 62-character
  CUT name already produces 73 characters with the prefix and index, so
  replacing the character alone never got under the limit.
  - A name that already fits is returned byte for byte as before, so every
    scenario, Harness and Test File built so far keeps its identifier.
  - Otherwise every character outside `[A-Za-z0-9_]` becomes `_`, and if the
    result is still too long the stem is cut to fit with a six-digit digest
    appended. The digest is taken from the original CUT name, so two CUTs
    that shorten to the same stem keep distinct scenarios, and the result is
    stable across sessions so a rerun still matches what the Harness holds.
- A CUT whose block name contains `/` is now reachable from the workbook.
  Simulink writes such a name doubled in a block path, so the block actually
  named `OBC_..._AC/DC_Check` lives at `.../OBC_..._AC//DC_Check`. A CUTPath
  cell typed or pasted from the block name carries a single slash, which
  resolves against nothing and takes the whole row down before any stage runs.
  - `st_load_targets` now escapes the trailing name while loading, where the
    CUTName and CUTPath columns are both in hand. CUTName states exactly where
    the leaf name begins, so only that trailing occurrence is rewritten and
    every separator above it is left alone. A path that is already escaped, a
    name without a slash, or a path that does not end with the name are all
    returned untouched, and the result is still validated against Simulink by
    `st_normalize_cut_path`.
  - `st_find_target_paths` applies the same rewrite to the existing cell, so a
    row written without the escaping is reused instead of being reassigned.
  - A slash inside a *parent* name is still out of scope: no column states
    where those names begin or end. Use `st_export_subsystem_paths`, which
    takes its paths straight from `find_system` and is escaped throughout.
- Added `st_probe_cut`, a read-only diagnostic that answers whether one CUT
  exists. It delegates resolution to Simulink rather than splitting paths on
  `/`: `getSimulinkBlockHandle` for the query as typed, then a comparison
  against the raw `get_param(block,'Name')`, then a walk that consumes the
  query using the child names Simulink reports. On failure it names the level
  where the path stopped matching and lists that block's children, and it
  separates the remaining causes — letter case, surrounding whitespace, a line
  break inside a name, a library link that only `FollowLinks','on'` reaches,
  and referenced models that are outside the search.

- A Test Case whose Iterations only partly succeed now still gets its expected
  values updated. A Test Case owns one Iteration per Test Sequence scenario, and
  the verify-timing validation that runs before the update used to abort the
  whole run as soon as a single scenario failed. An Iteration that died with an
  error records no verify result, so two broken Iterations out of three stopped
  the third — the one that ran correctly and needed its `verify(... == RHS)`
  rewritten — from ever being reached. Behaviour change, no new option:
  - Verify timing aborts only when every evaluated scenario failed. A mixed
    outcome warns and continues, so the healthy scenarios reach the update.
  - The expected-value update no longer raises
    `simtest:PerCutExpectedUpdateFailed` when one scenario could not be
    updated. The scenarios that were updated are kept and rerun. BATCH and
    PER_CUT now react identically; previously one errored and the other warned.
  - A partial run is judged `PARTIAL`, never a pass. BATCH reports it in
    `runContext.Status` alongside `VerifyTimingStatus` and
    `ExpectedUpdateStatus`; PER_CUT adds `VerifyTimingStatus` and
    `ExpectedUpdateStatus` columns per target, a `PartialTargetCount` in
    `manifest.json`, and a `PARTIAL` run status.
  - An Iteration whose Outcome is not `Failed` is still skipped, because a
    simulation that died mid-run has no trustworthy sample to copy. The reason
    is now recorded as `SKIP_OUTCOME_NOT_FAILED` with the observed Outcome
    instead of the bare `Iteration is not Failed`.
- Added `functionSignatures.json` for the commands people type, so MATLAB
  tab-completes their option names and the allowed values (`Action`,
  `FromStage`, `ExecutionModelMode` and so on). Completion is editor-only
  and changes no behaviour; the files live beside the functions they
  describe, which is the only place MATLAB looks.
- Removed the named model profile feature. Target selection is back to the
  single `runtime_target.mat` path that `st_select_target_model` writes, and
  `cfg.ActiveModelProfile` is gone. A `model_profiles.mat` left on a machine
  is now inert; a machine that had a profile active falls back to the
  default result paths, so earlier results under the profile's OutputRoot
  are not picked up automatically.
- A D number now counts a branch rather than a block. An If block spends one
  on its if condition and one on every elseif, because Simulink Coverage
  counts them separately and a single pooled line could not be compared with
  the objective count. The block name is written once and the D lines follow
  beneath it. The implicit else is not listed: it is the absence of every
  condition rather than a condition of its own, so an If block takes exactly
  as many D numbers as it has conditions. ElseIfExpressions is split on
  commas at bracket depth zero, so a condition such as `min(u1, u2) > 0`
  survives intact.
- Switch Case now prints `D<n> [T/F]SwitchCase` with no condition in the main
  cell, since the case list is long and says little on one line. The saved
  CaseConditions stay in the Expression column of DecisionBlockDetails. Which
  types behave this way is the new `MainExpression` column of the catalog,
  and a type the catalog does not know still prints its expression so that
  re-formatting an older workbook loses nothing.

- Documented why Coverage filter rules show `n/a` in the name column: the
  rules address blocks by SID, which the viewer resolves against a loaded
  model. Opening the standalone model that sits beside the CVF fills the
  names in; the original Top Model does not, because standalone models do
  not reuse its SIDs.
- Packaged standalone Coverage artifacts now carry a `UT_REQ_` prefix:
  `{NUM}_UT_REQ_{TestCaseName}` target folders holding
  `UT_REQ_{TestCaseName}.cvf`, `.cvt` and `.html`. The stem comes from the
  new `st_artifact_stem`, which every producer and the checker share so the
  names cannot drift apart; prefixing is idempotent and stays inside the
  80-character cap. Harness, standalone model and input MAT names are
  unchanged. Deliveries packaged before this change no longer satisfy the
  checker and must be produced again.
- `DecisionBlocks` can now inventory the block types that create Simulink
  Coverage objectives without looking like a decision: Saturate, Abs,
  DeadZone, RateLimiter, Relay, Lookup_n-D, Interpolation_n-D, PreLookup,
  Integrator, DiscreteIntegrator, ForIterator, WhileIterator and Logic sit
  next to If/Switch/MinMax/MultiPortSwitch/SwitchCase under the same
  D-numbering. A CUT with no If or Switch block could already report Decision
  coverage and the specification never said where it came from. Masked blocks
  such as Saturation Dynamic and Unit Delay Enabled report BlockType SubSystem
  and stay out of a SearchDepth=1 BlockType scan, as do the control ports of a
  child Enabled or Triggered Subsystem.
- How much of that inventory to write is selected by `DecisionBlockScope`:
  `EXPLICIT` (the default) keeps the original five dialog-condition blocks,
  `ALL` adds the implicit ones above, and `NONE` leaves the column empty and
  skips the scan. `cfg.DecisionBlockScope` sets the project default and
  `st_export_test_specification('DecisionBlockScope','ALL')` overrides one
  run. The scope is a view over the catalog selected by its `Kind` column, so
  the scan itself knows nothing about scopes and an empty catalog is the
  `NONE` view rather than a fault. An empty cell reads the same in Excel
  whether the scope was `NONE` or the CUT had no blocks, so the export start
  log now records the scope it ran with.
- The `DecisionBlocks` cell on the TestSpecification sheet now always prints
  `[T/F]`, and the specific branch kind moved to the `Outcome` column of
  DecisionBlockDetails. The main sheet says where the branches are, the detail
  sheet says what kind they are. MinMax and Multiport Switch used to print
  `[SELECT]` and Switch Case `[CASE]` in the main cell; those rows now read
  `[T/F]` and keep `SELECT` and `CASE` in the detail sheet. Outcome tokens are
  no longer rendered inline, so they were renamed for legibility and grouped by
  branch kind rather than by block: LIMIT, BAND, RATE, ON/OFF, SIGN, INTERVAL,
  LOOP and CONDITION.
- Blocks whose branch parameters are inactive are listed rather than filtered.
  An Integrator with `LimitOutput=off; ExternalReset=none` appears with that
  state in its expression. The column is a static inventory of candidates and
  claims no objective count, so filtering on saved parameters alone would be
  wrong whenever the data type or optimization settings decide the outcome.
  Breakpoint parameters are copied as saved text and never resolved in a
  workspace, so a lookup table configured from a variable shows the variable
  name.
- Block type knowledge moved into `st_specification_decision_catalog`. The scan
  list, the outcome token, the failed-read fallback outcome and the display
  alias were four literal copies of the same table, and the fallback copy only
  ran when an expression read had already failed, so drift there was invisible.
  Adding a type is now one catalog row, and only a type whose expression needs
  special assembly still touches `st_specification_decision_descriptor`.
- File hashing now reads on the Java side instead of copying every chunk
  through MATLAB. The cost was never SHA-256 itself but marshalling the
  bytes across the boundary, which dominated delivery verification once a
  project had hundreds of targets. Files above 256 MB still stream through
  the chunked reader, which also remains the fallback.
- Added scoped warning suppression. `cfg.SuppressedWarnings` lists the
  identifiers to silence while the standalone Harness export drives its
  per-target loop; they are logged once and the caller's warning state is
  restored afterwards. Bare words are rejected so a typo cannot widen into
  suppressing everything. `st_collect_warning_ids` gathers the identifiers
  a run actually emits, which `lastwarn` cannot do.
- `st_check_standalone_coverage` now understands `ExecutionStatus=EXCEPT`.
  A target whose Test Case raised an exception keeps only its standalone
  Harness and input, so it is judged against that reduced contract, the
  expected CVF/CVT/HTML counts exclude it, and an Action WARN explained
  entirely by excepted targets no longer zeroes the manifest bit for every
  target. Such a run reports PARTIAL with an EXCEPT row, never PASS.
  Result filtering and coverage metrics are reported as not applicable for
  an excepted target, while cleanup stays enforced so a leaked execution
  model or an unrestored MATLAB path is still a failure.
- `st_check_standalone_coverage` now scans for forbidden artifacts with a
  single recursive listing instead of five patterns per target directory.
  The unzipped Coverage report puts hundreds of companion assets in every
  target root, so the old scan repeated that walk 5*(targets+1) times.
- The standalone coverage pipeline and the verification snapshot no longer
  run the toolbox dependency analysis. Both build an internal bundle that
  is executed in place rather than delivered, so the informational product
  list never repaid loading every dependency model.
- Added `st_export_test_bundle('AnalyzeProducts', false)` to skip the
  toolbox dependency analysis, which loads every dependency model and can
  outlast the rest of the export. `RequiredProducts` is a bundle README
  hint that no code reads back; the manifest policy records whether the
  analysis ran.
- Standalone Harness export now reports progress. Each target prints a
  start line, the elapsed time of its source-copy save, Harness export and
  standalone save, and a completion line; reused targets are named instead
  of silently skipped. ZIP archiving reports the bundle size first.
- Bundle manifest export now reports what it is doing. Toolbox dependency
  analysis, whole-bundle SHA-256 hashing, and the source-unchanged recheck
  each log a start/complete checkpoint with elapsed time, and the hashing
  loop prints progress every five seconds.
- Fixed standalone Harness export failing to re-identify a library-linked CUT.
  `find_system` defaults stop at a link boundary, so a CUT inside a library
  link reported no ports while its exported copy reported the real ones, and
  the interface could never match. Both sides now resolve links and masks, and
  the failure message lists the candidate blocks with their link status.
- Standalone Harness export no longer runs dependency analysis over every
  branch of the source Top Model. It analyses the generated standalone
  models, copies their union of dependencies, and leaves the configuration
  Top Model unloaded during replay. Actual standalone dependency gaps still
  fail the export rather than producing a partial delivery.
- Added local named model profiles, a generated anonymous FILE/MAT example,
  read-only `st_check_readiness`, and strict `st_run_from_stage` execution.
  Valid predecessors are inspected and reused; invalid predecessors block
  instead of being repaired implicitly. Preparation checkpoints now preserve
  independent input/output readbacks and incomplete-stage status.
- Added hash-verified PACKAGE/SUMMARY regeneration into a new v3 PipelineId,
  recording source provenance and zero new test executions. Existing Action
  once-per-PipelineId rules and v2 reads remain supported. Failed/partial
  derivatives do not replace latest; missing saved evidence blocks regeneration.
- Added Korean task runbooks, behavior tests and disposable R2025b restart
  acceptance cases. Local MATLAB is unavailable; runtime validation is pending.

- Packaged standalone Coverage artifacts now use the safe Test Case name:
  `{TestCaseName}.cvf`, `{TestCaseName}.cvt`, and `{TestCaseName}.html` at the
  target root. The original `cvhtml` report binds a matching short filter name
  so the HTML names the CVF that sits beside it, and the validated absolute CVF
  binding is restored before final metric extraction.
- Fixed the per-CUT Coverage report filter helpers being nested inside
  `capture_package_evidence`, which left them unreachable from the report
  subfunctions that bind and restore the CVF.
- CoverageSummary.xlsx now reports the Decision and Execution objective counts
  next to each percentage (`Decision Executed`, `Decision Total`,
  `Execution Executed`, `Execution Total`). `st_check_standalone_coverage`
  verifies the eleven-column set and the Test Case artifact names.
- Fixed standalone Coverage packaging after per-CUT model cleanup. Each
  original Coverage `cvhtml` report, CVT, and final metric snapshot is now
  captured while its execution model is still open; PACKAGE verifies and
  promotes that evidence without serializing detached Coverage objects. PACKAGE also clears
  a cached prior helper and verifies its active-project implementation contract
  before promotion, preventing mixed revisions in long-lived MATLAB sessions.
- Generate the original Coverage HTML entirely in a short writable scratch
  directory before promoting its ZIP. This avoids the Windows legacy path
  boundary that made long per-CUT names fail with a misleading read-only
  current-directory error.
- Package a Test Manager launcher that resolves CUT-specific standalone
  models and applies each packaged CVF before opening the rewired MLDATX.
  Evidence capture now rechecks that every active coverage object still holds
  the CVF used by the original `cvhtml` report.
- Fixed `st_check_standalone_coverage` returning a 1-by-10 struct array. Its
  ten bit values now remain one field of a scalar summary struct.
- PACKAGE target manifests now preserve the exception identifier, message, and
  call stack; checker details surface the first failing source location.
- Treat a matched CUT with no remaining Coverage objectives as the valid
  zero-denominator metric (`0/0`, `N/A`) instead of an incomplete package.
- Replaced the standalone coverage `STEP*` interface with the default
  `ALL` workflow and explicit `EXECUTE`, `PACKAGE`, and `SUMMARY` actions.
  Each copied Test Case now runs once before one Result CVF registration;
  live results avoid serialization in `ALL`, staged execution optionally
  persists one aggregate Result, packaging emits one CVT and HTML report per
  CUT, and `st_check_standalone_coverage` provides a read-only 10-bit summary.
- Protected library-linked CUTs during Harness creation and reuse. Linked CUT
  Harnesses now use one-way `SyncOnOpen` synchronization, link status and
  reference identity are checked around create/clone operations, and automatic
  Atomic conversion fails safely instead of modifying a linked block. Ordinary
  `FILE+MAT` input no longer requests an SLDV-only Atomic conversion.
- Temporarily allow `FILE+SLDV` MAT files whose recorded subsystem path differs
  from the configured CUT when `cfg.AllowSldvSubsystemPathMismatch=true` (the
  default), while logging a warning and retaining Harness input-interface checks.
- Targets with no usable Harness output now configure an empty verify action and
  report `SKIP_NO_VERIFY_OUTPUT` during verify-timing validation and expected-value
  update. Missing or untested verify results still fail when an output exists.
- Extended `SldvMode=FILE` with explicit `DataFileFormat=SLDV|MAT` and optional
  `MatVariableName`. Ordinary MAT Dataset scenarios are selected deterministically,
  checked for exact interface and time consistency, copied to Signal Editor input,
  and skip SLDV-only parameter processing. Existing workbooks default to `SLDV`.
- Fixed nested-cell `dataNoEffect` handling and centralized Dataset interface
  inspection on the documented `getElementNames` API.
- Fixed specification workbook writing when MaxTime is NaN or text is missing.
  Overflow checks now preserve numeric cells and normalize missing strings to
  empty cells before character conversion.
- Specification export now defaults to the direct Assessment `step2` verify.
  `VerifyMode=ALL_STEPS_COLUMNS` puts each verify-bearing step in a separate
  column. Partial step/transition failures preserve readable verify content,
  and both modes retain full step details and per-step diagnostics.
- Added a numeric `MaxTime` specification column with the input scenario's
  maximum stored signal time in seconds; unavailable times remain blank in Excel.
- Fixed specification-export cleanup after an early error: cleanup callbacks
  now capture their arguments instead of reading cleared nested-workspace
  variables. Unsaved-model rejection still preserves the user's changes.
- Added `st_export_test_specification` to export every saved Assessment scenario
  without test execution. Input last samples are expanded into scalar array/bus
  paths; simple verify equalities become path/value lines. Wrapped Excel cells,
  original step/transition details, lossless overflow, and source guards are included.
- Added the read-only `st_check_actual_system` field diagnostic. It combines
  six environment checks, six PER_CUT run checks, and the existing six CVF
  checks into one transferable 18-bit result code with detailed tables.
- Fixed `st_check_per_cut_cvf` so a diagnostic no longer relies on the
  runtime-target helper that could load a model before its original open
  state was recorded.
- Changed automatic CVF generation to exclude the CUT root and create rules
  only for its direct-child Subsystems. `SUBSYSTEM` uses `BlockInstance`, while
  descendant filtering remains exclusive to `ALL_CONTENT`.
- Added the read-only `st_check_per_cut_cvf` R2025b diagnostic, which reports
  per-target and aggregate six-bit codes for artifact integrity, lifecycle,
  rule count, CUT exclusion, direct-child matching, and mode/action matching.
- Moved PER_CUT result serialization until after transient filter restore
  and added before/after ResultSet coverage integrity checks around MLDATX,
  CVT, CVF-copy, and HTML creation.
- Removed the editable target-model placeholder from tracked configuration.
  Local model name and file path now come only from the Git-ignored
  `runtime_target.mat` created by `st_select_target_model`.
- Fixed a PER_CUT regression where post-run mutation of `cvdata.filter`
  could make Test Manager Coverage Details fail to open. Generated filters
  are now registered through Test Manager for the run, while report export
  copies the CVF without relinking the live result object.
- Fixed PER_CUT ResultSet traversal for direct `run(testCase)` results,
  attached absolute CVF paths to result coverage data, changed each CVF name
  to `{TestCaseName}.cvf`, validates the generated rules after saving,
  and removed Java path canonicalization from result-filter verification.
- Added portable PER_CUT coverage artifacts: standalone detail HTML,
  reloadable CVT data, and copied CVF files while preserving their sources.
- Made result coverage filter verification compatible with MATLAB releases
  that return only the CVF basename or omit the `.cvf` extension on readback.
- Changed `SUBSYSTEM` coverage filtering to use each direct-child Subsystem's
  `BlockInstance`, so the CUT root and descendant primitive blocks remain
  included.
- Added the default PER_CUT `REPLACE` existing-filter policy, which temporarily
  suppresses inherited Test File, Suite, and Test Case CVFs and restores them
  after applying the newly generated Test Case CVF in isolation.
- Applies each PER_CUT CVF through Test Manager during its isolated run. The
  direct-child `BlockInstance` rules keep descendant coverage for `SUBSYSTEM`,
  and portable output copies the CVF without mutating the live Test Manager
  result.
- Fixed incremental SLDV preparation so `OFF` and legacy cached profiles
  use the same canonical structure schema as newly generated profiles.
- Added `AUTO`, `BATCH`, and `PER_CUT` execution policies. Active coverage
  filters now select sequential per-CUT execution for every enabled row while
  all-OFF workbooks retain the legacy `run(tf)` path.
- Added transient CVF sessions with exact Test File, Test Suite, and Test Case
  filter restoration checks, PERSIST rollback, and immediate abort when a
  filter cannot be restored safely.
- Added separate `result/per_cut_runs` bundles and `per_cut_latest.json`, with
  per-target CVF hashes, manifests, initial/final ResultSets, Excel summaries,
  lightweight or full coverage HTML, and optional official PDF reports.

- Added Excel-driven per-Test-Case coverage filters with `OFF`, `SUBSYSTEM`,
  and `ALL_CONTENT` selection, `EXCLUDE`/`JUSTIFY` actions, required
  rationale, API-only `RUNTIME` or `PERSIST` application, managed CVF
  cleanup, incremental workflow checkpoints, and integrated report metadata.
- Changed CUT path discovery to enforce one-to-one subsystem assignment,
  remove already claimed paths from later recommendations, reject duplicate
  existing ownership, and update the management workbook only after every
  selected path passes final validation. Excel row context no longer
  hard-filters candidates.
- Added one-to-one Signal Editor template mapping for existing multi-scenario
  MAT files such as `TestCase_1`, `TestCase_2`, preserving each scenario's
  Harness-only inputs while importing matching SLDV test cases.
- Fixed incremental SLDV cache reuse so `CACHED` remains a report-only
  status, successful manifest profiles stay `OK`, and manifests written by
  the previous behavior are recovered automatically.
- Fixed SLDV verify-result validation to export each complete Verify Run as
  a Dataset and to keep result-table columns aligned when a scenario fails
  before verify counts are available.
- Changed SLDV target preparation so both `FILE` and `GENERATE` modes convert
  non-atomic CUTs to persistent Atomic Subsystems by default, controlled by
  `cfg.AutoConvertSldvTargetsToAtomic`, with the action recorded in results.
- Added the dry-run-first `st_cleanup_results` operator command for scoped
  cleanup of known generated artifacts below `result/`.
- Added a start-to-cleanup operator manual covering public commands,
  prerequisites, side effects, outputs, recovery, and result retention.
- Added `cfg.CheckSharedSignalEditorDataFile = false` as the default so SLDV
  preparation skips the potentially slow all-Harness Signal Editor MAT
  ownership scan, while retaining an explicit opt-in safety check.
- Added a step-by-step Korean user manual for verification setup, recommended
  QUICK/RUNTIME/CERTIFY operation, manual evidence, result interpretation,
  troubleshooting, and final R2025b certification.
- Added `st_verify_all` with `QUICK`, `RUNTIME`, and `CERTIFY` profiles,
  normalized PASS/FAIL/BLOCKED/SKIP/WARN results, feature-catalog coverage,
  manual evidence validation, and Excel/JSON/JUnit output.
- Added execution-local fixture generation for scalar, numeric array, nested
  Bus, Bus array, no-Inport, and SLDV branch targets without tracking binary
  fixtures in Git.
- Added isolated current-model verification that reuses the export collector,
  hashes source dependencies and inputs, and runs only fresh workspace copies.
- Added certification checks for expected-value APPLY/OFF, SLDV GENERATE/FILE,
  cache reuse, corrupt-state recovery, preparation failure isolation, integrated
  reports, coverage, bundle checksums, template immutability, and repeat runs.

- Added standalone reproducible test bundle export with saved internal Harness
  models, analyzed dependencies, target inputs, Test File definitions, reference
  reports, SHA-256 inventory, and an optional ZIP archive.
- Added an exported runner that validates the bundle and creates a fresh mutable
  workspace for each rerun while preserving the source project and bundle
  template, plus a beginner-oriented Korean bundle README.

- Added target-level incremental preparation with `AUTO`/`FORCE` policies,
  stage checkpoints, input fingerprints, and atomic MAT/JSON state files.
- Added optional `PreparationMode` and `PreparationFromStage` Excel columns
  with call option, row, and global configuration precedence.
- Added cross-run SLDV manifest profile reuse while preserving direct no-arg
  behavior for each existing `st_*` preparation command.
- Added per-run integrated report bundles with initial/final Test Manager
  results, official PDF, raw MLDATX, coverage HTML, manifest, and Excel summary.
- Added Decision and Block Execution coverage extraction at overall CUT,
  Test Case, and Iteration levels, including justified outcomes, `N/A` for a
  zero denominator, and checksum-safe weighted aggregation.
- Added `result/latest.json` and latest Excel summary updates without external
  publishing or coverage-threshold failure enforcement.

- Connected the project to the `Huelune/Simulink-Test-Automation-Toolkit` repository while preserving its initial MIT license commit.
- Added explicit expected-value policy with `cfg.ExpectedUpdateMode = 'APPLY'` as the project default.
- Added optional per-row `ExpectedUpdateMode` values (`DEFAULT`, `OFF`, `APPLY`) to the `Targets` sheet.
- Limited expected-value logging preparation and mutation to rows resolved to `APPLY`.
- Documented the repository artifact policy, target package structure, and deferred decisions.
- Reorganized MATLAB sources by responsibility under `src/`, moved diagnostics and unit tests to dedicated folders, and preserved historical handoff files under `docs/archive/`.
- Added a root resolver so configuration and diagnostic paths remain stable after source files move.

## v0.9.6 Candidate

- Added optional filtering for SLDV Dataset inputs that are absent from the Harness ActiveScenario. `cfg.IgnoreUnexpectedSldvInputs=true` drops those inputs while assembling Signal Editor scenarios and records the ignored names and count; strict failure remains the default.
- Added optional automatic atomic CUT setup for `SldvMode=GENERATE`. With `cfg.AutoEnableAtomicForSldvGenerate = true`, a non-atomic Subsystem is changed to `TreatAsAtomicUnit=on` only around `sldvrun`, then its original setting and the model Dirty state are restored.
- Updated SLDV input handling to use the Harness Signal Editor `ActiveScenario` as the interface template. SLDV Dataset inputs may be a compatible subset; Harness-only external inputs are retained in every generated scenario, while unexpected SLDV inputs fail before mutation.
- Removed the SLDV direct-CUT-Inport gate from Signal Editor and Test Manager setup. SLDV Iterations now always bind both `SignalEditorScenario` and `TestSequenceScenario` to the matching `UT_REQ_*` name.
- Extended scenario alignment validation to check both Iteration scenario parameters in addition to scenario names and counts.
- Treat the initial Signal Editor `InputScenario`/template Scenario after linking a new MAT file as a normal intermediate state. The linked template is renamed and populated with `UT_REQ_*` scenarios only after the Filename refresh completes.

- Added row-level `SldvMode` (`OFF`, `FILE`, `GENERATE`) and `SldvDataFile` management columns with backward-compatible `OFF` defaults.
- Added SLDV generation using a deep copy of the Top Model Design Verifier settings, target-specific latest-result storage, and success-only replacement of generated data files.
- Added preflight validation for subsystem ownership, effective test cases, time vectors, Dataset interfaces, direct CUT Inports, iteration parameter metadata/application, and shared Signal Editor MAT files.
- Added one-to-one SLDV TestCase expansion into Signal Editor scenarios, Assessment scenarios, and Test Manager table iterations named `UT_REQ_{CUTName}_{NNN}`.
- Applied CUT-level `Tmax` to Harness StopTime, every Assessment transition, and expected-value sampling, while holding shorter Signal Editor inputs at their final values.
- Added per-iteration SLDV parameter overrides and targeted iteration reset for existing SLDV Test Cases.
- Added verify-run timing validation that reports missing or `Untested` active-scenario results without extending StopTime.
- Replaced Assessment output name matching with the confirmed positional rule: Assessment Input order is Signal Editor ActiveScenario variables followed by Harness output signals.
- Assessment Input symbols are sorted by their actual `Port`; the ActiveScenario element count is skipped and the remaining symbols are paired with Harness Outports in output order.
- Removed exact-name matching and limited port-fallback behavior from the current Assessment workflow. Harness names remain diagnostic metadata and are never normalized or guessed.
- Updated expected-value replacement to rebuild the same Assessment-symbol-to-Harness-output positional map before looking up logged signals.
- Changed the default Test Manager mode to incremental with `cfg.OverwriteTestFile = false`.
- Incremental Test Manager creation reuses an open target Test File, opens a closed existing file, creates a missing file, preserves existing Test Cases, and adds only missing `TestCaseName` values.
- Full recreation closes only the target Test File instead of clearing every open Test Manager file.
- Preserved the no-direct-Inport rule: Signal Editor configuration is skipped and `SignalEditorScenario` is omitted from the Test Manager iteration, while `TestSequenceScenario` remains assigned.
- Added timestamped verbose checkpoints through `st_log.m`, including logs immediately before and after long-running MATLAB/Simulink calls.
- Added workflow and per-target elapsed-time reporting.
- Kept compile-based Harness creation with `CreateWithoutCompile = false`.
- Documentation now treats the current code as the v0.9.6 candidate source of truth and records the remaining MATLAB R2025b runtime validation work.

## v0.9.5

- Assessment output matching no longer performs or proposes slash deletion/name normalization.
- `st_configure_assessments` now matches Harness output names to Assessment Input symbols using exact raw names first.
- If raw names differ, a port-order fallback is allowed only when Harness Outport count and Assessment Input symbol count are identical.
- Fallback keeps the original Harness signal/outport names unchanged and uses the actual Assessment symbol name for verify generation.
- If a safe one-to-one match cannot be established, the automation fails with the unmatched raw Harness names and actual Assessment symbol names instead of guessing.
- Added `PortOrderFallbackCount` to `AssessmentResult`.

## v0.9.4

- Fixed Test Manager iteration setup for CUTs with no direct Inport.
- `st_create_test_manager` now uses the same direct-Inport condition as `st_configure_signal_editors`.
- When a CUT has no direct Inport, `SignalEditorScenario` is no longer assigned to `Iteration 1`.
- `TestSequenceScenario` is still assigned because the Test Assessment scenario is independent of CUT input existence.
- Added `HasDirectInport` and `SignalEditorScenarioApplied` columns to `TestManagerResult` for traceability.

## v0.9.3

- Changed `st_export_subsystem_paths` to exhaustive inventory mode for human path selection.
- Searches under masks and inside library links, Subsystem References, and Model References.
- Includes inactive variant choices with `Simulink.match.allVariants`.
- Includes commented blocks.
- Added `SourceModel` so paths returned from referenced models can be distinguished from the selected top model.
- Depth and relative path are now calculated from each returned subsystem's actual block-diagram root.
- Duplicate identical returned definition paths are removed while preserving order.


## v0.9.2

- Added `excel_open_diagnostic.py` to compare multiple xlwings workbook-opening paths against the same management workbook.
- Added `st_diagnose_excel_access.m` so the diagnostic can be launched directly from MATLAB.
- Safe default tests are read-only and never modify the original workbook.
- Optional `writeProbe=true` additionally checks whether Excel can open the workbook read-write without saving and whether a disposable workbook can be saved in the same directory.
- Diagnostic methods include:
  - `app.books.open(..., read_only=True)`
  - `app.api.Workbooks.Open(..., ReadOnly=True)`
  - `xw.Book(path, read_only=True)`
  - `xw.Book(path, mode='r')`
- JSON results are written to `result/ExcelAccessDiagnostic.json` when launched from MATLAB.
- Existing v0.9.1 indentation-path workflow and test execution defaults are unchanged.

## v0.9.1

- Corrected the temporary path feature to read Excel native cell indentation rather than a numeric Depth column.
- Added `st_fill_temp_paths_from_indent`.
- Kept `st_fill_temp_paths_from_depth` as a compatibility wrapper.

## 2026-09-09 Template Harness clone

- 완전 복사/Import 구현을 backup/harness-full-copy(b6d30a8)에 보존하고 전용 경로만 제거.
- HARNESS_CLONE 행을 sltest.harness.clone + DestinationOwner로 생성하고 기존 입력·Assessment 구성 재사용.
- OverwriteHarness=false 기본값, 교체 recovery clone, 입력 MAT 독립 보존 및 대상 실패 격리 추가.
- 명세서 출력·CVF·일반 생성 동작 유지. MATLAB 런타임 검증은 미수행.
