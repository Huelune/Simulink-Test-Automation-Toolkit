# 결정 단위 분기(D) 나누기 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Saturation처럼 Coverage 결정이 여럿인 블록이 결정마다 D를 하나씩 받고, 최종 문서가 결정 텍스트로 실제 결과를 짝지어 적는다.

**Architecture:** catalog에 `Branches` 열을 더해 블록 종류마다 "Coverage 결정 텍스트:파라미터[:조건]"을 적는다. descriptor가 그 열로 분기마다 한 줄을 만들고, 세 번째 출력 `coverageTexts`로 결정 텍스트를 돌려준다. scan은 이것을 JSON의 `CoverageText` 필드로 넣는다. 최종 문서 리더는 기록된 `DecisionText`를 함께 돌려주고, 포맷터는 `CoverageText`가 있는 블록을 순서가 아니라 텍스트로 짝짓는다.

**Tech Stack:** MATLAB, Simulink(get_param 저장값), Simulink Coverage(decisioninfo 결정 텍스트), `matlab.unittest` 함수형 테스트(`functiontests(localfunctions)`).

**Spec:** `docs/superpowers/specs/2026-10-08-decision-branch-split-design.md` (앞선 설계: `docs/superpowers/specs/2026-10-06-decision-outcome-in-final-document-design.md`, 실기 결과 10.1절)

## Global Constraints

- `Branches` 값(행 순서 그대로, 공백 포함 정확히):
  - Saturate: `U >= LL:LowerLimit; U > UL:UpperLimit`
  - DeadZone: `U >= LL:LowerValue; U > UL:UpperValue`
  - RateLimiter: `X < LL:FallingSlewLimit; X > UL:RisingSlewLimit`
  - Relay: `U >= OnThresh:OnSwitchValue; U <= OffThresh:OffSwitchValue`
  - DiscreteIntegrator: `Reset:ExternalReset:ExternalReset!=none; X < LL:LowerSaturationLimit:LimitOutput=on; X > UL:UpperSaturationLimit:LimitOutput=on`
  - Delay, DiscreteFir: `Enable:ShowEnablePort:ShowEnablePort=on; Reset:ExternalReset:ExternalReset!=None`
  - DiscreteFilter, DiscreteTransferFcn: `Reset:ExternalReset:ExternalReset!=None`
  - 그 밖의 행: `""`
- 분기 한 줄의 식: `<Coverage 텍스트>; <파라미터>=<저장 값>` (예: `U >= LL; LowerLimit=-32`). 값은 평가하지 않는다.
- `Branches`가 있는 행은 `Parameters`와 `OptionalParameters`가 `""`다.
- `TwoWay=YES`인 종류(catalog 순서): `If, Switch, Saturate, Abs, DeadZone, RateLimiter, Relay, DiscreteIntegrator, ForIterator, WhileIterator, Delay, DiscreteFilter, DiscreteFir, DiscreteTransferFcn, EnablePort, TriggerPort, ResetPort`.
- JSON 항목에 `CoverageText` 필드를 더한다. `Branches`가 없는 블록과 WARN 행은 `""`다.
- 텍스트 짝짓기 비교는 공백 연속을 하나로 줄이고 앞뒤 공백을 지우고 대소문자를 무시한다. 각 D 줄이 기록된 결정과 정확히 하나씩 맞아야 하고, 기록된 결정 수와 D 줄 수가 같아야 한다. 아니면 그 블록의 D를 모두 `[T/F]`로 두고 `DECISION_OUTCOME_MISMATCH`를 남긴다.
- `CoverageText`가 없는 블록(If, Switch 등)은 지금처럼 순서로 짝짓는다.
- 결과가 셋 이상인 블록(MinMax, MultiPortSwitch, SwitchCase, Signum, CombinatorialLogic)은 바꾸지 않는다.
- descriptor의 기존 두 출력만 받는 호출자는 그대로 동작해야 한다.
- 모든 새 기능은 `st_log` 진단을 남긴다(`AGENTS.md`). 텍스트 불일치는 WARN.
- `.m`은 CRLF 줄끝. 커밋은 Conventional Commits, 한국어 제목, 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- 이 작업 디렉터리에서는 MATLAB을 실행할 수 없다. 테스트 실행 단계는 MATLAB이 있는 환경에서만 한다. 없으면 커밋 본문에 "MATLAB을 이 환경에서 실행할 수 없어 단위 테스트는 돌리지 못했다."를 적는다.

## Review Focus

1. **Coverage가 D와 다른 순서로 결정을 기록함**(실기: 하한이 먼저) → 텍스트로 맞는 D에 결과가 가야 한다. → Task 2 `testTextPairingFollowsTextNotOrder`.
2. **입력이 벡터라 같은 텍스트가 여러 번 기록됨** → 그 블록은 모두 `[T/F]`와 MISMATCH. → Task 2 `testRepeatedTextKeepsStaticMarkAndSaysMismatch`.
3. **export 뒤 설정이 바뀌어 기록된 결정이 D에 없는 것을 포함함**(Delay에 enable 결정이 추가됨) → MISMATCH. → Task 2 `testRecordedDecisionWithoutALineIsAMismatch`.
4. **분기 파라미터 읽기 실패** → 블록이 사라지지 않고 WARN 한 줄로 남는다. → Task 1 `testBranchParameterFailureKeepsTheBlockAsWarn`.
5. **결정 텍스트의 공백·대소문자 차이**(`u  >=  ll`) → 같은 결정으로 짝짓는다. → Task 2 `testTextPairingIgnoresSpacingAndCase`.

---

## File Structure

| 파일 | 책임 | Task |
| --- | --- | --- |
| `src/exporting/st_specification_decision_catalog.m` | `Branches` 열, `TwoWay` 9개 행 YES, 9개 행 `Parameters`/`OptionalParameters` 비움, 머리 주석 | 1 |
| `src/exporting/st_specification_decision_descriptor.m` | `Branches`로 분기 줄과 결정 텍스트 생성, 세 번째 출력 | 1 |
| `src/exporting/st_specification_decision_blocks.m` | 세 번째 출력을 받아 JSON `CoverageText` | 1 |
| `tests/unit/test_specification_decision_blocks.m` | catalog·descriptor·scan 테스트 갱신과 추가, 가짜 descriptor 3출력 | 1 |
| `src/exporting/st_final_document_decision_outcomes.m` | lookup이 `Texts`도 돌려줌 | 2 |
| `src/exporting/st_format_specification_decision_blocks.m` | `CoverageText` 묶음은 텍스트로 짝짓기 | 2 |
| `tests/unit/test_decision_outcomes.m` | 리더 텍스트, 텍스트 짝짓기 테스트 | 2 |
| 문서 5종 | 사용자 문서, 설계 보정, CHANGELOG, 인수인계 | 3 |

---

### Task 1: catalog `Branches`와 분기 줄 생성

**Files:**
- Modify: `src/exporting/st_specification_decision_catalog.m` (머리 주석의 열 설명, `Parameters`, `OptionalParameters`, `TwoWay` 배열, 새 `Branches` 배열, `catalog = table(...)`)
- Modify: `src/exporting/st_specification_decision_descriptor.m` (시그니처, `has_decision` 뒤 분기, 끝 부분, 새 로컬 함수 `branch_expressions`)
- Modify: `src/exporting/st_specification_decision_blocks.m` (`records` 열 수, descriptor 호출, `normalize_branches`, JSON 항목)
- Test: `tests/unit/test_specification_decision_blocks.m`

**Interfaces:**
- Produces: `[outcome, expression, coverageTexts] = st_specification_decision_descriptor(blockPath, blockType, parameterReader, catalogReader)`. `coverageTexts`는 `expression`과 같은 길이의 string column이고, `Branches`가 없는 블록이면 모두 `""`다. 결정이 없으면 셋 다 비어 있다(`expression`, `coverageTexts`는 `strings(0,1)`).
- Produces: scan JSON 항목 필드 순서 `BlockType, Name, Path, Outcome, Expression, CoverageText, ExpressionStatus, Message`.
- Produces: catalog 열 `Branches`(string).

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/unit/test_specification_decision_blocks.m`

기존 테스트 다섯 개의 기대값을 바꾼다.

`testImplicitBlocksUseGenericNameValueExpressions` 본문 전체:

```matlab
function testImplicitBlocksUseGenericNameValueExpressions(testCase)
% Saturate, Relay and RateLimiter receive one Decision per limit, so each
% limit is its own branch, named by the decision text coverage prints.
[outcome, expression, texts] = st_specification_decision_descriptor( ...
    'SaturatePath', 'Saturate', @fixture_implicit_parameter);
verifyEqual(testCase, outcome, "LIMIT");
verifyEqual(testCase, expression, ["U >= LL; LowerLimit=-1"; "U > UL; UpperLimit=1"]);
verifyEqual(testCase, texts, ["U >= LL"; "U > UL"]);

[outcome, expression] = st_specification_decision_descriptor( ...
    'RelayPath', 'Relay', @fixture_implicit_parameter);
verifyEqual(testCase, outcome, "ON/OFF");
verifyEqual(testCase, expression, ...
    ["U >= OnThresh; OnSwitchValue=1"; "U <= OffThresh; OffSwitchValue=0"]);

[outcome, expression] = st_specification_decision_descriptor( ...
    'RateLimiterPath', 'RateLimiter', @fixture_implicit_parameter);
verifyEqual(testCase, outcome, "RATE");
verifyEqual(testCase, expression, ...
    ["X < LL; FallingSlewLimit=-1"; "X > UL; RisingSlewLimit=1"]);
end
```

`testResetBlocksAreListedOnlyWithResetOrEnable`에서 두 기대값:

```matlab
verifyEqual(testCase, expression, "Enable; ShowEnablePort=on");
```
(`DelayEnablePath`, 기존 `"ExternalReset=None; ShowEnablePort=on"` 자리)

```matlab
verifyEqual(testCase, expression, "Reset; ExternalReset=Rising");
```
(`FilterResetPath`, 기존 `"ExternalReset=Rising"` 자리)

`testIntegratorWithLimitOrResetIsListed` 본문 전체:

```matlab
function testIntegratorWithLimitOrResetIsListed(testCase)
[outcome, expression] = st_specification_decision_descriptor( ...
    'IntegratorLimitPath', 'DiscreteIntegrator', @fixture_implicit_parameter);
verifyEqual(testCase, outcome, "LIMIT");
verifyEqual(testCase, expression, ...
    ["X < LL; LowerSaturationLimit=-1"; "X > UL; UpperSaturationLimit=1"]);

[outcome, expression] = st_specification_decision_descriptor( ...
    'IntegratorResetPath', 'DiscreteIntegrator', @fixture_implicit_parameter);
verifyEqual(testCase, outcome, "LIMIT");
verifyEqual(testCase, expression, "Reset; ExternalReset=rising");
end
```

`testCatalogMarksExactlyTheTrueFalseTypesAsTwoWay`의 기대 목록:

```matlab
verifyEqual(testCase, string(catalog.BlockType(string(catalog.TwoWay) == "YES")), ...
    ["If"; "Switch"; "Saturate"; "Abs"; "DeadZone"; "RateLimiter"; "Relay"; ...
     "DiscreteIntegrator"; "ForIterator"; "WhileIterator"; "Delay"; ...
     "DiscreteFilter"; "DiscreteFir"; "DiscreteTransferFcn"; ...
     "EnablePort"; "TriggerPort"; "ResetPort"]);
```

`testCatalogIsWellFormedAndUnique`의 GENERIC 검사(`hasSource = ...` 두 줄)를 다음으로 바꾼다:

```matlab
    if catalog.Formatter(k) == "GENERIC"
        hasSource = ~isempty(required) || ...
            strlength(strtrim(string(catalog.FixedText(k)))) > 0 || ...
            strlength(strtrim(string(catalog.Branches(k)))) > 0;
        verifyTrue(testCase, hasSource, label);
    end
```

가짜 descriptor 네 개에 세 번째 출력을 더한다. 첫 줄만 바뀐다:

```matlab
function [outcome, expression, coverageTexts] = fixture_descriptor(path, blockType)
coverageTexts = strings(0,1);
```
```matlab
function [outcome, expression, coverageTexts] = failing_descriptor(~, ~) %#ok<STOUT>
```
```matlab
function [outcome, expression, coverageTexts] = branching_descriptor(~, ~)
coverageTexts = strings(0,1);
```
```matlab
function [outcome, expression, coverageTexts] = mismatched_descriptor(~, ~)
coverageTexts = strings(0,1);
```

새 테스트를 더한다(`testIntegratorWithLimitOrResetIsListed` 다음):

```matlab
function testCatalogBranchesAreWellFormed(testCase)
% Each entry is "<coverage text>:<parameter>[:<condition>]". A row with
% branches names its parameters there, never in Parameters as well.
catalog = st_specification_decision_catalog('ALL');
for k = 1:height(catalog)
    spec = strtrim(string(catalog.Branches(k)));
    label = char(catalog.BlockType(k));
    if strlength(spec) == 0, continue; end
    verifyEqual(testCase, string(catalog.Parameters(k)), "", label);
    verifyEqual(testCase, string(catalog.OptionalParameters(k)), "", label);
    verifyEqual(testCase, string(catalog.TwoWay(k)), "YES", label);
    for entry = strtrim(split(spec, ';')).'
        fields = strtrim(split(entry, ':'));
        verifyTrue(testCase, numel(fields) == 2 || numel(fields) == 3, label);
        verifyTrue(testCase, all(strlength(fields(1:2)) > 0), label);
        if numel(fields) == 3
            verifyNotEmpty(testCase, regexp(char(fields(3)), '^\w+\s*!?=\s*\S', 'once'), label);
        end
    end
end
end

function testIntegratorWithEverySettingHasThreeBranchesInCoverageOrder(testCase)
% Coverage reports the reset, then the lower limit, then the upper limit.
[~, expression, texts] = st_specification_decision_descriptor( ...
    'IntegratorAllPath', 'DiscreteIntegrator', @fixture_implicit_parameter);
verifyEqual(testCase, expression, ["Reset; ExternalReset=rising"; ...
    "X < LL; LowerSaturationLimit=-5"; "X > UL; UpperSaturationLimit=5"]);
verifyEqual(testCase, texts, ["Reset"; "X < LL"; "X > UL"]);
end

function testDelayWithEnableAndResetHasTwoBranches(testCase)
[~, expression, texts] = st_specification_decision_descriptor( ...
    'DelayBothPath', 'Delay', @fixture_implicit_parameter);
verifyEqual(testCase, expression, ["Enable; ShowEnablePort=on"; "Reset; ExternalReset=Rising"]);
verifyEqual(testCase, texts, ["Enable"; "Reset"]);
end

function testDeadZoneSplitsIntoStartAndEnd(testCase)
[outcome, expression] = st_specification_decision_descriptor( ...
    'DeadZonePath', 'DeadZone', @fixture_implicit_parameter);
verifyEqual(testCase, outcome, "BAND");
verifyEqual(testCase, expression, ["U >= LL; LowerValue=-10"; "U > UL; UpperValue=10"]);
end

function testBlockWithoutBranchesHasEmptyCoverageTexts(testCase)
[~, expression, texts] = st_specification_decision_descriptor( ...
    'SwitchPath', 'Switch', @fixture_parameter);
verifyEqual(testCase, expression, "u2 >= 5");
verifyEqual(testCase, texts, "");
end

function testScanCarriesCoverageTextIntoTheJson(testCase)
cfg = struct('VerboseLogging', false);
descriptor = @(path, blockType) st_specification_decision_descriptor( ...
    path, blockType, @fixture_implicit_parameter);
[text, count, ~] = st_specification_decision_blocks( ...
    'Top/CUT', cfg, @single_saturate_finder, @(~) "Sat", descriptor);
decoded = jsondecode(char(text));
verifyEqual(testCase, count, 2);
verifyEqual(testCase, string({decoded.CoverageText}).', ["U >= LL"; "U > UL"]);
verifyEqual(testCase, string({decoded.Expression}).', ...
    ["U >= LL; LowerLimit=-1"; "U > UL; UpperLimit=1"]);
end

function testBranchParameterFailureKeepsTheBlockAsWarn(testCase)
cfg = struct('VerboseLogging', false);
descriptor = @(path, blockType) st_specification_decision_descriptor( ...
    path, blockType, @refusing_parameter);
[text, count, note] = st_specification_decision_blocks( ...
    'Top/CUT', cfg, @single_saturate_finder, @(~) "Sat", descriptor);
decoded = jsondecode(char(text));
verifyEqual(testCase, count, 1);
verifyEqual(testCase, string(decoded.ExpressionStatus), "WARN");
verifyEqual(testCase, string(decoded.Expression), "조건식 읽기 실패");
verifyEqual(testCase, string(decoded.CoverageText), "");
verifyNotEmpty(testCase, note);
end

function paths = single_saturate_finder(~, varargin)
[depth, blockType] = search_options(varargin);
if depth ~= 1
    error('fixture:SearchDepth', 'Expected SearchDepth=1.');
end
if strcmp(blockType, 'Saturate')
    paths = "SaturatePath";
else
    paths = strings(0,1);
end
end
```

`fixture_implicit_parameter`의 `switch key`에 다음 case를 더한다(`otherwise` 앞):

```matlab
    case "IntegratorAllPath|LimitOutput"
        value = 'on';
    case "IntegratorAllPath|ExternalReset"
        value = 'rising';
    case "IntegratorAllPath|UpperSaturationLimit"
        value = '5';
    case "IntegratorAllPath|LowerSaturationLimit"
        value = '-5';
    case "DelayBothPath|ExternalReset"
        value = 'Rising';
    case "DelayBothPath|ShowEnablePort"
        value = 'on';
    case "DeadZonePath|LowerValue"
        value = '-10';
    case "DeadZonePath|UpperValue"
        value = '10';
```

`single_saturate_finder`가 쓰는 `search_options`는 이 파일에 이미 있는 로컬 함수다(`single_integrator_finder`가 쓴다).

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run (MATLAB, 저장소 루트, `st_setup` 뒤): `runtests('tests/unit/test_specification_decision_blocks.m')`
Expected: 바꾼 다섯 테스트와 새 테스트가 FAIL(`Branches` 열 없음, 출력 인자 수, 기대값 불일치).

- [ ] **Step 3: catalog 변경** — `src/exporting/st_specification_decision_catalog.m`

머리 주석의 `TwoWay` 설명을 다음으로 바꾸고, 그 바로 아래에 `Branches` 설명을 더한다:

```matlab
% TwoWay             YES when every Decision the block receives has exactly
%                    the outcomes true and false and each one has its own D
%                    line, so the final document can print what a row's test
%                    took ([T], [F], [T/F], [-]). NO keeps the static [T/F]
%                    with no reason: the outcomes are not true/false (MinMax,
%                    Sign, ...).
% Branches           One D line per Simulink Coverage decision, for a block
%                    that receives several. ';' separates the entries, each
%                    "<coverage text>:<parameter>[:<condition>]". The coverage
%                    text is the decision text decisioninfo prints, so the D
%                    line reads like the coverage report and the final
%                    document pairs it with the recorded outcome by text: the
%                    report lists a lower limit before the upper limit, the
%                    reverse of the documentation. The condition uses the
%                    DecisionWhen syntax; an entry whose condition fails is
%                    not listed. A row with branches leaves Parameters and
%                    OptionalParameters empty.
```

`Parameters` 배열에서 Saturate, DeadZone, RateLimiter, Relay, DiscreteIntegrator, Delay, DiscreteFilter, DiscreteFir, DiscreteTransferFcn 행을 `""`로 바꾼다. 결과:

```matlab
Parameters = [ ...
    ""; ""; ""; ""; ""; ...
    ""; ...
    ""; ...
    ""; ...
    ""; ...
    ""; ...
    ""; ...
    "IterationSource"; ...
    "WhileBlockType"; ...
    ""; ...
    "TruthTable"; ...
    ""; ...
    ""; ...
    ""; ...
    ""; ...
    ""; ""; ""
];
```

`OptionalParameters`에서 DiscreteIntegrator 행을 `""`로 바꾼다:

```matlab
OptionalParameters = [ ...
    ""; ""; ""; ""; ""; ...
    ""; ...
    ""; ...
    ""; ""; ""; ...
    ""; ...
    "IterationLimit"; ...
    "MaxIters"; ...
    ""; ""; ""; ""; ""; ""; ...
    ""; ""; ""
];
```

`TwoWay` 배열:

```matlab
TwoWay = [ ...
    "YES"; "YES"; "NO"; "NO"; "NO"; ...
    "YES"; "YES"; "YES"; "YES"; "YES"; ...
    "YES"; ...
    "YES"; "YES"; ...
    "NO"; ...
    "NO"; ...
    "YES"; ...
    "YES"; ...
    "YES"; ...
    "YES"; ...
    "YES"; "YES"; "YES"
];
```

`TwoWay` 배열 다음에 `Branches` 배열을 더한다:

```matlab
Branches = [ ...
    ""; ""; ""; ""; ""; ...
    "U >= LL:LowerLimit; U > UL:UpperLimit"; ...
    ""; ...
    "U >= LL:LowerValue; U > UL:UpperValue"; ...
    "X < LL:FallingSlewLimit; X > UL:RisingSlewLimit"; ...
    "U >= OnThresh:OnSwitchValue; U <= OffThresh:OffSwitchValue"; ...
    "Reset:ExternalReset:ExternalReset!=none; X < LL:LowerSaturationLimit:LimitOutput=on; X > UL:UpperSaturationLimit:LimitOutput=on"; ...
    ""; ""; ...
    ""; ...
    ""; ...
    "Enable:ShowEnablePort:ShowEnablePort=on; Reset:ExternalReset:ExternalReset!=None"; ...
    "Reset:ExternalReset:ExternalReset!=None"; ...
    "Enable:ShowEnablePort:ShowEnablePort=on; Reset:ExternalReset:ExternalReset!=None"; ...
    "Reset:ExternalReset:ExternalReset!=None"; ...
    ""; ""; ""
];
```

`catalog = table(...)`에 `Branches`를 마지막 열로 더한다:

```matlab
catalog = table(BlockType, Outcome, DisplayType, Formatter, ...
    Parameters, OptionalParameters, FixedText, Kind, MainExpression, ...
    DecisionWhen, TwoWay, Branches);
```

- [ ] **Step 4: descriptor 변경** — `src/exporting/st_specification_decision_descriptor.m`

시그니처와 머리 주석:

```matlab
function [outcome, expression, coverageTexts] = st_specification_decision_descriptor( ...
        blockPath, blockType, parameterReader, catalogReader)
```
머리 주석 끝(`% then leaves the block out of the list.` 다음)에:

```matlab
% COVERAGETEXTS holds, per branch, the decision text Simulink Coverage
% prints for it when the catalog lists Branches for the type, and "" for
% every other type. The final document pairs a branch with its recorded
% outcome by this text.
```

`has_decision` 검사 블록을 다음으로 바꾼다:

```matlab
outcome = string(catalog.Outcome(index));
coverageTexts = strings(0,1);
if ~has_decision(parameterReader, blockPath, catalog.DecisionWhen(index))
    expression = strings(0,1);
    return;
end

branches = "";
if ismember('Branches', catalog.Properties.VariableNames)
    branches = strtrim(string(catalog.Branches(index)));
end
if strlength(branches) > 0
    % One line per branch. When no branch survives its condition the result
    % is empty: the saved settings give the block no Decision objective, the
    % same as a failed DecisionWhen, and the scan leaves it out.
    [expression, coverageTexts] = branch_expressions( ...
        parameterReader, blockPath, branches);
    return;
end
```

함수 끝의 빈 식 검사 다음(마지막 `end` 앞)에:

```matlab
coverageTexts = repmat("", numel(expression), 1);
```

`has_decision` 함수 앞에 로컬 함수를 더한다:

```matlab
function [expression, coverageTexts] = branch_expressions(reader, blockPath, spec)
% One line per Simulink Coverage decision, in the order coverage reports
% them. Each line starts with the decision text coverage prints, followed
% by the saved parameter that decision compares against. A parameter read
% failure propagates so the scan keeps the block as a WARN row.
expression = strings(0,1);
coverageTexts = strings(0,1);
for entry = strtrim(split(string(spec), ';')).'
    if strlength(entry) == 0, continue; end
    fields = strtrim(split(entry, ':'));
    if numel(fields) < 2 || numel(fields) > 3 || any(strlength(fields(1:2)) == 0)
        error('simtest:SpecificationDecisionBranch', ...
            'Malformed Branches entry: %s', entry);
    end
    if numel(fields) == 3 && ~has_decision(reader, blockPath, fields(3))
        continue;
    end
    value = parameter_text(reader, blockPath, char(fields(2)));
    expression(end+1,1) = fields(1) + "; " + fields(2) + "=" + value; %#ok<AGROW>
    coverageTexts(end+1,1) = fields(1); %#ok<AGROW>
end
end
```

- [ ] **Step 5: scan 변경** — `src/exporting/st_specification_decision_blocks.m`

`records`와 `typeRecords`를 9열로 바꾸고 주석을 고친다:

```matlab
% BlockType, Name, Path, Outcome, Expression, Status, Message, BranchOrder,
% CoverageText. BranchOrder is a sort key only; it is not written to the JSON.
records = strings(0,9);
```
```matlab
        typeRecords = strings(0,9);
```

descriptor 호출과 정규화:

```matlab
                [outcome, expression, coverageTexts] = ...
                    descriptorReader(char(paths(n)), char(blockType));
```
```matlab
                [outcome, expression, coverageTexts] = normalize_branches( ...
                    outcome, expression, coverageTexts, blockType, paths(n));
```

`catch ME` 경로의 기본값에 한 줄을 더한다(`expression = "조건식 읽기 실패";` 다음):

```matlab
                coverageTexts = "";
```

`typeRecords` 추가 부분:

```matlab
            typeRecords = [typeRecords; ...
                repmat(blockType, branches, 1) repmat(name, branches, 1) ...
                repmat(paths(n), branches, 1) outcome expression ...
                status message branchOrder coverageTexts]; %#ok<AGROW>
```

JSON 항목:

```matlab
        item = struct('BlockType', char(records(k,1)), ...
            'Name', char(records(k,2)), 'Path', char(records(k,3)), ...
            'Outcome', char(records(k,4)), ...
            'Expression', char(records(k,5)), ...
            'CoverageText', char(records(k,9)), ...
            'ExpressionStatus', char(records(k,6)), ...
            'Message', char(records(k,7)));
```

`normalize_branches`:

```matlab
function [outcome, expression, coverageTexts] = normalize_branches( ...
        outcome, expression, coverageTexts, blockType, path)
% A descriptor may return one expression per branch. The outcome is the kind
% of branch, so a scalar outcome applies to every branch of the block. A
% descriptor without coverage texts gets "" for every branch.
outcome = string(outcome);
outcome = outcome(:);
expression = string(expression);
expression = expression(:);
coverageTexts = string(coverageTexts);
coverageTexts = coverageTexts(:);
if isempty(expression)
    error('simtest:SpecificationDecisionExpression', ...
        'Decision expression is empty: %s', path);
end
if isscalar(outcome) && numel(expression) > 1
    outcome = repmat(outcome, numel(expression), 1);
end
if numel(outcome) ~= numel(expression)
    error('simtest:SpecificationDecisionBranch', ...
        'Decision branch count mismatch for %s (%s): %d outcome(s), %d expression(s).', ...
        path, blockType, numel(outcome), numel(expression));
end
if isempty(coverageTexts)
    coverageTexts = repmat("", numel(expression), 1);
end
if numel(coverageTexts) ~= numel(expression)
    error('simtest:SpecificationDecisionBranch', ...
        'Decision branch count mismatch for %s (%s): %d coverage text(s), %d expression(s).', ...
        path, blockType, numel(coverageTexts), numel(expression));
end
end
```

- [ ] **Step 6: 테스트 통과 확인**

Run: `runtests({'tests/unit/test_specification_decision_blocks.m', 'tests/unit/test_export_test_specification.m', 'tests/unit/test_decision_outcomes.m'})`
Expected: 전부 PASS. `test_export_test_specification`과 `test_decision_outcomes`는 JSON을 직접 만들어 쓰므로 영향이 없어야 한다.

정적 확인(MATLAB 없이):
```bash
grep -n "strings(0,8)\|\[outcome, expression\] = normalize_branches" src/exporting/st_specification_decision_blocks.m
```
Expected: 출력 없음.

- [ ] **Step 7: 커밋**

```bash
git add src/exporting/st_specification_decision_catalog.m src/exporting/st_specification_decision_descriptor.m src/exporting/st_specification_decision_blocks.m tests/unit/test_specification_decision_blocks.m
git commit -m "feat(export): 결정이 여럿인 블록의 D를 Coverage 결정 단위로 나눈다"
```
(본문: 대상 9종, Branches 문법, 결정 텍스트를 D 줄에 쓰는 이유, JSON CoverageText. MATLAB 미실행 문장, Co-Authored-By 줄.)

---

### Task 2: 결정 텍스트로 짝짓기

**Files:**
- Modify: `src/exporting/st_final_document_decision_outcomes.m` (텍스트 저장, `workbook_entries`, `lookup`, 머리 주석)
- Modify: `src/exporting/st_format_specification_decision_blocks.m` (`outcome_labels`, 새 로컬 함수 `pair_by_text`, `squash_text`)
- Test: `tests/unit/test_decision_outcomes.m`

**Interfaces:**
- Consumes: JSON 항목 `CoverageText` 필드(Task 1). 시트의 `DecisionText` 열(이미 있음).
- Produces: `Lookup(...)` 결과 struct에 `Texts`(N×1 string, `Counts`와 같은 순서, 공백 정규화)를 더한다. 기존 필드 `UnitFound`, `Counts`는 그대로.

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/unit/test_decision_outcomes.m`

`outcome_workbook` 헬퍼에 선택 인자 `texts`를 더한다. 시그니처와 `DecisionText` 열만 바뀐다:

```matlab
function file = outcome_workbook(testCase, runs, kinds, paths, indices, trues, falses, iterations, texts)
if nargin < 8 || isempty(iterations)
    iterations = repmat("Iteration 1", 1, numel(runs));
end
if nargin < 9
    texts = repmat("", 1, numel(runs));
end
```
`writetable(table(...))` 안의 `repmat("", count, 1)`(DecisionText 자리)를 `texts(:)`로 바꾼다. 다른 호출은 8개 이하 인자이므로 그대로 동작한다.

새 테스트와 헬퍼:

```matlab
function testLookupReturnsRecordedDecisionTexts(testCase)
file = outcome_workbook(testCase, ["FINAL","FINAL","FINAL"], ...
    ["UNIT","DECISION","DECISION"], ["","Sat","Sat"], [0 1 2], [0 3 0], [0 0 4], ...
    [], ["","U >= LL","U  > UL"]);
outcomes = st_final_document_decision_outcomes(base_config(), source_with(file, "ANY"));
found = outcomes.Lookup("Case1", "Iteration 1", "Sat");
verifyEqual(testCase, found.Counts, [3 0; 0 4]);
verifyEqual(testCase, found.Texts, ["U >= LL"; "U > UL"]);
end

function testTextPairingFollowsTextNotOrder(testCase)
% Coverage lists the lower limit first. Recorded in the opposite order of
% the D lines, each result must still land on its own line.
lookup = fake_text_lookup("Sat", [0 5; 7 0], ["U > UL"; "U >= LL"]);
formatted = st_format_specification_decision_blocks( ...
    one_row_specification(saturate_items()), base_config(), lookup);
verifyEqual(testCase, split(formatted.DecisionBlocks(1), newline), ...
    ["Sat"; "D1 [T]Saturate (U >= LL; LowerLimit=-32)"; ...
     "D2 [F]Saturate (U > UL; UpperLimit=32)"]);
end

function testTextPairingIgnoresSpacingAndCase(testCase)
lookup = fake_text_lookup("Sat", [1 1; 0 0], ["u  >=  ll"; "U > UL"]);
formatted = st_format_specification_decision_blocks( ...
    one_row_specification(saturate_items()), base_config(), lookup);
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D1 [T/F]Saturate (U >= LL"));
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D2 [-]Saturate (U > UL"));
end

function testRepeatedTextKeepsStaticMarkAndSaysMismatch(testCase)
% A vector input gives each element its own decision with the same text.
lookup = fake_text_lookup("Sat", [1 0; 1 0; 0 1; 0 1], ...
    ["U >= LL"; "U >= LL"; "U > UL"; "U > UL"]);
[formatted, ~, reasons] = st_format_specification_decision_blocks( ...
    one_row_specification(saturate_items()), base_config(), lookup);
verifyEqual(testCase, count(formatted.DecisionBlocks(1), "[T/F]"), 2);
verifyEqual(testCase, reasons(1), "DECISION_OUTCOME_MISMATCH");
end

function testRecordedDecisionWithoutALineIsAMismatch(testCase)
% The D list has only the reset branch, but the run recorded an enable
% decision too (the setting changed after the export).
item = struct('BlockType', 'Delay', 'Name', 'Dly', 'Path', 'TOP/CUT/Dly', ...
    'Outcome', 'RESET', 'Expression', 'Reset; ExternalReset=Rising', ...
    'CoverageText', 'Reset', 'ExpressionStatus', 'OK', 'Message', '');
lookup = fake_text_lookup("Dly", [1 1; 2 3], ["Enable"; "Reset"]);
[formatted, ~, reasons] = st_format_specification_decision_blocks( ...
    one_row_specification(item), base_config(), lookup);
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D1 [T/F]Delay"));
verifyEqual(testCase, reasons(1), "DECISION_OUTCOME_MISMATCH");
end

function testLinesWithoutCoverageTextStillPairByPosition(testCase)
% If has no coverage text on its lines; its order was confirmed at runtime.
items = [if_item("TOP/CUT/If1", "a > 0"); if_item("TOP/CUT/If1", "elseif b > 0")];
lookup = fake_lookup(struct('If1', [1 0; 0 1]));
formatted = st_format_specification_decision_blocks( ...
    one_row_specification(items), base_config(), lookup);
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D1 [T]IF (a > 0)"));
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D2 [F]IF (elseif b > 0)"));
end

function items = saturate_items()
items = [ ...
    struct('BlockType', 'Saturate', 'Name', 'Sat', 'Path', 'TOP/CUT/Sat', ...
        'Outcome', 'LIMIT', 'Expression', 'U >= LL; LowerLimit=-32', ...
        'CoverageText', 'U >= LL', 'ExpressionStatus', 'OK', 'Message', ''); ...
    struct('BlockType', 'Saturate', 'Name', 'Sat', 'Path', 'TOP/CUT/Sat', ...
        'Outcome', 'LIMIT', 'Expression', 'U > UL; UpperLimit=32', ...
        'CoverageText', 'U > UL', 'ExpressionStatus', 'OK', 'Message', '')];
end

function lookup = fake_text_lookup(relative, counts, texts)
% One scanned unit with one recorded block; any other path has no counts.
lookup = @(~, ~, asked) text_lookup_result(string(asked) == string(relative), counts, texts);
end

function result = text_lookup_result(matches, counts, texts)
result = struct('UnitFound', true, 'Counts', zeros(0,2), 'Texts', strings(0,1));
if matches
    result.Counts = counts;
    result.Texts = texts;
end
end
```

`one_row_specification`, `if_item`, `fake_lookup`, `base_config`, `source_with`는 이 파일에 이미 있는 헬퍼다. 이 파일의 다른 로컬 함수 이름과 겹치지 않는지 확인한다.

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `runtests('tests/unit/test_decision_outcomes.m')`
Expected: 새 테스트가 FAIL. `Texts` 필드가 없고, 텍스트 짝짓기가 없어 Saturate가 순서 짝짓기 또는 MISMATCH를 탄다.

- [ ] **Step 3: 리더 변경** — `src/exporting/st_final_document_decision_outcomes.m`

머리 주석의 `Counts` 설명 다음에:

```matlab
% Texts holds the recorded decision text for each row of Counts, with
% whitespace runs collapsed, so a D line that names its coverage decision
% can be paired by text rather than by position.
```

`decisions` Map 선언 다음에:

```matlab
texts = containers.Map('KeyType', 'char', 'ValueType', 'any');
```

`for r = 1:numel(entries.Unit)` 루프 안, `decisions(key) = current;` 다음에:

```matlab
        recorded = strings(0,1);
        if isKey(texts, key), recorded = texts(key); end
        recorded(end+1:index, 1) = "";
        recorded(index) = entries.Text(r);
        texts(key) = recorded;
```

충돌 키 제거(`remove(decisions, char(key));`)와 불완전 키 제거 바로 다음에 각각:

```matlab
    remove(texts, char(key));
```
```matlab
        remove(texts, char(key));
```

lookup 핸들과 함수:

```matlab
outcomes.Lookup = @(testCaseName, iterationName, relativePath) ...
    lookup(units, decisions, texts, testCaseName, iterationName, relativePath);
```
```matlab
function result = lookup(units, decisions, texts, testCaseName, iterationName, relativePath)
if ~st_is_real_iteration_name(iterationName)
    iterationName = "";
end
unit = unit_key(testCaseName, iterationName);
result = struct('UnitFound', isKey(units, char(unit)), 'Counts', zeros(0,2), ...
    'Texts', strings(0,1));
key = char(unit + "|" + squash(relativePath));
if isKey(decisions, key)
    result.Counts = decisions(key);
    result.Texts = texts(key);
end
end
```

`workbook_entries`에 `Text` 필드를 더한다:

```matlab
entries = struct('Unit', strings(count,1), 'IsUnit', false(count,1), ...
    'Key', strings(count,1), 'Index', zeros(count,1), 'Value', zeros(count,2), ...
    'Text', strings(count,1));
hasText = ismember("DecisionText", string(rows.Properties.VariableNames));
```
루프 안, `entries.Value(r,:) = ...` 다음에:

```matlab
    if hasText
        entries.Text(r) = squash(rows.DecisionText(r));
    end
```

- [ ] **Step 4: 포맷터 변경** — `src/exporting/st_format_specification_decision_blocks.m` `outcome_labels`

`types(k) = ...` 다음 줄에 결정 텍스트를 모은다. 선언도 함께:

```matlab
covered = strings(numel(decoded), 1);
```
(`types = strings(...)` 다음)
```matlab
    covered(k) = json_optional_text(decoded(k), 'CoverageText');
```
(루프 안 `types(k) = ...` 다음)

`if size(found.Counts, 1) ~= numel(items)` 블록 바로 앞에 텍스트 짝짓기를 넣는다:

```matlab
    if all(strlength(covered(items)) > 0)
        [picked, paired] = pair_by_text(covered(items), found);
        if ~paired
            mismatch = true;
            log_message(cfg, 'WARN', ...
                'Decision outcome text mismatch | Case=%s | Path=%s | Lines=%s | Recorded=%s', ...
                testCaseName, path, join_texts(covered(items)), ...
                join_texts(recorded_texts(found)));
            continue;
        end
        for j = 1:numel(items)
            labels(items(j)) = outcome_label(found.Counts(picked(j),:));
        end
        continue;
    end
```

머리 주석 첫 문단을 다음으로 바꾼다:

```matlab
% A block's D lines are paired with its recorded decisions by the decision
% text when every line names one (CoverageText), and by position otherwise
% (If, Switch, ...). Coverage lists a lower limit before the upper limit, so
% position alone would swap them. A block that cannot be paired one to one
% keeps [T/F]: pairing anyway would put one branch's result on another.
```

`outcome_label` 함수 앞에 로컬 함수 넷을 더한다:

```matlab
function [picked, paired] = pair_by_text(lines, found)
% Each D line must match exactly one recorded decision, and every recorded
% decision must belong to a line. Anything else - a vector input repeating
% a text, or a setting changed between the export and the run - leaves the
% block unpaired.
picked = zeros(numel(lines), 1);
paired = false;
recorded = recorded_texts(found);
if numel(recorded) ~= size(found.Counts, 1) || numel(recorded) ~= numel(lines)
    return;
end
recorded = squash_text(recorded);
for j = 1:numel(lines)
    match = find(recorded == squash_text(lines(j)));
    if ~isscalar(match)
        return;
    end
    picked(j) = match;
end
paired = numel(unique(picked)) == numel(picked);
end


function texts = recorded_texts(found)
texts = strings(0,1);
if isfield(found, 'Texts')
    texts = string(found.Texts);
    texts = texts(:);
end
end


function text = squash_text(text)
text = lower(strtrim(regexprep(string(text), '\s+', ' ')));
end


function text = join_texts(texts)
% For the log line only; never fails on an empty or column array.
text = "";
texts = string(texts);
if ~isempty(texts)
    text = strjoin(reshape(texts, 1, []), ', ');
end
end
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `runtests({'tests/unit/test_decision_outcomes.m', 'tests/unit/test_export_final_document.m', 'tests/unit/test_export_test_specification.m'})`
Expected: 전부 PASS. 기존 If/Switch/Enable 테스트는 `CoverageText`가 없어 순서 짝짓기를 그대로 탄다.

- [ ] **Step 6: 커밋**

```bash
git add src/exporting/st_final_document_decision_outcomes.m src/exporting/st_format_specification_decision_blocks.m tests/unit/test_decision_outcomes.m
git commit -m "feat(export): 결정 텍스트로 분기 결과를 짝짓는다"
```
(본문: 순서 대신 텍스트인 이유(실기에서 하한 먼저), 짝짓기 실패 규칙, 리더 Texts. MATLAB 미실행 문장, Co-Authored-By 줄.)

---

### Task 3: 문서

**Files:**
- Modify: `docs/reference/test-specification.md` (`### D번호는 블록이 아니라 분기 단위` 절 끝, `### 괄호 안 내용` 표와 그 아래 문단)
- Modify: `docs/reference/final-document.md` (`### 분기 결과` 절의 블록 목록과 사유 문단)
- Modify: `docs/superpowers/specs/2026-10-08-decision-branch-split-design.md` (상태, 6절)
- Modify: `CHANGELOG.md` (`## Unreleased` 맨 위)
- Modify: `docs/ai/codex-handoff.md` (`## 실물 미검증 목록`의 최종 문서 분기 결과 항목 다음)

- [ ] **Step 1: `test-specification.md`**

`### D번호는 블록이 아니라 분기 단위` 절의 마지막 문단(암묵적 else) 다음에:

```markdown
**Coverage 결정이 여럿인 블록도 결정마다 D를 하나씩 씁니다.** Saturate, DeadZone,
RateLimiter, Relay, DiscreteIntegrator, Delay, DiscreteFir, DiscreteFilter,
DiscreteTransferFcn이 여기 해당합니다. D 줄에는 Simulink Coverage가 그 결정에 붙이는
이름(`U >= LL`, `U > UL`, `Reset`, `Enable` 등)과 비교 대상 파라미터 하나를 적습니다.

```text
Sat 1
D1 [T/F]Saturate (U >= LL; LowerLimit=-32)
D2 [T/F]Saturate (U > UL; UpperLimit=32)
```

순서는 Coverage 리포트와 같아 하한이 먼저입니다. 결정 이름의 true 방향은 리포트와
같습니다. 예를 들어 Saturate의 하한은 `U >= LL`이 true(포화하지 않음)입니다.
DiscreteIntegrator의 reset 분기는 `ExternalReset`이 `none`이 아닐 때만, 한계 분기는
`LimitOutput=on`일 때만 생깁니다. Delay와 DiscreteFir의 enable 분기는
`ShowEnablePort=on`일 때만 생깁니다.
```

`### 괄호 안 내용` 표에서 `Saturate`, `Relay`, `DiscreteIntegrator`, `Delay, DiscreteFir`, `DiscreteFilter, DiscreteTransferFcn` 다섯 행을 지우고, 그 자리에 한 행을 넣는다:

```markdown
| `Saturate`, `DeadZone`, `RateLimiter`, `Relay`, `DiscreteIntegrator`, `Delay`, `DiscreteFir`, `DiscreteFilter`, `DiscreteTransferFcn` | 분기마다 Coverage 결정 이름과 파라미터 하나 (`U >= LL; LowerLimit=-32`) |
```

표 아래 문단 `암시적 분기 블록은 catalog가 지정한 파라미터를 ...`의 첫 문장을 다음으로 바꾼다:

```markdown
위 표에서 결정 단위로 나누지 않는 암시적 분기 블록은 catalog가 지정한 파라미터를
`이름=값; 이름=값` 형태로 이어 붙입니다.
```

- [ ] **Step 2: `final-document.md`**

`### 분기 결과` 절의 블록 목록 두 줄을 다음으로 바꾼다:

```markdown
- If(조건마다), Switch, Abs, For Iterator, While Iterator
- Saturate, DeadZone, RateLimiter, Relay, DiscreteIntegrator, Delay, DiscreteFir,
  DiscreteFilter, DiscreteTransferFcn(Coverage 결정마다)
- Enabled/Triggered/Resettable Subsystem(CUT 자신)
```

`- 그 밖의 블록(Saturate, MinMax, ...` 문장을 다음으로 바꾼다:

```markdown
- 그 밖의 블록(MinMax, MultiPortSwitch, SwitchCase, Sign, CombinatorialLogic)은
  결과가 셋 이상이라 정적 표기 `[T/F]` 그대로이며 사유를 남기지 않습니다.
- 결정마다 D가 있는 블록은 D 줄의 Coverage 결정 이름과 기록된 결정 이름을 맞춰
  결과를 적습니다. 리포트는 하한을 상한보다 먼저 적으므로 순서로는 짝짓지 않습니다.
  입력이 벡터라 같은 이름의 결정이 여러 개이거나, 기록된 결정이 D 줄과 하나씩
  맞지 않으면 `[T/F]`로 두고 `DECISION_OUTCOME_MISMATCH`를 남깁니다.
```

- [ ] **Step 3: 설계 문서 보정**

`docs/superpowers/specs/2026-10-08-decision-branch-split-design.md`:
- 머리의 `상태:`를 `구현됨 (실기 미확인)`으로 바꾼다.
- 6절의 "`DecisionBlockDetails` 시트에도 같은 열을 더한다." 문장을 "`DecisionBlockDetails` 시트에는 열을 더하지 않는다. 그 시트의 `JSON` 열이 항목 전체를 담으므로 `CoverageText`도 거기 있다."로 바꾼다.

- [ ] **Step 4: CHANGELOG**

`## Unreleased` 바로 아래 첫 항목으로:

```markdown
- **Coverage 결정이 여럿인 블록이 결정마다 D를 받습니다.** Saturate, DeadZone,
  RateLimiter, Relay, DiscreteIntegrator, Delay, DiscreteFir, DiscreteFilter,
  DiscreteTransferFcn의 D 줄이 `D1 [T/F]Saturate (U >= LL; LowerLimit=-32)`처럼
  Coverage 결정 이름과 파라미터 하나로 나뉩니다. 최종 문서는 이 블록들에도 실제
  결과를 적고, 결정 이름으로 짝짓습니다.
  - **명세서와 최종 문서의 D 번호가 바뀝니다.** 이 블록이 있는 CUT은 D가 분기 수만큼
    늘고 뒤쪽 번호가 밀립니다.
  - 결과가 셋 이상인 블록(MinMax, MultiPortSwitch, SwitchCase, Sign,
    CombinatorialLogic)은 그대로 `[T/F]`입니다.
```

- [ ] **Step 5: 인수인계 실기 확인 항목**

`docs/ai/codex-handoff.md`의 `## 실물 미검증 목록`에서 `최종 문서 분기 결과(\`DecisionOutcomes\`)` 항목 다음에:

```markdown
- 결정 단위 D(2026-10-08 설계): DiscreteFir의 결정 이름이 Delay와 같은 `Enable`,
  `Reset`이고 DiscreteTransferFcn이 DiscreteFilter와 같은 `Reset`인지(실기 스크립트에
  넣지 않음), 결정 이름이 MATLAB 릴리스·언어 설정에 따라 바뀌지 않는지, 벡터 입력
  블록의 결정 이름이 원소마다 같은지(다르면 MISMATCH로 보인다).
```

- [ ] **Step 6: 커밋**

```bash
git add docs/reference/test-specification.md docs/reference/final-document.md docs/superpowers/specs/2026-10-08-decision-branch-split-design.md CHANGELOG.md docs/ai/codex-handoff.md
git commit -m "docs: 결정 단위 D와 결정 이름 짝짓기를 설명한다"
```
(Co-Authored-By 줄.)
