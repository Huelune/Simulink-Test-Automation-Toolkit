# 도달 불가 결정 결과 결함 TC 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SLDV가 도달 불가로 판정한 결정 결과마다(블록 단위) 같은 Test Case에 결함 Iteration을 붙이고, 그 Iteration이 커버리지 판정으로 진짜 FAIL이 되어 최종 문서에 결함으로 남게 한다.

**Architecture:** `st_get_sldv_profile`이 SLDV 데이터에서 `profile.DefectIterations`를 계산한다. Test Manager 생성은 이 목록대로 원본 Iteration을 복사해 덧붙이고 Custom Criteria 콜백을 단다. 검사·기대값 갱신·최종 문서는 같은 목록을 읽는다. Custom Criteria가 Iteration 커버리지를 읽을 수 있는지는 확인되지 않았으므로, 첫 작업이 실험이다. 실험 결과를 기다리지 않는 작업(2~7)과 기다려야 하는 작업(8~10)을 나눈다.

**Tech Stack:** MATLAB R2025b, Simulink Test(Test Manager, Custom Criteria), Simulink Design Verifier(`sldvData`), Simulink Coverage(`decisioninfo`), `matlab.unittest` 함수 기반 테스트.

**Spec:** `docs/superpowers/specs/2026-11-24-unreachable-outcome-defect-tc-design.md`

## Global Constraints

- 이 저장소에서는 MATLAB을 돌릴 수 없다. 각 작업의 "실행" 단계는 정적 확인(`git diff --check`, 코드 읽기)으로 하고, MATLAB 실행은 7·10 작업의 `todo.md` 절에서 사용자가 몰아서 한다. 커밋은 정적 확인 뒤에 한다(AGENTS.md).
- 사용자가 화면 캡처로 돌려줄 출력에는 모델·블록·TC·변수 이름과 경로를 찍지 않는다. 개수, Simulink 블록 종류, MathWorks 공개 필드 이름, 오류 식별자(identifier), 미리 정한 문구만 찍는다. 출력은 한 화면(약 40줄 × 120자)이다.
- `todo.md` 절: `clearvars`로 시작, `clc`, 경고 끄고 되돌리기, 경로는 `st_project_root()` 기준, 테스트는 `runtests(fullfile(st_project_root(),'tests','unit','<name>.m'))`. Claude 언급 금지. main에 커밋·push.
- 새 기능은 `st_log` 수명 로그를 남긴다: 오래 걸리는 API 앞뒤 start/end, 저하·실패 경로는 WARN/ERROR와 이유.
- 무조건 실패하는 검증(`verify(false)`, 틀린 기대값) 금지. 커버리지를 읽지 못하면 FAIL이 아니라 오류로 끝낸다.
- Custom Criteria 콜백은 자기완결 코드다. `st_`로 시작하는 툴킷 함수를 부르지 않는다(standalone 번들에서도 돈다). 첫 줄 표식: `% simtest:unreachable-defect-criteria v1`.
- 이름 규칙: 결함 Iteration 이름은 `st_scenario_name(CUTName, N+k)`, `N = numel(profile.ScenarioNames)`, `k = 1..결함 수`.
- 사유 코드: `UNREACHABLE_DEFECT`(정보성), `UNREACHABLE_DEFECT_APPROXIMATE`, `UNREACHABLE_DEFECT_PASSED`.
- 기본 사유 문장(정확한 증명): `SLDV가 어떤 입력으로도 실행할 수 없음을 증명함`. 근사 판정: `SLDV 근사 분석에서 실행할 수 없다고 판정함(확인 필요)`.
- 커밋: Conventional Commits, 한국어 제목, 목적 하나당 커밋 하나, 끝에 `Co-Authored-By` 줄. main에 바로 push.
- 출력을 찍는 새 코드의 테스트는 이름에 `Secret`을 넣고 출력에 없는지 확인한다.

## Review Focus

1. 같은 CUT을 두 번 준비(TEST_MANAGER 단계 재실행)해도 결함 Iteration이 늘어나지 않고, 모델이 고쳐져 결함이 0이 되면 Iteration과 툴킷 콜백이 함께 사라져야 한다 → 9 작업 `testCriteriaActionClearsOwnCallbackWhenNoDefects`.
2. 사람이 이미 Custom Criteria를 써 둔 Test Case에서는 덮어쓰지 않고 이유와 할 일을 말하며 멈춰야 한다 → 9 작업 `testCriteriaActionRefusesForeignCallback`.
3. `DefectInputScenario` 칸에 없는 번호·이름·잡문자가 들어오면 준비 단계가 종류와 할 일을 말하며 멈춰야 한다 → 3 작업 `testInvalidSourceSelectorIsRejected`.
4. 사유 시트에 결함 목록에 없는 이름이나 같은 이름이 두 번 있으면, 첫 줄을 쓰고 WARN 로그를 남겨야 한다 → 6 작업 `testReasonSheetUnknownAndDuplicateNamesWarn`.
5. FILE 모드로 받은 SLDV 데이터에 `Objectives`가 없으면 결함 없이 WARN만 남기고 진행해야 한다 → 8 작업 `testDataWithoutObjectivesYieldsNoDefects`.

---

### Task 1: Custom Criteria·SLDV 데이터 실험 도구와 todo 절

**Files:**
- Create: `diagnostics/matlab/st_probe_defect_criteria.m`
- Create: `diagnostics/matlab/st_probe_sldv_objectives.m`
- Create: `tests/unit/test_probe_sldv_objectives.m`
- Modify: `todo.md` (main, 새 번호 절)

**Interfaces:**
- Produces: 실험 결과(사용자 화면). 8·9 작업이 이 결과에 기대어 필드 이름과 커버리지 접근 경로를 정한다.

- [ ] **Step 1: `test_probe_sldv_objectives.m` 작성**

  `testCountsAndFieldNamesOnlyWithoutNames`: 임시 폴더에 가짜 `sldvData` MAT를 만든다. `Objectives`는 4개(type `Decision` 3개, `Condition` 1개; status `Unsatisfiable`, `Unsatisfiable under approximation`, `Satisfied`, `Undecided`)이고, `ModelObjects(k).slPath`에는 `Secret_Model/Secret_CUT/Secret_Switch`가 있다. `lines = st_probe_sldv_objectives({file})`의 출력에 `"Unsatisfiable 1"`, `"근사 1"`, `"Undecided 1"`이 있고, `"Objectives 필드:"` 줄에 `status`가 있으며, `evalc` 출력에 `Secret`이 없어야 한다.

- [ ] **Step 2: `lines = st_probe_sldv_objectives(files)` 구현**

  `files`를 생략하면 `st_load_targets(true)`의 행마다 `st_get_sldv_profile(row, cfg).EffectiveDataFile`을 쓴다. `Mode=OFF`와 MAT 형식은 건너뛰고 개수만 센다. 파일마다 한 줄씩 찍는다. 줄에는 대상 순번과 결정 목표 수, status별 수만 넣는다. 그다음 `Objectives`, `ModelObjects`, `ModelInformation`의 필드 이름 줄을 찍고, 마지막 줄에 경로 구조를 예/아니오로 찍는다: `slPath` 첫 요소가 분석 모델 이름인가, 둘째 요소가 CUT 이름과 같은가, `designSid` 필드가 있는가. 경로 비교는 함수 안에서만 하고, 경로 문자열은 찍지 않는다. 시작과 끝에 `st_log`를 남긴다.

- [ ] **Step 3: `st_probe_defect_criteria()` 구현**

  `tempdir` 아래에 합성 모델을 만든다. Subsystem 안에 Switch 하나를 두고, 제어 입력은 상수 1로 묶어 false 결과에 도달할 수 없게 한다. 그 Subsystem의 하네스, Test File, Test Case, Iteration 1개를 만들고 커버리지(Decision)를 켠다. Custom Criteria 콜백은 다음 값을 `fullfile(tempdir,'st_probe_defect_criteria.mat')`에 저장한다.
  1. `test` 객체의 속성 이름 목록
  2. Iteration 결과에 닿았는지
  3. 그 시점에 커버리지 객체를 얻었는지(얻은 경로와 실패 시 identifier)
  4. `[test.sltest_sut '/<Switch 이름>']`으로 `decisioninfo`가 되는지
  5. false 결과의 실행 횟수

  콜백 안에서는 `verifyGreaterThan(count, 0)`만 한다. 실행 뒤에는 Iteration 판정을 읽고, Test File을 저장·닫기·다시 열기 한 뒤 콜백이 남아 있는지 본다. 화면에는 6줄을 찍는다(설계 문서 6절 1~5 + 속성 이름 줄). 콜백이 커버리지를 얻는 후보 경로는 셋이고, 이 순서로 시도한다.
  - `getCoverageResults(test.TestResult)`
  - `test.sltest_simout`의 coverage 변수
  - `cvdata` 관련 속성

  사용자의 Test File은 닫거나 지우지 않는다. 자기가 만든 Test File만 닫는다.

- [ ] **Step 4: todo.md에 절 추가**

  왜: 결함 TC 판정이 Custom Criteria 안에서 커버리지를 읽을 수 있어야 성립한다. 실제 SLDV 데이터의 필드 구조도 확인한다.
  준비: main pull, 모델 프로젝트 열기, 툴킷 폴더에서 `st_setup`.
  코드 블록:

  ```matlab
  clearvars; clc; warnState = warning('off', 'all');
  st_probe_defect_criteria;
  st_probe_sldv_objectives;
  warning(warnState);
  ```

  확인할 것: [2]가 "있음"이고 [5]가 Failed인가.
  돌려줄 것: 화면 캡처 한 장.

- [ ] **Step 5: 정적 확인 후 커밋·push**

  `git diff --check`. 커밋 제목은 둘이다.
  - `feat(diagnostics): 결함 TC 판정 실험 도구를 추가한다`
  - `docs(todo): Custom Criteria 커버리지 실험 절을 추가한다`

> **게이트:** 8·9 작업은 이 절의 결과를 받은 뒤에 시작한다. [2]가 "없음"이면 8·9를 멈추고 설계 문서 5.4절(대체 판정: 입력 신호 로깅)을 다시 설계한다. 2~7 작업은 기다리지 않는다.

---

### Task 2: 설정, 워크북 열, 재실행 지문

**Files:**
- Modify: `src/config/st_config.m` (`cfg.ExpectedUpdateMode` 근처 426행)
- Modify: `src/targets/st_load_targets.m` (선택 열 읽기 79행 근처, 출력 표 345행 근처, 머리말 주석)
- Modify: `src/workflow/st_stage_inputs.m:31-34`
- Modify: `docs/reference/config-reference.md`, `docs/reference/workbook-reference.md`
- Test: `tests/unit/test_defect_settings.m` (새 파일)

**Interfaces:**
- Produces:
  - `cfg.UnreachableDefectTests = true`, `cfg.DefectReasonSheet = 'DefectReasons'`
  - `st_load_targets` 출력 표의 `DefectInputScenario` 열(string, 기본 `""`). 별칭은 `DefectInputScenario`, `Defect Input Scenario`, `결함입력시나리오`.
  - `st_stage_inputs(row,cfg).TEST_MANAGER` 해시 입력에 `DefectTests`(cfg 값)와 `DefectInput`(행 값) 추가. 행에 열이 없으면 `""`.

- [ ] **Step 1: 테스트 작성** — `testConfigDefaults`: `cfg = st_config(); verifyTrue(cfg.UnreachableDefectTests); verifyEqual(cfg.DefectReasonSheet,'DefectReasons')`. `testStageFingerprintChangesWithDefectInput`: 같은 행에서 `DefectInputScenario`만 `""`→`"2"`로 바꾸면 `TEST_MANAGER` 해시가 달라지고 `SLDV` 해시는 같다. `testStageFingerprintToleratesMissingColumn`: 열이 없는 행도 오류 없이 해시를 만든다.
- [ ] **Step 2: 정적 확인** — 테스트가 아직 없는 필드를 가리키는지 읽어 확인.
- [ ] **Step 3: 구현** — 위 Interfaces 그대로. `st_load_targets`는 `ExpectedUpdateMode`와 같은 방식으로 읽고, `ismissing`은 `""`로, 앞뒤 공백은 `strtrim`으로 처리한다. 값 검증은 3 작업이 한다(여기서는 문자열로만 옮긴다).
- [ ] **Step 4: 문서** — config-reference에 두 cfg 항목, workbook-reference에 열 하나(값: 비움/번호/시나리오 이름, 비면 마지막 시나리오)와 `DefectReasons` 시트(열 `TestName`/`결함TC`, `Reason`/`사유`)를 적는다.
- [ ] **Step 5: 정적 확인 후 커밋** — `feat(config): 결함 TC 설정과 입력 시나리오 열을 추가한다`

---

### Task 3: 결함 Iteration 목록 만들기

**Files:**
- Create: `src/sldv/st_build_defect_iterations.m`
- Modify: `src/sldv/st_empty_sldv_profile.m` (필드 `DefectIterations` 추가)
- Test: `tests/unit/test_build_defect_iterations.m`

**Interfaces:**
- Consumes: 8 작업이 만드는 objectives 표 형식(여기서 정의한다).
  - `objectives`: table, 열 `Sid`(string), `BlockType`(string), `RelativePath`(string, CUT 기준, 바로 아래면 블록 이름만), `OutcomeIndex`(double), `OutcomeText`(string), `Approximate`(logical)
- Produces: `defects = st_build_defect_iterations(objectives, scenarioNames, cutName, selector)`
  - `scenarioNames`: cellstr(`profile.ScenarioNames`), `selector`: string(`DefectInputScenario` 칸)
  - 반환은 struct 배열이고, 필드는 `Name`(char), `SourceScenario`(char), `SourceIndex`(double), `BlockType`(char), `RelativePath`(char), `Sid`(char), `Outcomes`(struct 배열: `Index`, `Text`, `Approximate`)이다.
  - 빈 결과는 같은 필드의 0×1 struct이다. `st_empty_sldv_profile`의 `DefectIterations` 기본값도 이 빈 struct다.

- [ ] **Step 1: 테스트 작성**
  - `testGroupsByBlockAndNamesAfterLastScenario`: 시나리오 3개, objectives 3행(블록 A 결과 2개, 블록 B 결과 1개)을 주면 결함 2개가 나온다.
    - 이름: `st_scenario_name("Secret_CUT",4)`, `...,5)`
    - 순서: `RelativePath` 오름차순
    - 블록 A의 `Outcomes`는 2개
  - `testEmptySelectorUsesLastScenario`: `selector=""`이면 `SourceScenario`가 3번째, `SourceIndex=3`이다.
  - `testNumberAndNameSelectorsPickTheSameScenario`: `"2"`와 `st_scenario_name("Secret_CUT",2)`이 같은 결과를 낸다.
  - `testInvalidSourceSelectorIsRejected`: `"9"`, `"abc"`, `"0"`은 모두 `verifyError(..., 'simtest:DefectInputScenarioInvalid')`이다. 오류 문구에는 할 일("Targets 시트의 DefectInputScenario를 1~3 또는 시나리오 이름으로")이 들어간다.
  - `testNoObjectivesGiveEmptyStructWithFields`: 빈 표 → `isempty`이고 `isfield(defects,'Outcomes')`이다.
  - `testApproximateFlagIsKeptPerOutcome`.
- [ ] **Step 2: 정적 확인**
- [ ] **Step 3: 구현** — `Sid`로 묶고, 묶음의 `BlockType`·`RelativePath`는 첫 행 값을 쓴다. 결과는 `OutcomeIndex` 순서다.
- [ ] **Step 4: 정적 확인 후 커밋** — `feat(sldv): 도달 불가 결과를 블록 단위 결함 Iteration 목록으로 묶는다`

---

### Task 4: 결함 Iteration을 받아들이는 이름·바인딩 검사

**Files:**
- Create: `src/test_manager/st_expected_iteration_bindings.m`
- Modify: `src/workflow/st_inspect_preparation_stage.m:89-101`
- Modify: `src/test_manager/st_validate_scenario_alignment.m:292-305, 421-476` (`assert_iteration_scenario_parameters`)
- Test: `tests/unit/test_expected_iteration_bindings.m`

**Interfaces:**
- Consumes: `profile.DefectIterations` (3 작업)
- Produces: `[names, bound] = st_expected_iteration_bindings(profile)`
  - 두 값 모두 cellstr 열이고 순서가 같다.
  - 보통 모드: `names = [ScenarioNames; {Defect.Name}]`, `bound = [ScenarioNames; {Defect.SourceScenario}]`
  - `Mode=OFF`: `names = {'Iteration 1'}`, `bound = ScenarioNames(1)`

- [ ] **Step 1: 테스트 작성** — `testScenariosBindToThemselves`, `testDefectsBindToTheirSource`, `testOffModeKeepsIteration1`, `testProfileWithoutDefectFieldBehavesAsBefore`(`DefectIterations` 필드 없는 옛 profile도 동작).
- [ ] **Step 2: 정적 확인**
- [ ] **Step 3: 구현과 두 검사 교체**
  - `st_inspect_preparation_stage`: `require_names`의 기대 목록을 `names`로 바꾼다. 바인딩 검사는 Iteration 이름에서 `bound`의 같은 위치 값을 찾아 비교한다.
  - `st_validate_scenario_alignment`: `expectedIterationNames = names`로 바꾸고, `assert_iteration_scenario_parameters`에 `bound`를 넘긴다. 그 안에서는 `scenarioName = bound{이름 위치}`로 바인딩을 확인한다. 이름 자체가 목록에 있는지는 `names`로 확인한다.
  - Assessment·Signal Editor 시나리오 집합 검사는 계속 `ScenarioNames`만 쓴다(결함은 시나리오를 만들지 않는다).
- [ ] **Step 4: 정적 확인 후 커밋** — `feat(test-manager): 준비 검사가 결함 Iteration의 원본 시나리오 바인딩을 받아들인다`

---

### Task 5: Iteration 결과 찾기를 이름 우선으로

**Files:**
- Create: `src/test_manager/st_find_iteration_result.m`
- Modify: `src/execution/st_update_expected_from_results.m:1630-1683` (`find_iteration_result`를 새 함수 호출로)
- Modify: `src/sldv/st_validate_sldv_verify_results.m:193-206` (같음)
- Test: `tests/unit/test_find_iteration_result.m`

**Interfaces:**
- Produces: `index = st_find_iteration_result(iterations, scenarioName, allowFallback)`
  - 반환은 double이고, 못 찾으면 `0`이다.
  - 1차: `st_result_iteration_name(iterations(i), i) == scenarioName`
  - 2차: 지금처럼 `TestSequenceScenario`가 같은 첫 Iteration
  - 3차: `allowFallback`이면 마지막 Iteration
  - 두 호출부는 `index`로 결과를 꺼내고 나머지 동작은 그대로 둔다. `st_validate_sldv_verify_results`는 `allowFallback=false`를 넘긴다.

- [ ] **Step 1: 테스트 작성** — 입력은 struct 배열(`Name`, `TestSequenceScenario.TestSequenceScenario`).
  - `testDefectBeforeOriginalIsNotPicked`: 결함 Iteration(이름 `_004`, 시나리오 `_001`)이 원본 `_001`보다 앞에 있어도 `_001` 조회는 원본 위치를 돌려준다.
  - `testOffModeFallsBackToScenarioBinding`: 이름 `Iteration 1`, 시나리오 `_001`이면 `_001` 조회가 1을 돌려준다.
  - `testNothingMatchesReturnsZero`.
- [ ] **Step 2: 정적 확인**
- [ ] **Step 3: 구현과 두 호출부 교체**
- [ ] **Step 4: 정적 확인 후 커밋** — `fix(execution): 기대값 갱신과 SLDV 검증이 Iteration을 이름으로 먼저 찾는다`

---

### Task 6: 최종 문서의 결함 행

**Files:**
- Create: `src/exporting/st_read_defect_reasons.m`
- Create: `src/exporting/st_final_document_defects.m`
- Create: `src/exporting/st_final_document_defect_rows.m`
- Modify: `src/exporting/st_final_document_table.m` (`build_identifiers` 83-116, OutputValue 32행, `resolve_judgements` 143-196, `only_informational` 218-225)
- Modify: `src/exporting/st_export_final_document.m:94-104` (`details`를 받아 결함 행 단계 끼우기)
- Modify: `docs/reference/final-document.md`
- Test: `tests/unit/test_final_document_defects.m`

**Interfaces:**
- Consumes: `profile.DefectIterations`(3 작업), `st_get_sldv_profile`, `st_load_targets`, `st_specification_decision_catalog()`의 `TwoWay`
- Produces:
  - `reasons = st_read_defect_reasons(cfg)`
    - 반환: table(`TestName` string, `Reason` string)
    - 시트가 없으면 빈 표를 돌려주고 INFO 로그를 남긴다.
    - 같은 이름이 두 번이면 첫 줄을 쓰고 WARN을 남긴다.
  - `defects = st_final_document_defects(cfg)`
    - 반환: table(`TestCaseName`, `Name`, `BlockType`, `RelativePath`, `OutcomeTexts`(string, `"|"`로 이음), `Approximate` logical)
    - 대상 행마다 `st_get_sldv_profile`을 부른다.
    - 한 대상에서 실패하면 그 대상만 WARN으로 남기고 건너뛴다.
  - `specification = st_final_document_defect_rows(specification, details, defects, reasons, cfg)`
    - `DefectCode`("", `"EXACT"`, `"APPROXIMATE"`)와 `DefectReason` 열을 덧붙인다.
    - 결함 행이면 `DecisionBlocks`와 `verify 내용` 칸을 바꾼다.
    - 결함 행은 (`테스트 케이스명`, `Iteration명`)이 `defects`의 (`TestCaseName`, `Name`)과 같은 행이다.

- [ ] **Step 1: 테스트 작성** (`sample_specification`은 `test_export_final_document.m`과 같은 모양으로 만든다)
  - `testDefectRowUsesIterationNameForId`: Test Sequence 시나리오가 `UT_REQ_Secret_001`이고 Iteration명이 `UT_REQ_Secret_004`인 결함 행의 `TestCaseID`는 `..._004`이고, `DUPLICATE_TEST_CASE_ID`가 없다.
  - `testDescriptionKeepsOnlyTheTargetLineWithItsOutcome`
    - 렌더된 Description이 `"Name1\nD1 [T/F]Switch (u2 >= 1)\nName2\nD2 [T/F]Max"`이고, `details`가 D1↔`.../Secret_Switch`, D2↔`.../Secret_Max`이다.
    - 결함 블록이 `Secret_Switch`, 결과 문구에 `false`가 있으면 Description은 `"D1 [F]Switch (u2 >= 1)"`이다.
    - Max 결함(결과 문구 `input 1`)은 `"D2 [input 1]Max"`이다.
  - `testNestedBlockWithoutDLineUsesPath`: `details`에 없는 블록은 `"Switch [false] (Sub/Secret_Switch)"`이다.
  - `testExpectedAndOutputCells`: Expected result는 `"<Description 줄>가 한 번 이상 실행된다"`이고, OutputValue는 `DefectReason`이다. 사유 시트가 없을 때는 고정 문장이 들어간다(Global Constraints).
  - `testReasonSheetTextWins`
  - `testReasonSheetUnknownAndDuplicateNamesWarn`
  - `testFailedExactDefectIsInformational`: FAIL이고 EXACT면 `확인 사유`에 `UNREACHABLE_DEFECT`가 있고 `FAILED`는 없으며, `확인 필요`는 `""`이다.
  - `testApproximateDefectNeedsReview`: `UNREACHABLE_DEFECT_APPROXIMATE`, `확인 필요=Y`.
  - `testPassedDefectNeedsReview`: `UNREACHABLE_DEFECT_PASSED`, `확인 필요=Y`.
  - `testOrdinaryRowsUnchanged`: 결함이 없으면 `st_final_document_table` 출력이 이전과 같다(기존 `test_export_final_document.m` 전체가 그대로 통과해야 함).
  - `st_final_document_defects`는 대상 워크북과 manifest가 필요해 단위 테스트를 두지 않고, 10 작업의 실기 확인으로 검증한다.
- [ ] **Step 2: 정적 확인**
- [ ] **Step 3: 구현**
  - D 줄 찾기: `details`에서 `TestSpecificationRow == row+1`이고 `Path == CUTPath + "/" + RelativePath`인 행의 `Decision`을 얻는다(`CUTPath`는 같은 행의 명세 열). 렌더된 줄 중 `Decision + " ["`로 시작하는 줄의 대괄호 안을 라벨로 바꾼다. 일치하는 행이 없으면 경로 표기로 간다.
  - 라벨: `TwoWay=YES` 블록이면, 결과 문구에 `false`가 있으면(대소문자 무시) `F`, `true`가 있으면 `T`다. 그 밖에는 결과 문구 그대로다. 한 블록에 결과가 여럿이면 `/`로 잇는다.
  - `st_final_document_table`: `DefectCode`가 비어 있지 않은 행은 다음처럼 다룬다.
    - 식별자 계산에서 시나리오 대신 `Iteration명`을 쓴다.
    - OutputValue는 `DefectReason`이다.
    - 판정 사유는 Global Constraints의 코드로 정한다.
    - `UNREACHABLE_DEFECT`는 `only_informational` 목록에 넣는다.
  - `st_export_final_document`: `[specification, details, outcomeReasons] = st_format_specification_decision_blocks(...)`로 `details`를 받는다. 그다음 `defects`와 `reasons`를 읽고 `st_final_document_defect_rows`를 부른 뒤 표를 만든다. 결함 행 수는 INFO 로그로 남긴다.
- [ ] **Step 4: 문서** — final-document.md에 결함 행 칸 표, 사유 코드 세 개, 사유 시트를 적는다.
- [ ] **Step 5: 정적 확인 후 커밋** — `feat(final-document): 결함 Iteration을 도달 불가 결함 행으로 적는다`

---

### Task 7: 2~6 작업 단위 테스트 실행 절

**Files:**
- Modify: `todo.md`

- [ ] **Step 1: todo 절 추가**
  - 왜: 2~6 작업의 단위 테스트와, 바뀐 기존 테스트를 돌린다.
  - 대상 파일: `test_defect_settings`, `test_build_defect_iterations`, `test_expected_iteration_bindings`, `test_find_iteration_result`, `test_final_document_defects`, `test_export_final_document`, `test_expected_update_modes`, `test_probe_sldv_objectives`
  - 코드 블록: 파일마다 `runtests(fullfile(st_project_root(),'tests','unit',name))`를 돌린다. 한 줄에 한 파일씩 `통과/실패/미완료` 개수를 찍고, 실패한 테스트는 이름과 진단의 첫 줄만 찍는다. 진단 전문은 `tempdir`의 파일에 쓰고 파일 이름만 찍는다.
  - 돌려줄 것: 화면 캡처 한 장.
- [ ] **Step 2: 커밋·push** — `docs(todo): 결함 TC 단위 테스트 실행 절을 추가한다`

---

### Task 8: SLDV 목표 읽기와 profile 연결 (Task 1 결과 이후)

**Files:**
- Create: `src/sldv/st_unreachable_objectives.m`
- Modify: `src/sldv/st_get_sldv_profile.m` (113-125행 뒤에 결함 계산)
- Test: `tests/unit/test_unreachable_objectives.m`

**Interfaces:**
- Consumes: Task 1이 확인한 `sldvData` 필드 이름과 경로 구조(아래). `st_build_defect_iterations`(3 작업).
  - 실험 결과(R2025b 실제 데이터): `Objectives` 필드는 `type, status, descr, label, outcomeValue, modelObjectIdx, ...`, `ModelObjects` 필드는 `descr, typeDesc, slPath, sfObjType, sfObjNum, sid, designSid, replacementSid, ...`, `ModelInformation` 필드는 `Name, Version, TimeStamp, Checksum, Author, SubsystemPath, ExtractedModel`이다.
  - `slPath`의 첫 요소는 `ModelInformation.Name`이 아니고, 둘째 요소는 언제나 CUT 이름이며, `SubsystemPath`로 시작하지 않는다. 그래서 상대 경로는 **앞의 두 요소를 뗀 나머지**다. 요소를 나눌 때 `//`(이름 속 `/`)는 나누지 않는다. 남은 경로의 `//` 표기와 줄바꿈은 그대로 둔다(9 작업 콜백이 이 경로로 하네스 블록을 찾는다).
- Produces: `[objectives, counts] = st_unreachable_objectives(sldvData, coverageFilterMode)`
  - `objectives`: 3 작업에서 정의한 표. `Sid`는 `designSid`가 있으면 그것, 없으면 `sid`. `BlockType`은 `typeDesc`.
  - `counts`: struct(`Decision`, `Unsatisfiable`, `Approximate`, `Undecided`, `FilteredByCvf`, `CutItself`)
  - type이 `Decision`이 아닌 목표와, status가 두 Unsatisfiable 종류가 아닌 목표는 버린다.
  - 요소가 둘뿐인 목표(CUT 자신)는 버리고 `CutItself`로 센다.
  - CVF 거름(설계 5.2, 사용자 결정): `coverageFilterMode`가 `SUBSYSTEM`이면 상대 경로에 `/`가 없고 `typeDesc`에 `subsystem`이 든(대소문자 무시) 목표를 버린다. `ALL_CONTENT`면 그에 더해 상대 경로에 (`//`가 아닌) `/`가 있는 목표를 모두 버린다. `OFF`·빈 값은 거르지 않는다. 버린 수는 `FilteredByCvf`.

- [ ] **Step 1: 테스트 작성** — 위 필드 이름으로 가짜 `sldvData`를 만든다(`slPath`는 `Secret_Root/Secret_CUT/...`).
  - `testOnlyDecisionUnsatisfiableAreKept`
  - `testApproximateStatusIsFlagged`
  - `testUndecidedIsCountedNotKept`
  - `testRelativePathDropsRootAndCut`(바로 아래 블록 → 이름만, 하위 → `Sub/Blk`, 이름 속 `//`는 유지)
  - `testCutItselfIsCountedNotKept`
  - `testCvfOffKeepsAll`, `testCvfSubsystemDropsDirectChildSubsystemOutcomes`, `testCvfAllContentDropsNestedBlocks`
  - `testDesignSidPreferredOverSid`
  - `testDataWithoutObjectivesYieldsNoDefects`(필드 없음 → 빈 표, WARN)
- [ ] **Step 2: 정적 확인**
- [ ] **Step 3: 구현과 연결**
  - `st_get_sldv_profile`은 `cfg.UnreachableDefectTests`가 참이고 `profile.DataFileFormat`이 `'SLDV'`일 때만 결함을 계산한다. 계산 순서는 이렇다.
    1. `load(profile.EffectiveDataFile)`
    2. `st_unreachable_objectives(sldvData, row.CoverageFilterMode)`
    3. `st_build_defect_iterations(objectives, profile.ScenarioNames, profile.CUTName, row.DefectInputScenario)`
  - 행에 `DefectInputScenario`·`CoverageFilterMode` 열이 없으면 `""`·`"OFF"`를 쓴다. 이 계산의 실패(파일 읽기 등)는 profile 전체를 막지 않는다: WARN을 남기고 `DefectIterations`를 비운다. 단 `simtest:DefectInputScenarioInvalid`는 사용자가 고칠 입력 오류이므로 그대로 던진다.
  - 최종 문서 라벨 보정(`src/exporting/st_final_document_defect_rows.m`): `typeDesc`가 Simulink BlockType 이름과 다를 수 있으므로, D 줄을 찾은 경우에는 catalog `TwoWay` 조회에 `details.BlockType`(D 목록의 실제 BlockType)을 쓴다. 테스트 `testTwoWayLookupUsesDetailsBlockType`을 `tests/unit/test_final_document_defects.m`에 추가한다.
  - 로그는 DEBUG로 `[UnreachableDefect] profile | CUT=… | Unsatisfiable=… | Approximate=… | Undecided=… | Defects=…`를 남긴다. 이 함수는 여러 단계에서 불리므로 INFO 로그는 9 작업에서 한 번만 남긴다.
  - `% shortcut: 호출마다 sldvData를 다시 읽는다, 느려지면 manifest에 결과를 캐시한다`
- [ ] **Step 4: 정적 확인 후 커밋** — `feat(sldv): SLDV 도달 불가 목표로 결함 Iteration 목록을 profile에 채운다`

---

### Task 9: Test Manager에 결함 Iteration과 Custom Criteria 달기 (Task 1 결과 이후)

**Files:**
- Create: `src/test_manager/st_defect_criteria_script.m`
- Create: `src/test_manager/st_defect_criteria_action.m`
- Modify: `src/test_manager/st_create_test_manager.m:478-519` (Iteration 준비 루프를 로컬 함수로 빼고 결함분 추가, Custom Criteria 설정)
- Test: `tests/unit/test_defect_criteria.m`

**Interfaces:**
- Consumes: `profile.DefectIterations`, Task 1이 확인한 커버리지 접근 경로.
- Produces:
  - `script = st_defect_criteria_script(defects)` (char)
    - 첫 줄은 표식이다. 이름 → (`RelativePath`, 결과 번호들, 표기 문구) 표를 상수로 박는다.
    - 결함 Iteration이 아니면 바로 `return`한다.
    - 결함이면 결과마다 `verifyGreaterThan(실행 횟수, 0, '<BlockType> [<결과 문구>] 실행 횟수')`를 한다.
    - 커버리지를 못 읽으면 `error('simtest:DefectCriteriaNoCoverage', ...)`를 던진다.
    - 커버리지는 `getCoverageResults(test.TestResult)`로 얻는다(실험으로 확인). 결과가 배열·그룹일 수 있으니 `diagnostics/matlab/st_probe_defect_criteria.m`의 콜백 문자열이 펼치는 방식을 그대로 옮긴다(툴킷 함수 호출 없이).
    - 블록 경로는 하네스 기준 `[test.sltest_bdroot '/' cutName '/' RelativePath]`다. `cutName`은 `get_param(test.sltest_sut,'Name')`의 `/`를 `//`로 바꾼 값이다. `test.sltest_sut`(원래 모델 경로)로는 `decisioninfo`가 빈 값을 돌려준다(실험으로 확인).
  - `action = st_defect_criteria_action(currentCallback, defects)`
    - 반환 `'SET' | 'CLEAR' | 'NONE'`
    - 표식 없는 비어 있지 않은 콜백이 있고 결함이 있으면 `error('simtest:DefectCriteriaForeign', ...)`를 던진다. 문구에는 할 일("Test Case의 Custom Criteria를 비우거나 cfg.UnreachableDefectTests=false")을 넣는다.

- [ ] **Step 1: 테스트 작성**
  - `testScriptIsSelfContainedAndMarked`: 첫 줄이 표식이고 `regexp(script,'\<st_\w+\(')`가 비어 있다.
  - `testScriptNamesEveryDefectIteration`
  - `testScriptRaisesInsteadOfFailingWithoutCoverage`: 스크립트 텍스트에 `simtest:DefectCriteriaNoCoverage`가 있고, `verify`·`assert`에 상수 `false`를 넘기는 곳이 없다.
  - `testCriteriaActionSetsWhenDefectsExist`
  - `testCriteriaActionClearsOwnCallbackWhenNoDefects`
  - `testCriteriaActionLeavesForeignCallbackWithoutDefects`(`'NONE'`)
  - `testCriteriaActionRefusesForeignCallback`
- [ ] **Step 2: 정적 확인**
- [ ] **Step 3: 구현**
  - `st_create_test_manager`: 보통 시나리오 Iteration 준비 코드를 로컬 함수 `prepare_iteration(profile, scenarioIndex, applySignalEditor)`로 뺀다. 이 함수는 `[iter, parameterCount]`를 반환한다.
  - 보통 시나리오 루프 뒤에 결함마다 다음을 한다.
    - `prepare_iteration(profile, defect.SourceIndex, ...)`로 Iteration을 만든다.
    - 이름은 `defect.Name`으로 하고 `preparedIterations`에 덧붙인다.
  - `replace_test_iterations`는 그대로 쓴다. 매번 전체를 다시 쓰므로 중복이 생기지 않는다.
  - 그다음 `cc = getCustomCriteria(tc)`를 얻고 `st_defect_criteria_action(cc.Callback, defects)`대로 처리한다.
    - SET: `cc.Callback = script; cc.Enabled = true`
    - CLEAR: `cc.Callback = ''; cc.Enabled = false`
  - INFO 로그: `[UnreachableDefect] start | TestCase=%s | Defects=%d`, `end | Iterations=%d | Criteria=%s`
  - 실패하면 ERROR 로그를 남기고 다시 던진다.
- [ ] **Step 4: 정적 확인 후 커밋** — `feat(test-manager): 결함 Iteration과 커버리지 판정 Custom Criteria를 단다`

---

### Task 10: 실기 확인 절과 마무리 문서

**Files:**
- Modify: `todo.md`, `CHANGELOG.md`, `docs/ai/codex-handoff.md`, `docs/user-manual.md`(결함 TC가 생기는 조건과 사유 시트 한 단락)

- [ ] **Step 1: todo 절 추가**
  - 왜: 계기가 된 모델에서 결함 TC가 2건 생기고 FAIL이 진짜인지 확인한다.
  - 코드 블록은 세 부분이다.
    1. 8·9 작업 단위 테스트(`test_unreachable_objectives`, `test_defect_criteria`)를 7 작업과 같은 형식으로 돌린다.
    2. 그 CUT을 `PreparationFromStage` TEST_MANAGER로 다시 준비하고 테스트를 실행한다. 명령은 user-manual의 PER_CUT 실행 명령을 따른다. 기대값 갱신은 기본값(APPLY) 그대로 두어, 갱신 뒤에도 결함 TC가 FAIL로 남는지 함께 본다.
    3. 결과에서 숫자만 한 줄씩 찍는다.
       - 결함 Iteration 수, 결함마다 한 줄(블록 종류, CUT 아래 깊이, 결과 수, 근사 여부)
       - CVF로 거른 수, CUT 자신이라 뺀 수
       - 결함 FAIL·PASS·오류 수
       - 보통 Iteration의 이전 대비 판정 변화 수
       - 결정 커버리지 분자/분모
  - 확인할 것: 결함 TC가 Switch와 Max 2건(블록 종류로 확인), FAIL 2, 판정 변화 0, 커버리지 숫자가 이전과 같다(20/22 등 직전 값과 비교). SLDV 도달 불가 3개 중 나머지가 CVF 거름이나 같은 블록의 두 번째 결과로 설명되는가.
  - 돌려줄 것: 화면 캡처 한 장.
- [ ] **Step 2: 마무리 문서**
  - CHANGELOG에 기능 항목을 적는다.
  - codex-handoff에는 "실기 미확인: 결함 TC" 항목과 Task 1 실험 결과 요약을 적는다.
- [ ] **Step 3: 커밋·push** — `docs: 결함 TC 실기 확인 절과 변경 기록을 추가한다`
