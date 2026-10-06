# 최종 문서의 분기 결과 표기 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 최종 문서의 각 행(Test Case × iteration)에서 true/false 두 결과짜리 분기의 `[T/F]`를 그 행 테스트가 실제로 탄 결과 `[T]`/`[F]`/`[T/F]`/`[-]`로 바꾼다.

**Architecture:** 리포트 시점(PER_CUT `st_export_result_set_report`, BATCH `st_generate_test_report`)에 iteration별 cvdata에서 `decisioninfo`의 결과별 `executionCount`를 읽어 결과 workbook의 `DecisionOutcomes` 시트로 남긴다. 최종 문서(`st_export_final_document`)는 판정과 같은 workbook·stage에서 이 시트를 읽고, 포맷터가 D 줄의 `[T/F]`를 바꾼다. 결과를 못 붙인 행은 `확인 사유`에 정보성 코드를 남긴다.

**Tech Stack:** MATLAB, Simulink Test(Test Manager 결과 API), Simulink Coverage(`decisioninfo`), `matlab.unittest` 함수형 테스트(`functiontests(localfunctions)`).

**Spec:** `docs/superpowers/specs/2026-10-06-decision-outcome-in-final-document-design.md`

## Global Constraints

- 표기는 정확히 `[T]`, `[F]`, `[T/F]`, `[-]`. 대상은 모든 결정이 true/false 두 결과인 블록뿐이고, 나머지는 `[T/F]` 그대로 둔다.
- 행 사유 코드는 `DECISION_OUTCOME_UNAVAILABLE`, `DECISION_OUTCOME_MISMATCH`. 이 둘은 정보성이라 그것만으로 `확인 필요`를 `Y`로 만들지 않는다. 시트 단위 노트는 `DECISION_OUTCOME_AMBIGUOUS`.
- 시트 이름은 `DecisionOutcomes`, 열은 `Run, CUTName, TestCaseName, IterationName, Kind, RelativePath, DecisionIndex, DecisionText, TrueCount, FalseCount`. `Kind`는 `UNIT` 또는 `DECISION`.
- 명세서 export(`st_export_test_specification`)의 출력은 바뀌지 않는다. 포맷터의 새 인자는 선택 인자다.
- 모든 새 기능은 `st_log` 시작·끝 INFO와 저하 경로 WARN을 남긴다(`AGENTS.md`).
- `.m` 파일은 CRLF 줄끝이다(`core.autocrlf=true`, 기존 파일이 모두 CRLF). 새 파일도 CRLF로 저장한다.
- 커밋은 `docs/ai/commit-convention.md`: 목적 하나에 커밋 하나, Conventional Commits, 한국어 제목, 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- 이 저장소의 작업 디렉터리에서는 MATLAB을 실행할 수 없다(MATLAB은 별도 클론에서 돈다). 테스트 실행 단계는 MATLAB이 있는 환경에서만 수행하고, 없으면 커밋 메시지에 "단위 테스트는 돌리지 못했다"고 적는다.

## Review Focus

1. **Simulink 기본 블록 이름의 줄바꿈과 끝 공백** (`For⏎Iterator`, `Discrete-Time⏎Integrator`, 이름이 공백으로 끝나는 CUT): 시트에 기록된 경로와 모델 경로가 공백 정규화 후 같은 키로 만나야 한다. → Task 2 `testRelativePathCollapsesNewlinesAndTrailingSpaces`, Task 3 `testLookupMatchesBlockNamesWithNewlines`.
2. **`Iteration명`이 `<기본 설정>`이나 빈 값인 행**: 판정처럼 Test Case 단위 결과로 찾아야 한다. → Task 3 `testPlaceholderIterationIsLookedUpAtTheTestCaseLevel`.
3. **이 기능 이전에 만든 결과 workbook**(`DecisionOutcomes` 시트 없음): 오류 없이 `[T/F]`를 유지하고 `DECISION_OUTCOME_UNAVAILABLE`을 남겨야 한다. → Task 3 `testWorkbookWithoutTheSheetMarksRowsUnavailable`.
4. **T/F 분기가 하나도 없는 CUT**(Saturate·MinMax만 있음): 수집은 됐지만 기록할 결정이 없다. 사유 없이 `[T/F]`로 남아야 한다. → Task 3 `testBlockWithoutTwoWayDecisionsKeepsTheStaticMarkSilently`.
5. **CUT 자신이 Enabled/Triggered/Resettable Subsystem**: DecisionBlocks JSON의 Path가 CUT 자체이므로 상대 경로 `.`로 만나야 한다. → Task 2 `testRelativePathIsKeyedBelowTheCut`, Task 3 `testConditionalCutIsLookedUpAsDot`.

---

## File Structure

| 파일 | 책임 | Task |
| --- | --- | --- |
| `src/reporting/st_result_iteration_name.m` (새) | iteration 결과의 키 이름. 판정 시트와 결과 시트가 같이 씀 | 1 |
| `src/reporting/st_decision_object_path.m` (새) | CUT 직계 자식이 어느 catalog 유형이고 coverage에 어느 경로로 물을지 | 1 |
| `src/exporting/st_is_real_iteration_name.m` (새) | 행의 `Iteration명`이 자리표시가 아닌지 | 1 |
| `src/reporting/st_collect_test_result_summary.m` | 로컬 `iteration_name` 제거, 공용 함수 호출 | 1 |
| `src/reporting/st_collect_decision_points.m` | 로컬 `classify_block`·`conditional_port`·`read_block_type` 제거 | 1 |
| `src/exporting/st_final_document_table.m` | 로컬 `is_real_iteration_name` 제거(1), 행 사유 인자와 정보성 판정(3) | 1, 3 |
| `src/reporting/st_cut_relative_path.m` (새) | CUT 기준 상대 경로 키(공백 정규화, CUT 자신은 `.`) | 2 |
| `src/reporting/st_decision_outcome_counts.m` (새) | `decisioninfo` description → `[True False]` 행렬. 순수 함수 | 2 |
| `src/reporting/st_collect_decision_outcomes.m` (새) | 결과 객체를 돌며 `DecisionOutcomes` 행을 만듦 | 2 |
| `src/reporting/st_export_result_set_report.m` | PER_CUT 시트 기록 | 2 |
| `src/reporting/st_generate_test_report.m` | BATCH 시트 기록 | 2 |
| `src/exporting/st_final_document_decision_outcomes.m` (새) | 시트 읽기, stage 선택, lookup 핸들 | 3 |
| `src/exporting/st_format_specification_decision_blocks.m` | lookup으로 `[T/F]` 치환, 행 사유 반환 | 3 |
| `src/exporting/st_export_final_document.m` | 연결과 Metadata | 3 |
| `tests/unit/test_decision_outcomes.m` (새) | Task 1~3의 단위 테스트 | 1, 2, 3 |
| `tests/unit/test_specification_decision_blocks.m` | 이동한 port 규칙의 소스 검사 대상 변경 | 1 |
| `tests/unit/test_export_final_document.m` | 정보성 사유 테스트 | 3 |
| 문서 4종과 설계 문서 | 사용자 문서, 인수인계, CHANGELOG | 4 |

---

### Task 1: 공용 함수 꺼내기 (동작 변화 없음)

**Files:**
- Create: `src/reporting/st_result_iteration_name.m`
- Create: `src/reporting/st_decision_object_path.m`
- Create: `src/exporting/st_is_real_iteration_name.m`
- Create: `tests/unit/test_decision_outcomes.m`
- Modify: `src/reporting/st_collect_test_result_summary.m:55`, `:80-95` (로컬 `iteration_name` 삭제)
- Modify: `src/reporting/st_collect_decision_points.m:47`, `:85-139` (로컬 함수 3개 삭제)
- Modify: `src/exporting/st_final_document_table.m:250`, `:274-277` (로컬 `is_real_iteration_name` 삭제)
- Modify: `tests/unit/test_specification_decision_blocks.m` (`testPortBlocksAreNotRecordedOnTheirOwn`)

**Interfaces:**
- Produces: `name = st_result_iteration_name(iterResult, index)` → string scalar
- Produces: `[blockType, objectPath] = st_decision_object_path(blockPath, root)` → char, char. 분기가 아니면 `blockType`이 `''`
- Produces: `tf = st_is_real_iteration_name(iterationName)` → logical scalar

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/unit/test_decision_outcomes.m`

```matlab
function tests = test_decision_outcomes
%TEST_DECISION_OUTCOMES No model or simulation is required by these tests.
tests = functiontests(localfunctions);
end

function testIterationNamePrefersTheResultName(testCase)
verifyEqual(testCase, st_result_iteration_name(struct('Name', 'Scenario1'), 3), ...
    "Scenario1");
end

function testIterationNameFallsBackToTheScenarioThenTheIndex(testCase)
scenario = struct('Name', '', 'TestSequenceScenario', ...
    struct('TestSequenceScenario', 'Sc2'));
verifyEqual(testCase, st_result_iteration_name(scenario, 2), "Sc2");
verifyEqual(testCase, st_result_iteration_name(struct('Name', ''), 4), ...
    "Iteration 4");
end

function testRealIterationNameRejectsThePlaceholders(testCase)
verifyTrue(testCase, st_is_real_iteration_name("Iteration 1"));
placeholders = ["", " ", "<기본 설정>", "(단일 실행)", "연결 없음"];
verifyFalse(testCase, any(arrayfun(@st_is_real_iteration_name, placeholders)));
end
```

`tests/unit/test_specification_decision_blocks.m`의 `testPortBlocksAreNotRecordedOnTheirOwn`에서 읽는 파일만 바꾼다:

```matlab
function testPortBlocksAreNotRecordedOnTheirOwn(testCase)
% The port is a direct child of the subsystem that owns it, so a depth 1
% walk sees both. Recording both would list the same branch twice.
source = fileread(fullfile(st_project_root(), 'src', 'reporting', ...
    'st_decision_object_path.m'));
verifyNotEmpty(testCase, regexp(source, ...
    "if any\(strcmp\(blockType, \{'EnablePort', 'TriggerPort', 'ResetPort'\}\)\)", 'once'));
end
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run (MATLAB, 저장소 루트, `st_setup` 뒤): `runtests({'tests/unit/test_decision_outcomes.m', 'tests/unit/test_specification_decision_blocks.m'})`
Expected: `test_decision_outcomes`의 3개는 `Undefined function 'st_result_iteration_name'` 등으로 FAIL, `testPortBlocksAreNotRecordedOnTheirOwn`은 파일 없음으로 FAIL.

- [ ] **Step 3: 공용 함수 작성**

`src/reporting/st_result_iteration_name.m`:

```matlab
function name = st_result_iteration_name(iterResult, index)
%ST_RESULT_ITERATION_NAME The name a Test Iteration result is keyed by.
% The Iterations sheet and the DecisionOutcomes sheet are both joined to a
% specification row by this name, so both derive it here: the result Name,
% then the Test Sequence scenario, then "Iteration N".
name = string(safe_property(iterResult, 'Name', ''));
if strlength(name) > 0
    return;
end
try
    scenario = iterResult.TestSequenceScenario;
    if isstruct(scenario) && isfield(scenario, 'TestSequenceScenario')
        name = string(scenario.TestSequenceScenario);
    end
catch
end
if strlength(name) == 0
    name = "Iteration " + string(index);
end
end

function value = safe_property(object, property, defaultValue)
try
    value = object.(property);
catch
    value = defaultValue;
end
end
```

`src/reporting/st_decision_object_path.m` — `st_collect_decision_points.m:85-139`의 세 함수를 옮긴다. 본문은 그대로이고 머리 주석만 새로 쓴다:

```matlab
function [blockType, objectPath] = st_decision_object_path(blockPath, root)
%ST_DECISION_OBJECT_PATH Which catalog type a CUT child is, and where coverage keeps it.
% Returns the catalog type this block stands for and the path to ask
% coverage about, or an empty type when the block is not a decision at all.
% st_collect_decision_points and st_collect_decision_outcomes walk the same
% direct children and must agree on which of them are decisions.
objectPath = blockPath;
blockType = read_block_type(blockPath);
% A port block is reported through the subsystem that owns it, so seeing
% it on its own would record the same branch twice.
if any(strcmp(blockType, {'EnablePort', 'TriggerPort', 'ResetPort'}))
    blockType = '';
    return;
end
if ~any(strcmp(blockType, {'SubSystem', 'ModelReference', ''}))
    return;
end
% Only the CUT itself counts as conditional. A child subsystem's enable
% belongs to that child, the same reason a nested branch is out of scope.
if ~strcmp(blockType, 'SubSystem') || ~strcmp(blockPath, root)
    blockType = '';
    return;
end
for portType = {'EnablePort', 'TriggerPort', 'ResetPort'}
    port = conditional_port(blockPath, portType{1});
    if ~isempty(port)
        blockType = portType{1};
        objectPath = port;
        return;
    end
end
blockType = '';
end


function blockType = read_block_type(blockPath)
blockType = '';
try
    blockType = char(string(get_param(blockPath, 'BlockType')));
catch
    % A block whose type cannot be read cannot be matched to a catalog
    % entry either, so it is left out rather than guessed at.
end
end


function port = conditional_port(blockPath, portType)
port = '';
try
    found = find_system(blockPath, 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'BlockType', portType);
catch
    return;
end
if ~isempty(found)
    port = char(string(found{1}));
end
end
```

`src/exporting/st_is_real_iteration_name.m`:

```matlab
function tf = st_is_real_iteration_name(iterationName)
%ST_IS_REAL_ITERATION_NAME False for the placeholders of an unbound row.
% A specification row bound to no named iteration carries one of these
% placeholders. Such a row is matched at the Test Case level, for its
% verdict and its decision outcomes alike.
iterationName = strtrim(string(iterationName));
tf = strlength(iterationName) > 0 && ...
    ~ismember(iterationName, ["<기본 설정>", "(단일 실행)", "연결 없음"]);
end
```

- [ ] **Step 4: 호출하는 곳을 바꾸고 로컬 함수 삭제**

`st_collect_test_result_summary.m:55`:
```matlab
        IterationName(end+1,1) = st_result_iteration_name(iterResult, i); %#ok<AGROW>
```
같은 파일의 `function name = iteration_name(iterResult, index)` 블록(`:80-95`)을 지운다. `safe_property`와 `numeric_property`는 다른 곳에서 쓰므로 남긴다.

`st_collect_decision_points.m:47`:
```matlab
    [blockType, objectPath] = st_decision_object_path(blockPath, root);
```
같은 파일의 `read_block_type`, `classify_block`, `conditional_port` 세 함수(`:85-139`)를 지운다.

`st_final_document_table.m:250`:
```matlab
usable = st_is_real_iteration_name(iterationName);
```
같은 파일의 `function tf = is_real_iteration_name(iterationName)` 블록(`:274-277`)을 지운다.

- [ ] **Step 5: 테스트 통과 확인**

Run: `runtests({'tests/unit/test_decision_outcomes.m', 'tests/unit/test_specification_decision_blocks.m', 'tests/unit/test_export_final_document.m'})`
Expected: 새 테스트 3개와 `testPortBlocksAreNotRecordedOnTheirOwn` PASS. `test_export_final_document`는 이전과 같은 결과다. 특히 `testIterationWithoutAUsableNameFallsBackToTheTestCase`가 PASS여야 한다.

정적 확인(MATLAB 없이): 지운 이름이 남아 있지 않아야 한다.
```bash
grep -rn "iteration_name(\|classify_block(\|is_real_iteration_name(" src
```
Expected: `st_result_iteration_name(`와 `st_is_real_iteration_name(`만 나온다.

- [ ] **Step 6: 커밋**

```bash
git add src/reporting/st_result_iteration_name.m src/reporting/st_decision_object_path.m src/exporting/st_is_real_iteration_name.m src/reporting/st_collect_test_result_summary.m src/reporting/st_collect_decision_points.m src/exporting/st_final_document_table.m tests/unit/test_decision_outcomes.m tests/unit/test_specification_decision_blocks.m
git commit -m "refactor(reporting): iteration 이름과 분기 객체 경로 규칙을 공용 함수로 꺼낸다"
```
(본문에 이유 한 단락: DecisionOutcomes 수집이 판정 시트·DecisionPoints와 같은 키와 같은 분기 판단을 써야 한다. 그리고 Co-Authored-By 줄.)

---

### Task 2: `DecisionOutcomes` 수집과 리포트 기록

**Files:**
- Create: `src/reporting/st_cut_relative_path.m`
- Create: `src/reporting/st_decision_outcome_counts.m`
- Create: `src/reporting/st_collect_decision_outcomes.m`
- Modify: `src/reporting/st_export_result_set_report.m:219-226`, `:517-535`
- Modify: `src/reporting/st_generate_test_report.m:84-125` 뒤, `:146-150`, `:289-316`
- Test: `tests/unit/test_decision_outcomes.m`

**Interfaces:**
- Consumes: `st_result_iteration_name`, `st_decision_object_path` (Task 1), 기존 `st_collect_test_case_results`, `st_flatten_coverage_results`, `st_coverage_object_path`
- Produces: `relative = st_cut_relative_path(blockPath, cutPath)` → string. CUT 자신은 `"."`, 밖이면 `""`
- Produces: `[counts, texts] = st_decision_outcome_counts(description)` → N×2 double, N×1 string. T/F 블록이 아니면 `zeros(0,2)`
- Produces: `rows = st_collect_decision_outcomes(resultObj, targetConfig, runLabel, cfg)` → table. 열은 Global Constraints의 `DecisionOutcomes` 열

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/unit/test_decision_outcomes.m`에 추가

```matlab
function testRelativePathIsKeyedBelowTheCut(testCase)
verifyEqual(testCase, st_cut_relative_path("TOP/CUT/Switch1", "TOP/CUT"), "Switch1");
verifyEqual(testCase, st_cut_relative_path("TOP/CUT", "TOP/CUT"), ".");
verifyEqual(testCase, st_cut_relative_path("TOP/Other/Switch1", "TOP/CUT"), "");
verifyEqual(testCase, st_cut_relative_path("TOP/CUTX/Switch1", "TOP/CUT"), "");
end

function testRelativePathCollapsesNewlinesAndTrailingSpaces(testCase)
verifyEqual(testCase, st_cut_relative_path( ...
    "TOP/CUT/For" + newline + "Iterator", "TOP/CUT"), "For Iterator");
verifyEqual(testCase, st_cut_relative_path("TOP/X /If1", "TOP/X "), "If1");
end

function testCountsKeepTrueAndFalsePerDecision(testCase)
description = struct('decision', [ ...
    fake_decision('if', ["true","false"], [3 0]), ...
    fake_decision('elseif', ["false","true"], [5 2])]);
[counts, texts] = st_decision_outcome_counts(description);
verifyEqual(testCase, counts, [3 0; 2 5]);
verifyEqual(testCase, texts, ["if"; "elseif"]);
end

function testCountsIgnoreOutcomeTextCase(testCase)
description = struct('decision', fake_decision('loop', ["False","TRUE"], [3 30]));
verifyEqual(testCase, st_decision_outcome_counts(description), [30 3]);
end

function testBlockWithAThreeWayDecisionIsNotDescribed(testCase)
description = struct('decision', fake_decision('max', ["in1","in2","in3"], [1 0 2]));
verifyEmpty(testCase, st_decision_outcome_counts(description));
end

function testBlockWithNonBooleanOutcomeTextIsNotDescribed(testCase)
description = struct('decision', fake_decision('relay', ["on","off"], [1 1]));
verifyEmpty(testCase, st_decision_outcome_counts(description));
end

function testOneNonBooleanDecisionDropsTheWholeBlock(testCase)
% Keeping only the two-way decision would shift the order the final
% document pairs D lines with.
description = struct('decision', [ ...
    fake_decision('a', ["true","false"], [1 1]), ...
    fake_decision('b', ["x","y"], [1 1])]);
verifyEmpty(testCase, st_decision_outcome_counts(description));
end

function testEmptyDescriptionIsNotDescribed(testCase)
verifyEmpty(testCase, st_decision_outcome_counts([]));
verifyEmpty(testCase, st_decision_outcome_counts(struct('decision', [])));
end

function testBothReportsWriteTheDecisionOutcomesSheet(testCase)
root = st_project_root();
for file = ["st_export_result_set_report.m", "st_generate_test_report.m"]
    source = fileread(fullfile(root, 'src', 'reporting', char(file)));
    verifyNotEmpty(testCase, regexp(source, ...
        "writetable\(decisionOutcomes, path, 'Sheet', 'DecisionOutcomes'\)", 'once'), ...
        char(file));
    verifyNotEmpty(testCase, regexp(source, 'st_collect_decision_outcomes\(', 'once'), ...
        char(file));
end
end

function testVerdictOnlyReportStillCollectsDecisionOutcomes(testCase)
% A LEAN collection writes only what the final document reads, and the
% final document reads this sheet, so it sits next to DecisionPoints,
% outside the verdict-only branch.
source = fileread(fullfile(st_project_root(), 'src', 'reporting', ...
    'st_export_result_set_report.m'));
verifyNotEmpty(testCase, regexp(source, ...
    ['decisionPoints = collect_decision_points\(resultObj, targetConfig, cfg\);\s*' ...
     'decisionOutcomes = st_collect_decision_outcomes\('], 'once'));
end

function d = fake_decision(text, outcomeTexts, executionCounts)
outcomes = struct('text', cellstr(outcomeTexts), ...
    'executionCount', num2cell(executionCounts));
d = struct('text', text, 'outcome', outcomes);
end
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `runtests('tests/unit/test_decision_outcomes.m')`
Expected: 새 테스트 10개가 `Undefined function` 또는 regexp 빈 결과로 FAIL. Task 1 테스트는 PASS.

- [ ] **Step 3: 순수 함수 작성**

`src/reporting/st_cut_relative_path.m`:

```matlab
function relative = st_cut_relative_path(blockPath, cutPath)
%ST_CUT_RELATIVE_PATH A block path below its CUT, as a lookup key.
% The recording session and the export session can reach the CUT under
% different absolute paths (a standalone bundle renames the model), so
% DecisionOutcomes is keyed by the path below the CUT. The CUT itself is
% ".", and a block outside the CUT gives "".
%
% Whitespace runs collapse to one space. Simulink default names carry a
% newline ("For<newline>Iterator") and readtable trims text cells, so raw
% text would not match between the sheet and the model.
relative = "";
blockPath = squash(blockPath);
cutPath = squash(cutPath);
if strlength(cutPath) == 0 || strlength(blockPath) == 0
    return;
end
if blockPath == cutPath
    relative = ".";
    return;
end
% A CUT whose name ends in a space keeps one space before the separator.
for prefix = [cutPath + "/", cutPath + " /"]
    if startsWith(blockPath, prefix)
        relative = extractAfter(blockPath, strlength(prefix));
        return;
    end
end
end

function text = squash(text)
text = string(text);
if ~isscalar(text) || ismissing(text)
    text = "";
    return;
end
text = strtrim(regexprep(text, '\s+', ' '));
end
```

`src/reporting/st_decision_outcome_counts.m`:

```matlab
function [counts, texts] = st_decision_outcome_counts(description)
%ST_DECISION_OUTCOME_COUNTS True and false execution counts per decision.
% DESCRIPTION is the second output of decisioninfo for one block. Row k of
% COUNTS is [TrueCount FalseCount] for description.decision(k), and TEXTS(k)
% is that decision's text.
%
% Only a block whose every decision has exactly the outcomes true and false
% is described. Anything else returns empty for the whole block: keeping
% the two-way decisions of a mixed block would shift the decision order
% the final document pairs its D lines with.
counts = zeros(0,2);
texts = strings(0,1);
if ~isstruct(description) || ~isscalar(description) || ...
        ~isfield(description, 'decision') || isempty(description.decision)
    return;
end
decisions = description.decision;
found = zeros(numel(decisions), 2);
names = strings(numel(decisions), 1);
for k = 1:numel(decisions)
    if ~isfield(decisions(k), 'outcome') || numel(decisions(k).outcome) ~= 2
        return;
    end
    outcomes = decisions(k).outcome;
    labels = lower(strtrim(string({outcomes.text})));
    t = find(labels == "true");
    f = find(labels == "false");
    if ~isscalar(t) || ~isscalar(f)
        return;
    end
    found(k,:) = [double(outcomes(t).executionCount), ...
        double(outcomes(f).executionCount)];
    if isfield(decisions(k), 'text')
        names(k) = string(decisions(k).text);
    end
end
counts = found;
texts = names;
end
```

- [ ] **Step 4: 수집기 작성** — `src/reporting/st_collect_decision_outcomes.m`

```matlab
function rows = st_collect_decision_outcomes(resultObj, targetConfig, runLabel, cfg)
%ST_COLLECT_DECISION_OUTCOMES Which way each two-way branch went, per iteration.
% For every Test Iteration result, or the Test Case result when it has no
% iterations, asks that unit's own coverage how often each true/false
% decision of the CUT's direct children evaluated true and false. The final
% document turns these counts into [T], [F], [T/F] or [-] on the matching
% specification row.
%
% Every scanned unit also gets one Kind="UNIT" row, so the reader can tell
% "this row has no two-way branch" from "this row was never scanned". A
% unit without coverage of its own gets no UNIT row and is logged.
%
% Collection never stops the report: a failure is logged and whatever was
% collected so far is returned.
if nargin < 4, cfg = []; end
rows = empty_rows();
label = string(runLabel);
timer = tic;
units = 0;
st_log(cfg, 'INFO', 'Decision outcome scan start | Run=%s', label);
try
    caseResults = st_collect_test_case_results(resultObj);
    for c = 1:numel(caseResults)
        [found, scanned] = collect_case(caseResults{c}, targetConfig, label, cfg);
        rows = [rows; found]; %#ok<AGROW>
        units = units + scanned;
    end
catch ME
    st_log(cfg, 'WARN', 'Decision outcome scan stopped early | Run=%s | %s', ...
        label, ME.message);
end
st_log(cfg, 'INFO', ...
    'Decision outcome scan end | Run=%s | Units=%d | Rows=%d | elapsed=%.3f sec', ...
    label, units, height(rows), toc(timer));
end


function [rows, scanned] = collect_case(tcResult, targetConfig, label, cfg)
rows = empty_rows();
scanned = 0;
caseName = property_text(tcResult, 'Name');
index = find(string(targetConfig.TestCaseName) == caseName, 1);
if isempty(index)
    st_log(cfg, 'WARN', ...
        'Decision outcome scan skipped a test case not in the target list | TestCase=%s', ...
        caseName);
    return;
end
target = targetConfig(index, :);
root = st_coverage_object_path(target);
cutName = string(target.CUTName);
blocks = direct_children(root, cfg);
[units, names] = result_units(tcResult);
for u = 1:numel(units)
    cvd = unit_coverage(units{u}, root);
    if isempty(cvd)
        st_log(cfg, 'WARN', ...
            'Decision outcome scan found no coverage for a unit | TestCase=%s | Iteration=%s', ...
            caseName, names(u));
        continue;
    end
    scanned = scanned + 1;
    rows = [rows; outcome_row(label, cutName, caseName, names(u), ...
        "UNIT", "", 0, "", 0, 0)]; %#ok<AGROW>
    for b = 1:numel(blocks)
        rows = [rows; block_rows(cvd, blocks(b), root, label, cutName, ...
            caseName, names(u), cfg)]; %#ok<AGROW>
    end
end
end


function blocks = direct_children(root, cfg)
% The same direct children st_collect_decision_points walks. LookUnderMasks
% and FollowLinks stay on: without them a masked or linked CUT has none.
blocks = strings(0,1);
try
    found = find_system(root, 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'Type', 'Block');
    blocks = string(found(:));
catch ME
    st_log(cfg, 'WARN', 'Decision outcome scan could not list blocks | Root=%s | %s', ...
        root, ME.message);
end
end


function [units, names] = result_units(tcResult)
% A Test Case without iterations is its own single unit. Its name stays
% empty, the key the verdict fallback uses for the Test Case level.
iterations = [];
try
    iterations = getIterationResults(tcResult);
catch
end
if isempty(iterations)
    units = {tcResult};
    names = "";
    return;
end
units = cell(numel(iterations), 1);
names = strings(numel(iterations), 1);
for i = 1:numel(iterations)
    units{i} = iterations(i);
    names(i) = st_result_iteration_name(iterations(i), i);
end
end


function cvd = unit_coverage(unit, root)
% A unit can carry coverage for several models. The CUT's own is the one
% that answers for the CUT path.
cvd = [];
try
    objects = st_flatten_coverage_results(getCoverageResults(unit));
catch
    return;
end
for i = 1:numel(objects)
    try
        if ~isempty(decisioninfo(objects{i}, root))
            cvd = objects{i};
            return;
        end
    catch
        % A coverage object for another model simply does not answer.
    end
end
end


function rows = block_rows(cvd, blockPath, root, label, cutName, caseName, iterationName, cfg)
rows = empty_rows();
[blockType, objectPath] = st_decision_object_path(char(blockPath), root);
if isempty(blockType), return; end
description = block_description(cvd, objectPath, char(blockPath));
if isempty(description), return; end
[counts, texts] = st_decision_outcome_counts(description);
if isempty(counts)
    st_log(cfg, 'DEBUG', ...
        'Decision outcome scan skipped a block without two-way decisions | Path=%s | BlockType=%s', ...
        blockPath, blockType);
    return;
end
relative = st_cut_relative_path(blockPath, root);
for k = 1:size(counts, 1)
    rows = [rows; outcome_row(label, cutName, caseName, iterationName, ...
        "DECISION", relative, k, texts(k), counts(k,1), counts(k,2))]; %#ok<AGROW>
end
end


function description = block_description(cvd, objectPath, blockPath)
% A conditional CUT's branch sits on its port block on some releases and on
% the subsystem on others, as st_collect_decision_points found. The
% subsystem is asked with descendants ignored so inner blocks stay out.
description = [];
try
    [values, description] = decisioninfo(cvd, objectPath);
    if ~isempty(values), return; end
catch
end
description = [];
if strcmp(objectPath, blockPath), return; end
try
    [values, description] = decisioninfo(cvd, blockPath, 1);
    if isempty(values), description = []; end
catch
    description = [];
end
end


function T = empty_rows()
T = table(strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), zeros(0,1), strings(0,1), zeros(0,1), ...
    zeros(0,1), 'VariableNames', column_names());
end


function T = outcome_row(label, cutName, caseName, iterationName, kind, ...
        relative, index, text, trueCount, falseCount)
T = table(string(label), string(cutName), string(caseName), ...
    string(iterationName), string(kind), string(relative), double(index), ...
    string(text), double(trueCount), double(falseCount), ...
    'VariableNames', column_names());
end


function names = column_names()
names = {'Run','CUTName','TestCaseName','IterationName','Kind', ...
    'RelativePath','DecisionIndex','DecisionText','TrueCount','FalseCount'};
end


function value = property_text(object, name)
value = "";
try
    value = string(object.(name));
catch
end
end
```

- [ ] **Step 5: PER_CUT 리포트에 연결** — `src/reporting/st_export_result_set_report.m`

`:219` 바로 아래에 한 줄을 넣고, `write_summary` 호출에 인자를 더한다:

```matlab
decisionPoints = collect_decision_points(resultObj, targetConfig, cfg);
decisionOutcomes = st_collect_decision_outcomes(resultObj, targetConfig, resultLabel, cfg);

summaryPath = fullfile(outputDirectory, 'TestSummary.xlsx');
stepTimer = report_step_start(cfg, 6, 6, 'Write Test Summary Excel');
try
    write_summary(summaryPath, resultName, ...
        targets, iterations, coverage, artifacts, coverageReportMode, ...
        decisionPoints, decisionOutcomes);
```

`write_summary`(`:517`) 시그니처와 본문:

```matlab
function write_summary(path, resultName, targets, iterations, coverage, ...
        artifacts, coverageReportMode, decisionPoints, decisionOutcomes)
```
`writetable(decisionPoints, path, 'Sheet', 'DecisionPoints');` 바로 아래에:
```matlab
writetable(decisionOutcomes, path, 'Sheet', 'DecisionOutcomes');
```

- [ ] **Step 6: BATCH 리포트에 연결** — `src/reporting/st_generate_test_report.m`

`step('Exporting the raw ResultSets');` 바로 위(커버리지 수집 `try/catch`가 끝난 뒤)에:

```matlab
step('Collecting decision outcomes');
initialOutcomes = st_collect_decision_outcomes( ...
    runContext.InitialResult, targetConfig, 'INITIAL', cfg);
if logical(runContext.RerunPerformed)
    finalOutcomes = st_collect_decision_outcomes( ...
        runContext.FinalResult, targetConfig, 'FINAL', cfg);
else
    % Without a rerun both labels name the same ResultSet, as with the
    % coverage rows above, so the walk is not repeated.
    finalOutcomes = initialOutcomes;
    finalOutcomes.Run(:) = "FINAL";
end
decisionOutcomes = [initialOutcomes; finalOutcomes];
```

`write_summary_workbook` 호출(`:146-149`) 끝에 인자를 더한다:

```matlab
    write_summary_workbook(summaryPath, targets, iterations, coverage, ...
        coverageFilters, runContext.ExpectedUpdateResult, ...
        workflowResult, workflowPlan, ...
        cfg, runId, runDirectory, artifacts, decisionOutcomes);
```

`write_summary_workbook`(`:289`) 시그니처 끝에 `decisionOutcomes`를 더하고, `writetable(coverageFilters, path, 'Sheet', 'CoverageFilters');` 바로 아래에:

```matlab
writetable(decisionOutcomes, path, 'Sheet', 'DecisionOutcomes');
```

- [ ] **Step 7: 테스트 통과 확인**

Run: `runtests({'tests/unit/test_decision_outcomes.m', 'tests/unit/test_log_adoption.m'})`
Expected: `test_decision_outcomes` 전부 PASS. `test_log_adoption`은 이전과 같은 결과다(새 `st_log` 호출이 로그 규칙을 어기지 않는지 본다).

- [ ] **Step 8: 커밋**

```bash
git add src/reporting/st_cut_relative_path.m src/reporting/st_decision_outcome_counts.m src/reporting/st_collect_decision_outcomes.m src/reporting/st_export_result_set_report.m src/reporting/st_generate_test_report.m tests/unit/test_decision_outcomes.m
git commit -m "feat(reporting): iteration별 분기 결과를 DecisionOutcomes 시트로 남긴다"
```
(본문: 수집 단위, UNIT 행의 의미, VERDICT에서도 수집하는 이유, 실기 미확인 항목. 그리고 Co-Authored-By 줄.)

---

### Task 3: 최종 문서에 결과 표기

**Files:**
- Create: `src/exporting/st_final_document_decision_outcomes.m`
- Modify: `src/exporting/st_format_specification_decision_blocks.m:1-10`, `:27-40`, `:64-122`
- Modify: `src/exporting/st_final_document_table.m:1`, `:34-35`, `:140-180`, `:214-218`
- Modify: `src/exporting/st_export_final_document.m:85-102`, `:222`, `:260-262` 근처
- Test: `tests/unit/test_decision_outcomes.m`, `tests/unit/test_export_final_document.m`

**Interfaces:**
- Consumes: `st_cut_relative_path` (Task 2), `st_is_real_iteration_name` (Task 1), 시트 열 (Task 2)
- Produces: `outcomes = st_final_document_decision_outcomes(cfg, source)` → struct. 필드는 `Units`(double), `Notes`(No/TestCaseName/Reason/Message table), `Lookup`
  - `Lookup`은 function handle `result = Lookup(testCaseName, iterationName, relativePath)`. `result.UnitFound`(logical), `result.Counts`(N×2 double)를 돌려준다
  - workbook이 하나도 없으면 `Lookup`은 `[]`
- Produces: `[specification, details, outcomeReasons] = st_format_specification_decision_blocks(specification, cfg, outcomeLookup)`. `outcomeReasons`는 행 수만큼의 string column
- Produces: `document = st_final_document_table(cfg, specification, outcomes, source, rowReasons)`. `rowReasons`는 선택 인자

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/unit/test_decision_outcomes.m`에 추가

```matlab
function testLookupReadsCountsInDecisionOrder(testCase)
file = outcome_workbook(testCase, ...
    ["FINAL","FINAL","FINAL"], ["UNIT","DECISION","DECISION"], ...
    ["","If1","If1"], [0 1 2], [0 3 0], [0 0 4]);
outcomes = st_final_document_decision_outcomes(base_config(), source_with(file, "ANY"));
found = outcomes.Lookup("Case1", "Iteration 1", "If1");
verifyTrue(testCase, found.UnitFound);
verifyEqual(testCase, found.Counts, [3 0; 0 4]);
verifyEqual(testCase, outcomes.Units, 1);
end

function testBatchWorkbookPrefersTheFinalRows(testCase)
file = outcome_workbook(testCase, ...
    ["INITIAL","INITIAL","FINAL","FINAL"], ["UNIT","DECISION","UNIT","DECISION"], ...
    ["","Sw","","Sw"], [0 1 0 1], [0 1 0 0], [0 0 0 7]);
outcomes = st_final_document_decision_outcomes(base_config(), source_with(file, "ANY"));
found = outcomes.Lookup("Case1", "Iteration 1", "Sw");
verifyEqual(testCase, found.Counts, [0 7]);
end

function testPlaceholderIterationIsLookedUpAtTheTestCaseLevel(testCase)
file = outcome_workbook(testCase, ["FINAL","FINAL"], ["UNIT","DECISION"], ...
    ["","Sw"], [0 1], [0 2], [0 0], ["",""]);
outcomes = st_final_document_decision_outcomes(base_config(), source_with(file, "ANY"));
found = outcomes.Lookup("Case1", "<기본 설정>", "Sw");
verifyTrue(testCase, found.UnitFound);
verifyEqual(testCase, found.Counts, [2 0]);
end

function testLookupMatchesBlockNamesWithNewlines(testCase)
file = outcome_workbook(testCase, ["FINAL","FINAL"], ["UNIT","DECISION"], ...
    ["","For Iterator"], [0 1], [0 1], [0 1]);
outcomes = st_final_document_decision_outcomes(base_config(), source_with(file, "ANY"));
found = outcomes.Lookup("Case1", "Iteration 1", "For" + newline + "Iterator");
verifyEqual(testCase, found.Counts, [1 1]);
end

function testWorkbookWithoutTheSheetMarksRowsUnavailable(testCase)
folder = tempname; mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
file = fullfile(folder, 'TestSummary.xlsx');
writetable(table("x"), file, 'Sheet', 'Iterations', 'UseExcel', false);
outcomes = st_final_document_decision_outcomes(base_config(), source_with(file, "ANY"));
[formatted, ~, reasons] = st_format_specification_decision_blocks( ...
    one_row_specification(switch_item("TOP/CUT/Sw")), base_config(), outcomes.Lookup);
verifyEqual(testCase, formatted.DecisionBlocks(1), "Sw" + newline + "D1 [T/F]Switch (u > 0)");
verifyEqual(testCase, reasons(1), "DECISION_OUTCOME_UNAVAILABLE");
end

function testFormatterWritesTheActualOutcome(testCase)
lookup = fake_lookup(struct('Sw', [4 0]));
[formatted, ~, reasons] = st_format_specification_decision_blocks( ...
    one_row_specification(switch_item("TOP/CUT/Sw")), base_config(), lookup);
verifyEqual(testCase, formatted.DecisionBlocks(1), "Sw" + newline + "D1 [T]Switch (u > 0)");
verifyEqual(testCase, reasons(1), "");
end

function testFormatterLabelsEveryCombination(testCase)
items = [if_item("TOP/CUT/If1", "a > 0"); if_item("TOP/CUT/If1", "elseif b > 0"); ...
    switch_item("TOP/CUT/Sw"); switch_item("TOP/CUT/Sw2")];
lookup = fake_lookup(struct('If1', [1 1; 0 0], 'Sw', [0 2], 'Sw2', [5 5]));
formatted = st_format_specification_decision_blocks( ...
    one_row_specification(items), base_config(), lookup);
lines = split(formatted.DecisionBlocks(1), newline);
verifyEqual(testCase, lines, ["If1"; "D1 [T/F]IF (a > 0)"; "D2 [-]IF (elseif b > 0)"; ...
    "Sw"; "D3 [F]Switch (u > 0)"; "Sw2"; "D4 [T/F]Switch (u > 0)"]);
end

function testCountMismatchKeepsTheStaticMarkAndSaysSo(testCase)
items = [if_item("TOP/CUT/If1", "a > 0"); if_item("TOP/CUT/If1", "elseif b > 0")];
lookup = fake_lookup(struct('If1', [1 0]));
[formatted, ~, reasons] = st_format_specification_decision_blocks( ...
    one_row_specification(items), base_config(), lookup);
verifyEqual(testCase, count(formatted.DecisionBlocks(1), "[T/F]"), 2);
verifyEqual(testCase, reasons(1), "DECISION_OUTCOME_MISMATCH");
end

function testBlockWithoutTwoWayDecisionsKeepsTheStaticMarkSilently(testCase)
item = struct('BlockType', 'Saturate', 'Name', 'Sat', 'Path', 'TOP/CUT/Sat', ...
    'Outcome', 'LIMIT', 'Expression', 'UpperLimit=1', 'ExpressionStatus', 'OK', 'Message', '');
lookup = fake_lookup(struct());
[formatted, ~, reasons] = st_format_specification_decision_blocks( ...
    one_row_specification(item), base_config(), lookup);
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D1 [T/F]Saturate"));
verifyEqual(testCase, reasons(1), "");
end

function testConditionalCutIsLookedUpAsDot(testCase)
item = struct('BlockType', 'EnablePort', 'Name', 'CUT', 'Path', 'TOP/CUT', ...
    'Outcome', 'ON/OFF', 'Expression', 'enable', 'ExpressionStatus', 'OK', 'Message', '');
lookup = fake_lookup(containers.Map({'.'}, {[0 9]}));
formatted = st_format_specification_decision_blocks( ...
    one_row_specification(item), base_config(), lookup);
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D1 [F]Enable"));
end

function testFormatterWithoutALookupIsUnchanged(testCase)
specification = one_row_specification(switch_item("TOP/CUT/Sw"));
[formatted, ~, reasons] = st_format_specification_decision_blocks(specification, base_config());
verifyEqual(testCase, formatted.DecisionBlocks(1), "Sw" + newline + "D1 [T/F]Switch (u > 0)");
verifyEqual(testCase, reasons(1), "");
end

function testFinalDocumentWiresTheOutcomes(testCase)
source = fileread(fullfile(st_project_root(), 'src', 'exporting', ...
    'st_export_final_document.m'));
verifyNotEmpty(testCase, regexp(source, 'st_final_document_decision_outcomes\(cfg, source\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'st_final_document_table\(cfg, specification, outcomes, source, outcomeReasons\)', 'once'));
end

function cfg = base_config()
cfg = struct('VerboseLogging', false);
end

function source = source_with(file, stage)
source = struct('Mode', 'BATCH', 'Workbooks', table(string(stage), 0, "", ...
    string(file), 'VariableNames', {'Stage','No','TestCaseName','File'}));
end

function file = outcome_workbook(testCase, runs, kinds, paths, indices, trues, falses, iterations)
if nargin < 8
    iterations = repmat("Iteration 1", 1, numel(runs));
end
folder = tempname; mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
file = fullfile(folder, 'TestSummary.xlsx');
count = numel(runs);
writetable(table(runs(:), repmat("CUT", count, 1), repmat("Case1", count, 1), ...
    iterations(:), kinds(:), paths(:), indices(:), repmat("", count, 1), ...
    trues(:), falses(:), 'VariableNames', {'Run','CUTName','TestCaseName', ...
    'IterationName','Kind','RelativePath','DecisionIndex','DecisionText', ...
    'TrueCount','FalseCount'}), file, 'Sheet', 'DecisionOutcomes', 'UseExcel', false);
end

function lookup = fake_lookup(counts)
% counts maps a relative path to its [True False] matrix. The unit is
% always found, as if the row was scanned.
if isstruct(counts)
    keys = fieldnames(counts);
    values = struct2cell(counts);
    if isempty(keys)
        counts = containers.Map('KeyType', 'char', 'ValueType', 'any');
    else
        counts = containers.Map(keys, values);
    end
end
lookup = @(~, ~, relative) struct('UnitFound', true, ...
    'Counts', value_or_empty(counts, char(relative)));
end

function value = value_or_empty(map, key)
value = zeros(0,2);
if isKey(map, key), value = map(key); end
end

function item = switch_item(path)
[~, name] = fileparts(path);
item = struct('BlockType', 'Switch', 'Name', name, 'Path', char(path), ...
    'Outcome', 'T/F', 'Expression', 'u > 0', 'ExpressionStatus', 'OK', 'Message', '');
end

function item = if_item(path, expression)
[~, name] = fileparts(path);
item = struct('BlockType', 'If', 'Name', name, 'Path', char(path), ...
    'Outcome', 'T/F', 'Expression', char(expression), 'ExpressionStatus', 'OK', 'Message', '');
end

function specification = one_row_specification(items)
raw = string(jsonencode(items(:)));
specification = table("Case1", "TOP/CUT", "Iteration 1", raw, 'VariableNames', ...
    {'테스트 케이스명', 'CUTPath', 'Iteration명', 'DecisionBlocks'});
end
```

`outcome_workbook`은 기본으로 모든 행을 `"Iteration 1"`로 채운다. `testPlaceholderIterationIsLookedUpAtTheTestCaseLevel`만 8번째 인자 `["",""]`로 Test Case 단위 행을 만든다.

`tests/unit/test_export_final_document.m`에 추가한다. 이 파일의 기존 fixture `sample_specification`, `outcomes_with`, `empty_source`, `base_config`를 쓴다:

```matlab
function testDecisionOutcomeReasonIsInformational(testCase)
% A [T/F] left in Description is worth noting, but on its own it does not
% send anyone to Test Manager.
specification = sample_specification();
outcomes = outcomes_with("Controller_12345", "Iteration 1", "Passed", "");
document = st_final_document_table(base_config(), specification, outcomes, ...
    empty_source(), "DECISION_OUTCOME_UNAVAILABLE");
verifyEqual(testCase, document.Results.('확인 필요')(1), "");
verifyTrue(testCase, contains(document.Results.('확인 사유')(1), ...
    "DECISION_OUTCOME_UNAVAILABLE"));
end

function testDecisionOutcomeReasonDoesNotHideAFailure(testCase)
specification = sample_specification();
outcomes = outcomes_with("Controller_12345", "Iteration 1", "Failed", "");
document = st_final_document_table(base_config(), specification, outcomes, ...
    empty_source(), "DECISION_OUTCOME_MISMATCH");
verifyEqual(testCase, document.Results.('확인 필요')(1), "Y");
end
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `runtests({'tests/unit/test_decision_outcomes.m', 'tests/unit/test_export_final_document.m'})`
Expected: 새 테스트 14개가 FAIL. 원인은 `st_final_document_decision_outcomes` 없음, 포맷터의 출력 인자 수 초과, `st_final_document_table`의 입력 인자 수 초과다.

- [ ] **Step 3: 읽기 함수 작성** — `src/exporting/st_final_document_decision_outcomes.m`

```matlab
function outcomes = st_final_document_decision_outcomes(cfg, source)
%ST_FINAL_DOCUMENT_DECISION_OUTCOMES Read which way each branch went, per row.
% Reads the DecisionOutcomes sheets of the workbooks st_final_document_run_source
% listed: the same files, and the same stage, the verdicts come from.
%
% outcomes.Lookup(testCaseName, iterationName, relativePath) returns a
% struct. UnitFound says whether that row's test unit was scanned at all.
% Counts holds one [TrueCount FalseCount] row per decision of the block, in
% decision order, and is empty for a block with no two-way decision. A row
% whose iteration name is a placeholder is looked up at the Test Case
% level, as its verdict is. Lookup is [] when no workbook was resolved, so
% a document made before any run carries no outcome reasons at all.
outcomes = struct('Units', 0, 'Notes', note_table(), 'Lookup', []);
if isempty(source) || ~isfield(source, 'Workbooks') || height(source.Workbooks) == 0
    return;
end
st_log(cfg, 'INFO', 'Final document decision outcomes start | Workbooks=%d', ...
    height(source.Workbooks));
units = containers.Map('KeyType', 'char', 'ValueType', 'logical');
decisions = containers.Map('KeyType', 'char', 'ValueType', 'any');
conflicts = strings(0,1);
for i = 1:height(source.Workbooks)
    entry = source.Workbooks(i,:);
    rows = read_rows(cfg, entry.File);
    if isempty(rows), continue; end
    rows = select_stage(rows, entry.Stage);
    for r = 1:height(rows)
        unit = unit_key(rows.TestCaseName(r), rows.IterationName(r));
        if rows.Kind(r) == "UNIT"
            units(char(unit)) = true;
            continue;
        end
        key = char(unit + "|" + squash(rows.RelativePath(r)));
        index = rows.DecisionIndex(r);
        value = [rows.TrueCount(r) rows.FalseCount(r)];
        current = nan(0,2);
        if isKey(decisions, key), current = decisions(key); end
        if size(current, 1) >= index && ~any(isnan(current(index,:))) && ...
                ~isequal(current(index,:), value)
            conflicts(end+1,1) = string(key); %#ok<AGROW>
        end
        current(size(current,1)+1:index, :) = NaN;
        current(index,:) = value;
        decisions(key) = current;
    end
end
for key = unique(conflicts).'
    remove(decisions, char(key));
    outcomes.Notes = [outcomes.Notes; table(NaN, extractBefore(key, "|"), ...
        "DECISION_OUTCOME_AMBIGUOUS", "Different counts recorded for " + key, ...
        'VariableNames', {'No','TestCaseName','Reason','Message'})];
    st_log(cfg, 'WARN', 'Final document decision outcome ambiguous | Key=%s', key);
end
% A gap in the decision order cannot be paired with D lines by position.
for key = string(keys(decisions))
    if any(isnan(decisions(char(key))), 'all')
        remove(decisions, char(key));
        st_log(cfg, 'WARN', 'Final document decision outcome incomplete | Key=%s', key);
    end
end
outcomes.Units = units.Count;
outcomes.Lookup = @(testCaseName, iterationName, relativePath) ...
    lookup(units, decisions, testCaseName, iterationName, relativePath);
st_log(cfg, 'INFO', ...
    'Final document decision outcomes end | Units=%d | Blocks=%d | Notes=%d', ...
    units.Count, decisions.Count, height(outcomes.Notes));
end


function result = lookup(units, decisions, testCaseName, iterationName, relativePath)
if ~st_is_real_iteration_name(iterationName)
    iterationName = "";
end
unit = unit_key(testCaseName, iterationName);
result = struct('UnitFound', isKey(units, char(unit)), 'Counts', zeros(0,2));
key = char(unit + "|" + squash(relativePath));
if isKey(decisions, key)
    result.Counts = decisions(key);
end
end


function rows = read_rows(cfg, file)
% A workbook written before this sheet existed simply has none.
rows = [];
text = ["Run","CUTName","TestCaseName","IterationName","Kind","RelativePath","DecisionText"];
try
    if ~any(string(sheetnames(file)) == "DecisionOutcomes"), return; end
    options = detectImportOptions(file, 'Sheet', 'DecisionOutcomes', ...
        'TextType', 'string', 'VariableNamingRule', 'preserve');
    % An all-blank column, or an iteration named "001", must not come back
    % as a number.
    options = setvartype(options, ...
        intersect(cellstr(text), options.VariableNames), 'string');
    rows = readtable(file, options);
catch ME
    st_log(cfg, 'WARN', 'Final document decision outcomes unreadable | File=%s | %s', ...
        file, ME.message);
    rows = [];
    return;
end
required = ["Run","TestCaseName","IterationName","Kind","RelativePath", ...
    "DecisionIndex","TrueCount","FalseCount"];
if ~all(ismember(required, string(rows.Properties.VariableNames)))
    st_log(cfg, 'WARN', 'Final document decision outcomes sheet is missing a column | File=%s', file);
    rows = [];
    return;
end
for name = intersect(text, string(rows.Properties.VariableNames))
    values = rows.(name);
    values(ismissing(values)) = "";
    rows.(name) = values;
end
end


function rows = select_stage(rows, stage)
% The verdict rule: a PER_CUT workbook names its stage, and a BATCH
% workbook holds both, FINAL first.
stage = upper(string(stage));
run = upper(rows.Run);
if stage ~= "ANY"
    picked = rows(run == stage, :);
elseif any(run == "FINAL")
    picked = rows(run == "FINAL", :);
else
    picked = rows(run == "INITIAL", :);
end
if height(picked) > 0, rows = picked; end
end


function key = unit_key(testCaseName, iterationName)
key = squash(testCaseName) + "|" + squash(iterationName);
end


function text = squash(text)
text = string(text);
if ~isscalar(text) || ismissing(text)
    text = "";
    return;
end
text = strtrim(regexprep(text, '\s+', ' '));
end


function T = note_table()
T = table(zeros(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'No','TestCaseName','Reason','Message'});
end
```

- [ ] **Step 4: 포맷터 변경** — `src/exporting/st_format_specification_decision_blocks.m`

시그니처와 머리(`:1-10`):

```matlab
function [specification, details, outcomeReasons] = st_format_specification_decision_blocks(specification, cfg, outcomeLookup)
%ST_FORMAT_SPECIFICATION_DECISION_BLOCKS Make the main list readable in Excel.
% The main DecisionBlocks cell contains a block Name line followed by a
% "D<number> [T/F]Type (expression)" line. The main cell prints T/F for every
% branch kind so the sheet reads uniformly as "a branch lives here".
% DecisionBlockDetails keeps the specific Outcome token together with the
% structured fields and one JSON object per row, so downstream processing
% does not depend on parsing the display.
%
% The final document passes OUTCOMELOOKUP (st_final_document_decision_outcomes).
% A two-way branch then shows what the row's test actually took: [T], [F],
% [T/F] or [-]. OUTCOMEREASONS says, per row, why a [T/F] was left in place.
% The specification export passes no lookup and its output is unchanged.
if nargin < 2, cfg = []; end
if nargin < 3, outcomeLookup = []; end
mainOutcome = "T/F";
outcomeReasons = repmat("", height(specification), 1);
```

D 줄 루프(`:71-103`)에서 `lines = strings(0,1);` 바로 위에 레이블 계산을 넣고, `entry` 줄을 바꾼다:

```matlab
    labels = repmat(mainOutcome, numel(decoded), 1);
    if ~isempty(outcomeLookup)
        [labels, outcomeReasons(row)] = outcome_labels(cfg, decoded, labels, ...
            cutPath, testCaseName, table_text(specification, row, "Iteration명"), ...
            outcomeLookup);
    end
```
```matlab
            entry = decision + " [" + labels(k) + "]" + displayType;
```

파일 끝(`log_message` 앞)에 로컬 함수 둘을 더한다:

```matlab
function [labels, reason] = outcome_labels(cfg, decoded, labels, cutPath, ...
        testCaseName, iterationName, outcomeLookup)
% A block's D lines are paired with its recorded decisions by position, so
% a block whose counts differ keeps [T/F]: pairing anyway would put one
% branch's result on another.
reason = "";
paths = strings(numel(decoded), 1);
for k = 1:numel(decoded)
    paths(k) = json_optional_text(decoded(k), 'Path');
end
unavailable = false;
mismatch = false;
for path = unique(paths(strlength(paths) > 0), 'stable').'
    items = find(paths == path);
    try
        found = outcomeLookup(testCaseName, iterationName, ...
            st_cut_relative_path(path, cutPath));
    catch ME
        log_message(cfg, 'WARN', ...
            'Decision outcome lookup failed | Case=%s | Path=%s | %s', ...
            testCaseName, path, ME.message);
        continue;
    end
    if ~found.UnitFound
        unavailable = true;
        continue;
    end
    if isempty(found.Counts)
        continue;
    end
    if size(found.Counts, 1) ~= numel(items)
        mismatch = true;
        log_message(cfg, 'WARN', ...
            'Decision outcome count mismatch | Case=%s | Path=%s | Lines=%d | Decisions=%d', ...
            testCaseName, path, numel(items), size(found.Counts, 1));
        continue;
    end
    for j = 1:numel(items)
        labels(items(j)) = outcome_label(found.Counts(j,:));
    end
end
codes = ["DECISION_OUTCOME_UNAVAILABLE", "DECISION_OUTCOME_MISMATCH"];
reason = strjoin(codes([unavailable, mismatch]), ' | ');
end


function label = outcome_label(counts)
tookTrue = counts(1) > 0;
tookFalse = counts(2) > 0;
if tookTrue && tookFalse
    label = "T/F";
elseif tookTrue
    label = "T";
elseif tookFalse
    label = "F";
else
    label = "-";
end
end
```

`strjoin`에 빈 배열을 주면 `""`가 나오는지 MATLAB에서 한 번 확인한다(`strjoin(strings(1,0), ' | ')` → `""`). 다르면 `if ~any([unavailable mismatch]), reason = ""; end`로 감싼다.

- [ ] **Step 5: 표 함수 변경** — `src/exporting/st_final_document_table.m`

```matlab
function document = st_final_document_table(cfg, specification, outcomes, source, rowReasons)
```
`naText = ...` 줄 바로 아래에:
```matlab
if nargin < 5 || isempty(rowReasons)
    rowReasons = repmat("", height(specification), 1);
end
```
`resolve_judgements` 호출(`:34-35`)과 정의(`:140`)에 `rowReasons`를 마지막 인자로 더한다:
```matlab
[judgement, results] = resolve_judgements( ...
    cfg, specification, outcomes, source, identifier, idReasons, rowReasons);
```
```matlab
function [judgement, results] = resolve_judgements(cfg, specification, outcomes, source, identifier, idReasons, rowReasons)
```
루프 안 `extractStatus` 분기 바로 아래, `needsReview` 판정 위에:
```matlab
    reasons(i) = join_reasons(reasons(i), rowReasons(i));
```
`only_informational`(`:214-218`)을 바꾼다:
```matlab
function tf = only_informational(reason)
% MAXTIME_UNAVAILABLE explains a blank cell the exporter already reported,
% and the DECISION_OUTCOME codes explain a [T/F] left in Description.
% Neither sends anyone to Test Manager on its own.
informational = ["MAXTIME_UNAVAILABLE", "DECISION_OUTCOME_UNAVAILABLE", ...
    "DECISION_OUTCOME_MISMATCH"];
tf = all(ismember(strtrim(split(string(reason), "|")), informational));
end
```

- [ ] **Step 6: 최종 문서에 연결** — `src/exporting/st_export_final_document.m`

`:93`의 포맷터 호출을 바꾸고, 노트·표·Metadata에 넘긴다:

```matlab
    decisionOutcomes = st_final_document_decision_outcomes(cfg, source);
    % Renders the DecisionBlocks JSON into the Description text, with the
    % outcome each row's test took where the run recorded one.
    [specification, ~, outcomeReasons] = st_format_specification_decision_blocks( ...
        specification, cfg, decisionOutcomes.Lookup);
    outcomes = st_final_document_outcomes(cfg, source);
    coverage = st_final_document_coverage(cfg, coverageSource, ...
        char(string(p.Results.CoveragePipelineId)), source);
    outcomes.Notes = [outcomes.Notes; coverage.Notes; decisions.Notes; ...
        decisionOutcomes.Notes];
    require_results(p.Results.RequireTestResults, source, outcomes);
    require_coverage(p.Results.RequireCoverage, coverage);
    document = st_final_document_table(cfg, specification, outcomes, source, outcomeReasons);
    metadata = build_metadata(cfg, source, coverage, decisionScope, ...
        height(specification), decisions, decisionOutcomes, outcomeReasons);
```

`build_metadata`(`:222`) 시그니처 끝에 `decisionOutcomes, outcomeReasons`를 더하고, `add('DecisionSourceCUTs', decisions.ByCut.Count);` 바로 아래에:

```matlab
add('DecisionOutcomeUnits', decisionOutcomes.Units);
add('DecisionOutcomeUnavailableRows', ...
    sum(contains(outcomeReasons, "DECISION_OUTCOME_UNAVAILABLE")));
add('DecisionOutcomeMismatchRows', ...
    sum(contains(outcomeReasons, "DECISION_OUTCOME_MISMATCH")));
```

- [ ] **Step 7: 테스트 통과 확인**

Run: `runtests({'tests/unit/test_decision_outcomes.m', 'tests/unit/test_export_final_document.m', 'tests/unit/test_export_test_specification.m', 'tests/unit/test_specification_decision_blocks.m'})`
Expected: 전부 PASS. `test_export_test_specification`이 이전과 같으면 명세서 출력이 바뀌지 않았다는 뜻이다.

- [ ] **Step 8: 커밋**

```bash
git add src/exporting/st_final_document_decision_outcomes.m src/exporting/st_format_specification_decision_blocks.m src/exporting/st_final_document_table.m src/exporting/st_export_final_document.m tests/unit/test_decision_outcomes.m tests/unit/test_export_final_document.m
git commit -m "feat(export): 최종 문서의 T/F 분기에 실제로 탄 결과를 적는다"
```
(본문: 표기 규칙, 사유 코드가 정보성인 이유, Metadata 키. 그리고 Co-Authored-By 줄.)

---

### Task 4: 문서

**Files:**
- Modify: `docs/reference/final-document.md` (`### Description` 절 끝, `## 7` 사유 표, `## 8` Metadata 표)
- Modify: `docs/reference/execution-commands.md:539`
- Modify: `docs/superpowers/specs/2026-10-06-decision-outcome-in-final-document-design.md` (4·5·7절을 구현에 맞춤)
- Modify: `CHANGELOG.md` (`## Unreleased` 맨 위)
- Modify: `docs/ai/codex-handoff.md` (`## 실물 미검증 목록` 끝)

- [ ] **Step 1: `final-document.md`**

`### Description` 절의 `` `'NONE'`을 주면 커버리지가 있어도 열을 비웁니다. `` 줄 다음에 새 소절을 넣는다:

```markdown
### 분기 결과 — `[T]`, `[F]`, `[T/F]`, `[-]`

모든 결정이 true/false 두 결과인 블록(If의 조건마다, Switch, For/While Iterator,
Enabled/Triggered/Resettable Subsystem 등)은 **그 행의 테스트가 실제로 탄 결과**를
적습니다.

| 표기 | 뜻 |
| --- | --- |
| `[T]` | true만 탔습니다 |
| `[F]` | false만 탔습니다 |
| `[T/F]` | 둘 다 탔습니다 |
| `[-]` | 그 행에서 한 번도 평가되지 않았습니다 |

값은 결과 정리 때 iteration마다 기록한 결과 워크북의 `DecisionOutcomes` 시트에서
옵니다. 판정과 같은 워크북·같은 실행(INITIAL/FINAL)을 읽습니다.

- Saturate, MinMax, MultiPortSwitch, SwitchCase, Sign처럼 결정이 둘 이상이거나 결과가
  셋 이상인 블록은 정적 표기 `[T/F]` 그대로입니다.
- 결과를 붙이지 못하면 `[T/F]`로 두고 `TestResults`의 `확인 사유`에 이유를 남깁니다.
  이 사유만으로 `확인 필요`가 `Y`가 되지는 않습니다.
- 이 기능 이전에 정리한 결과는 시트가 없어 모든 행이
  `DECISION_OUTCOME_UNAVAILABLE`입니다. 결과 정리를 다시 하면 채워집니다.
```

`## 7`의 사유 표에서 `MAXTIME_UNAVAILABLE` 행 다음에 세 행을 넣는다:

```markdown
| `DECISION_OUTCOME_UNAVAILABLE` | 이 행의 분기 결과가 기록되지 않아 `Description`에 `[T/F]`를 남겼습니다. 정보성이며 `확인 필요`를 켜지 않습니다 |
| `DECISION_OUTCOME_MISMATCH` | 블록의 D 줄 수와 기록된 결정 수가 달라 `[T/F]`를 남겼습니다. 정보성입니다 |
| `DECISION_OUTCOME_AMBIGUOUS` | 같은 행·블록에 서로 다른 결과가 기록돼 그 블록을 `[T/F]`로 두었습니다 |
```

`## 8` Metadata 표의 `| 설정 | \`DecisionBlockScope\` |` 행 위에 한 행을 넣는다:

```markdown
| 분기 결과 출처 | `DecisionOutcomeUnits`, `DecisionOutcomeUnavailableRows`, `DecisionOutcomeMismatchRows` |
```

- [ ] **Step 2: `execution-commands.md:539`**

`판정(\`Iterations\`, \`Targets\`)과 \`DecisionPoints\`만 씁니다.`를 다음으로 바꾼다:
`판정(\`Iterations\`, \`Targets\`)과 \`DecisionPoints\`, \`DecisionOutcomes\`만 씁니다.`

- [ ] **Step 3: 설계 문서를 구현에 맞춤**

- 4절 행 형식 표: `BlockPath` 행을 `RelativePath`(CUT 기준 상대 경로, 공백 정규화, CUT 자신은 `.`)로 바꾸고, `Kind`(`UNIT`/`DECISION`) 행을 더한다. UNIT 행이 "수집된 단위" 표시라는 문장을 더한다.
- 5절: "`Scope='VERDICT'`에서는 수집하지 않고" 문장을 "`Scope='VERDICT'`(LEAN)에서도 수집한다. LEAN은 최종 문서가 읽는 시트만 쓰는데 이 시트도 그중 하나다"로 바꾼다.
- 7절: Metadata 키를 `DecisionOutcomeUnits`, `DecisionOutcomeUnavailableRows`, `DecisionOutcomeMismatchRows`로 바꾼다.
- 머리의 `상태:`를 `구현됨 (실기 미확인)`으로 바꾼다.

- [ ] **Step 4: CHANGELOG**

`## Unreleased` 바로 아래 첫 항목으로:

```markdown
- **최종 문서의 `Description`에 분기의 실제 결과를 적습니다.** true/false 두 결과인
  분기는 그 행의 테스트가 탄 쪽에 따라 `[T]`, `[F]`, `[T/F]`(둘 다), `[-]`(평가 안
  됨)로 적습니다. 결과 정리(BATCH `st_generate_test_report`, PER_CUT
  `st_collect_per_cut_results`)가 결과 워크북에 `DecisionOutcomes` 시트를 새로
  씁니다. 그 밖의 분기와 결과를 구할 수 없는 행은 `[T/F]` 그대로이며,
  `TestResults`에 정보성 사유 `DECISION_OUTCOME_UNAVAILABLE` /
  `DECISION_OUTCOME_MISMATCH`가 남습니다.
  - **기존 결과에는 시트가 없습니다.** 이 버전 전에 정리한 결과로 최종 문서를 뽑으면
    모든 행이 `DECISION_OUTCOME_UNAVAILABLE`입니다. 결과 정리를 다시 하십시오.
  - 명세서 export 출력은 바뀌지 않습니다.
```

- [ ] **Step 5: 인수인계 실기 확인 항목**

`docs/ai/codex-handoff.md`의 `## 실물 미검증 목록` 마지막 항목 다음에:

```markdown
- 최종 문서 분기 결과(`DecisionOutcomes`): iteration 단위 `getCoverageResults`가
  결과를 담는지(비면 모든 행이 `DECISION_OUTCOME_UNAVAILABLE`, Metadata
  `DecisionOutcomeUnits=0`), Switch·If·Enable·Trigger·Reset의 outcome 텍스트가
  `true`/`false`인지(For Iterator만 사용자 캡처로 확인), If의
  `description.decision` 순서가 if→elseif인지, PER_CUT 결과 정리 시간이 얼마나
  늘었는지.
```

- [ ] **Step 6: 커밋**

```bash
git add docs/reference/final-document.md docs/reference/execution-commands.md docs/superpowers/specs/2026-10-06-decision-outcome-in-final-document-design.md CHANGELOG.md docs/ai/codex-handoff.md
git commit -m "docs: 최종 문서 분기 결과 표기와 DecisionOutcomes 시트를 설명한다"
```
(Co-Authored-By 줄.)
