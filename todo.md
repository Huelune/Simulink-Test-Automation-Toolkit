# MATLAB 실행 요청

작성: 2026-10-07. 결과를 붙여 주면 해당 절은 지운다.

## 1. 실제 모델로 최종 문서의 분기 결과 확인

단위 테스트는 2026-10-08에 통과했다(167/173, 남은 6건은 무관한 기존 실패). 이제 실제
모델에서 최종 문서가 결정마다 D를 나누고 `[T]`/`[F]`/`[T/F]`/`[-]`를 적는지 본다.

**먼저 결과 정리를 이 develop 버전으로 다시 한다.** `DecisionOutcomes` 시트는 결과 정리
때 쓰이므로, 이전 버전으로 정리한 결과로는 모든 행이 `DECISION_OUTCOME_UNAVAILABLE`이 된다.
PER_CUT으로 돌렸으면 `st_collect_per_cut_results`, BATCH면 `st_generate_test_report`.

그다음 아래를 돌린다. 최종 문서를 새 파일로 만들고, 한 화면에 요약한다.

```matlab
st_setup
[T, file] = st_export_final_document();
clc
meta = readtable(file, 'Sheet', 'Metadata', 'TextType', 'string');
for key = ["ResultRunMode", "ResultRunId", "DecisionOutcomeUnits", ...
        "DecisionOutcomeUnavailableRows", "DecisionOutcomeMismatchRows"]
    value = meta.Value(meta.Key == key);
    if isempty(value), value = "(none)"; end
    fprintf('%-32s %s\n', key, value(1));
end
lines = splitlines(strjoin(string(T.Description), newline));
tok = regexp(cellstr(lines), '^D\d+ \[([^\]]*)\]', 'tokens', 'once');
labels = string(cellfun(@(c) c{1}, tok(~cellfun(@isempty, tok)), 'UniformOutput', false));
fprintf('D lines: %d | [T] %d | [F] %d | [T/F] %d | [-] %d\n', numel(labels), ...
    sum(labels == "T"), sum(labels == "F"), sum(labels == "T/F"), sum(labels == "-"));
split = unique(lines(contains(lines, ["U >= LL", "U > UL", "X < LL", "X > UL", ...
    "Reset;", "Enable;", "OnThresh", "OffThresh"])), 'stable');
fprintf('split-decision lines (first 12 of %d):\n', numel(split));
for s = reshape(split(1:min(12, end)), 1, [])
    fprintf('  %s\n', s);
end
R = readtable(file, 'Sheet', 'TestResults', 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
reason = R.("확인 사유");
reason(ismissing(reason)) = "";
hit = find(contains(reason, "DECISION_OUTCOME"));
fprintf('rows with DECISION_OUTCOME reasons: %d (first 5)\n', numel(hit));
for i = reshape(hit(1:min(5, end)), 1, [])
    fprintf('  %s | %s | %s\n', R.TestCaseName(i), R.("Iteration명")(i), reason(i));
end
fprintf('file: %s\n', file);
```

확인할 것:
- `DecisionOutcomeUnits`가 0보다 크다(iteration별 coverage가 실제로 읽혔다).
- `[T]`·`[F]`·`[-]`가 나온다. 전부 `[T/F]`면 결과가 붙지 않은 것이다.
- split-decision 줄에 Saturation 등이 `U >= LL; LowerLimit=...`처럼 결정마다 나뉘어 있다.
- `DECISION_OUTCOME` 사유가 있으면 어떤 블록·행인지(아래 5줄).
- Discrete FIR Filter, Discrete Transfer Fcn이 있으면 그 줄이 MISMATCH 없이 나오는지
  (결정 이름을 실기로 확인하지 못한 블록이다).

돌려줄 것: 화면 캡처 한 장.

### 1-1. 분기 결과가 하나도 안 붙을 때 (2026-10-08: Units 0, 전부 UNAVAILABLE)

결과 workbook에 `DecisionOutcomes` 시트가 있는지, 있으면 UNIT 행이 있는지, 마지막 결과
정리 로그에 분기 결과 수집 줄이 있는지를 한 화면에 찍는다. 아무것도 바꾸지 않는다.

```matlab
st_setup
cfg = st_config();
pointer = jsondecode(fileread(cfg.PerCutLatestPointer));
runDir = string(pointer.RunDirectory);
files = dir(fullfile(runDir, 'targets', '*', '*', 'TestSummary.xlsx'));
clc
fprintf('run: %s\n', runDir);
noSheet = strings(0,1); noUnit = strings(0,1); units = 0; decisions = 0;
for k = 1:numel(files)
    f = fullfile(files(k).folder, files(k).name);
    [targetDir, stage] = fileparts(files(k).folder);
    [~, target] = fileparts(targetDir);
    stamp = string(datetime(files(k).datenum, 'ConvertFrom', 'datenum', 'Format', 'MM-dd HH:mm'));
    label = string(target) + "/" + stage + " (" + stamp + ")";
    if ~any(sheetnames(f) == "DecisionOutcomes")
        noSheet(end+1,1) = label; continue;
    end
    T = readtable(f, 'Sheet', 'DecisionOutcomes', 'TextType', 'string');
    if height(T) == 0 || ~ismember('Kind', T.Properties.VariableNames)
        noUnit(end+1,1) = label; continue;
    end
    u = sum(T.Kind == "UNIT");
    units = units + u;
    decisions = decisions + sum(T.Kind == "DECISION");
    if u == 0, noUnit(end+1,1) = label; end
end
fprintf('workbooks %d | no sheet %d | sheet without UNIT rows %d | UNIT rows %d | DECISION rows %d\n', ...
    numel(files), numel(noSheet), numel(noUnit), units, decisions);
for x = reshape(noSheet(1:min(3, end)), 1, []), fprintf('  no sheet: %s\n', x); end
for x = reshape(noUnit(1:min(3, end)), 1, []), fprintf('  no UNIT : %s\n', x); end
logs = dir(fullfile(cfg.ResultDir, 'logs', '*_st_collect_per_cut_results.log'));
if isempty(logs)
    fprintf('no st_collect_per_cut_results log in %s\n', fullfile(cfg.ResultDir, 'logs'));
else
    [~, newest] = max([logs.datenum]);
    text = splitlines(string(fileread(fullfile(logs(newest).folder, logs(newest).name))));
    scan = text(contains(text, "Decision outcome scan"));
    warn = scan(contains(scan, "WARN"));
    done = scan(contains(scan, "scan end"));
    fprintf('log %s | outcome lines %d | WARN %d\n', logs(newest).name, numel(scan), numel(warn));
    for x = reshape([warn(1:min(3, end)); done(1:min(3, end))], 1, [])
        fprintf('  %s\n', extractBefore(x + blanks(150), 151));
    end
end
```

읽는 법:
- `no sheet`가 workbook 수와 같다 → 결과 정리를 새 버전으로 다시 하지 않은 것이다.
  `st_collect_per_cut_results`를 돌리고 1절을 다시 돌린다.
- 시트는 있는데 `UNIT rows 0` → iteration별 coverage를 읽지 못한 것이다. 로그 WARN 줄의
  `Reason=`이 원인이다.

돌려줄 것: 화면 캡처 한 장.

## 2. 단위 테스트 다시 돌리기 (기존 실패 6건을 고친 뒤)

이번 기능과 무관하게 이미 실패하던 테스트 6건을 따로 고친다. 고친 뒤 아래를 다시 돌린다.
`tests`는 `st_setup`이 path에 넣지 않으므로 파일 경로로 돌린다.

```matlab
st_setup
unitDir = fullfile(st_project_root(), 'tests', 'unit');
names = ["test_decision_outcomes", "test_export_final_document", ...
    "test_export_test_specification", "test_specification_decision_blocks", ...
    "test_coverage_filters"];
r = runtests(cellstr(fullfile(unitDir, names + ".m")));
clc
known = ["testScanReportsTheSubsystemNotThePortBlock", ...
    "testCatalogHidesOnlySwitchCaseExpressionInTheMainCell", ...
    "testApplicationCanIsolateAndRestoreExistingFilters", ...
    "testGeneratedFilterTargetsDirectChildSubsystems", ...
    "testWorkbookKeepsFirstPrimaryOverflowPartAndAddsRowNote", ...
    "testStaticScanIgnoresCommentsAndDocumentationStrings"];
logFile = fullfile(tempdir, 'failed_tests.txt');
fid = fopen(logFile, 'w', 'n', 'UTF-8');
skipped = 0;
fprintf('Passed %d / %d\n', sum([r.Passed]), numel(r));
for k = find(~[r.Passed])
    name = string(r(k).Name);
    short = extractAfter(name, "/");
    rec = r(k).Details.DiagnosticRecord;
    at = NaN;
    reason = "(no diagnostic)";
    if ~isempty(rec)
        rec = rec(1);
        fprintf(fid, '%s\n%s\n\n', name, rec.Report);
        for s = reshape(rec.Stack, 1, [])
            if contains(s.file, unitDir), at = s.line; break; end
        end
        if isprop(rec, 'Exception') && ~isempty(rec.Exception)
            reason = string(rec.Exception.message);
        elseif isprop(rec, 'FrameworkDiagnosticResults') && ~isempty(rec.FrameworkDiagnosticResults)
            reason = strjoin(string({rec.FrameworkDiagnosticResults.DiagnosticText}), " ");
        else
            reason = string(rec.Report);
        end
    end
    if any(short == known), skipped = skipped + 1; continue; end
    reason = strtrim(regexprep(reason, '\s+', ' '));
    if strlength(reason) > 230, reason = extractBefore(reason, 231) + "..."; end
    fprintf('%s:%d\n   %s\n', short, at, reason);
end
fclose(fid);
fprintf('known failures skipped: %d | full reports: %s\n', skipped, logFile);
```

돌려줄 것: 화면 캡처 한 장. 고친 테스트는 `known` 목록에서 빼고 돌린다.

기존 실패 6건:

- `test_specification_decision_blocks/testScanReportsTheSubsystemNotThePortBlock`:
  지금 코드에 없는 `conditional_subsystems` 함수를 찾는다.
- `test_specification_decision_blocks/testCatalogHidesOnlySwitchCaseExpressionInTheMainCell`:
  `HIDE`가 SwitchCase 하나라고 가정하지만 catalog에는 CombinatorialLogic과
  Enable/Trigger/Reset도 `HIDE`다.
- `test_coverage_filters/testApplicationCanIsolateAndRestoreExistingFilters`(118행):
  `CoverageFilterReplacementRequiresRuntime`를 찾지만 지금 `src`에 없다.
- `test_coverage_filters/testGeneratedFilterTargetsDirectChildSubsystems`(178행):
  큰따옴표 MATLAB 문자열 안의 `\\(`가 역슬래시 자체를 찾는 정규식이 되어 맞지 않는다.
- `test_export_test_specification/testWorkbookKeepsFirstPrimaryOverflowPartAndAddsRowNote`(169행):
  빈 `Message` 셀을 readtable이 `NaN`으로 읽는다.
- `test_export_test_specification/testStaticScanIgnoresCommentsAndDocumentationStrings`(304행):
  `st_executable_source`가 호출을 하나도 남기지 않는다.
