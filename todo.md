# MATLAB 실행 요청

작성: 2026-10-07. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 실제 모델로 최종 문서의 분기 결과 확인

**먼저 결과 정리를 이 develop 버전으로 다시 한다.** PER_CUT이면 `st_collect_per_cut_results`,
BATCH면 `st_generate_test_report`. `DecisionOutcomes` 시트는 결과 정리 때 쓰인다.

```matlab
clearvars  % a variable left over from an earlier block (e.g. "split") would shadow a function
st_setup
[T, file] = st_export_final_document();
clc
meta = readtable(file, 'Sheet', 'Metadata', 'TextType', 'string');
for key = ["ResultRunMode", "DecisionOutcomeUnits", ...
        "DecisionOutcomeUnavailableRows", "DecisionOutcomeMismatchRows"]
    value = meta.Value(meta.Key == key);
    if isempty(value), value = "(none)"; end
    fprintf('%-32s %s\n', key, value(1));
end
lines = splitlines(strjoin(string(T.Description), newline));
tok = regexp(cellstr(lines), '^D\d+ \[([^\]]*)\]', 'tokens', 'once');
labels = string(cellfun(@(c) c{1}, tok(~cellfun(@isempty, tok)), 'UniformOutput', false));
fprintf('D lines %d | [T] %d | [F] %d | [T/F] %d | [-] %d\n', numel(labels), ...
    sum(labels == "T"), sum(labels == "F"), sum(labels == "T/F"), sum(labels == "-"));
texts = ["U >= LL", "U > UL", "X < LL", "X > UL", "U >= OnThresh", "U <= OffThresh", ...
    "Reset;", "Enable;"];
counts = arrayfun(@(t) sum(contains(lines, "(" + t)), texts);
fprintf('split-decision lines: %s\n', strjoin(texts + "=" + counts, " | "));
R = readtable(file, 'Sheet', 'TestResults', 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
reason = R.("확인 사유");
reason(ismissing(reason)) = "";
for code = ["DECISION_OUTCOME_UNAVAILABLE", "DECISION_OUTCOME_MISMATCH", "DECISION_OUTCOME_AMBIGUOUS"]
    fprintf('rows with %-30s %d\n', code, sum(contains(reason, code)));
end
[~, name, ext] = fileparts(file);
fprintf('file: result\\%s%s\n', name, ext);
```

확인할 것: `DecisionOutcomeUnits`가 0보다 크다. `[T]`·`[F]`·`[-]`가 나온다. UNAVAILABLE이
남으면 1-1절을 돌린다.

돌려줄 것: 화면 캡처 한 장.

### 1-1. UNAVAILABLE이 남을 때: 원인 분류 (개수만)

1절을 돌린 직후에 돌린다. 마지막 최종 문서 로그와 마지막 결과 정리 로그, 결과 workbook의
`DecisionOutcomes` 시트를 대조해, 결과가 안 붙은 이유를 종류별 개수로 찍는다. 아무것도
바꾸지 않는다.

```matlab
clearvars  % a variable left over from an earlier block (e.g. "split") would shadow a function
st_setup
cfg = st_config();
logDir = fullfile(cfg.ResultDir, 'logs');
exportLog = strings(0,1); collectLog = strings(0,1); stamps = ["none", "none"];
f = dir(fullfile(logDir, '*_st_export_final_document.log'));
if ~isempty(f)
    [~, i] = max([f.datenum]);
    exportLog = splitlines(string(fileread(fullfile(f(i).folder, f(i).name))));
    stamps(1) = extractBefore(string(f(i).name), 16);
end
f = dir(fullfile(logDir, '*_st_collect_per_cut_results.log'));
if ~isempty(f)
    [~, i] = max([f.datenum]);
    collectLog = splitlines(string(fileread(fullfile(f(i).folder, f(i).name))));
    stamps(2) = extractBefore(string(f(i).name), 16);
end
sq = @(x) strtrim(regexprep(string(x), '\s+', ' '));
% The value after "<name>=" up to the next '|'. \< keeps Case= from matching TestCase=.
% A line without the field comes back whole, which then simply matches nothing.
fieldOf = @(line, name) strtrim(string(regexprep(char(line), ['^.*?\<' name '=([^|]*).*$'], '$1')));
pointer = jsondecode(fileread(cfg.PerCutLatestPointer));
books = dir(fullfile(string(pointer.RunDirectory), 'targets', '*', '*', 'TestSummary.xlsx'));
recCase = strings(0,1); recKey = strings(0,1); recPath = strings(0,1);
for k = 1:numel(books)
    b = fullfile(books(k).folder, books(k).name);
    if ~any(sheetnames(b) == "DecisionOutcomes"), continue; end
    opts = detectImportOptions(b, 'Sheet', 'DecisionOutcomes', 'TextType', 'string');
    opts = setvartype(opts, intersect({'TestCaseName','IterationName','Kind','RelativePath'}, ...
        opts.VariableNames), 'string');
    S = readtable(b, opts);
    if height(S) == 0, continue; end
    tc = sq(S.TestCaseName); tc(ismissing(tc)) = "";
    it = sq(S.IterationName); it(ismissing(it)) = "";
    rp = sq(S.RelativePath); rp(ismissing(rp)) = "";
    isUnit = string(S.Kind) == "UNIT";
    recCase = [recCase; tc(isUnit)];
    recKey = [recKey; tc(~isUnit) + "|" + it(~isUnit)];
    recPath = [recPath; rp(~isUnit)];
end
clc
fprintf('logs: final document %s | collect %s | workbooks %d\n', stamps(1), stamps(2), numel(books));
um = exportLog(contains(exportLog, "Decision outcome unit not found"));
otherIter = 0; noCase = 0;
for k = 1:numel(um)
    if any(recCase == sq(fieldOf(um(k), 'Case'))), otherIter = otherIter + 1; else, noCase = noCase + 1; end
end
fprintf('unit not found %d: case recorded under other iteration names %d | case not recorded %d\n', ...
    numel(um), otherIter, noCase);
nr = exportLog(contains(exportLog, "Decision outcome not recorded for a two-way block"));
skipLines = collectLog(contains(collectLog, "skipped a block without two-way decisions"));
failLines = collectLog(contains(collectLog, "Decision outcome lookup failed"));
skipped = 0; failed = 0; otherPath = 0; neverSeen = 0; types = strings(0,1); tf = false(0,1);
for k = 1:numel(nr)
    p = sq(fieldOf(nr(k), 'Path'));
    key = sq(fieldOf(nr(k), 'Case')) + "|" + sq(fieldOf(nr(k), 'Iteration'));
    hit = skipLines(contains(skipLines, "Path=" + p + " |"));
    if ~isempty(hit)
        skipped = skipped + 1;
        types(end+1,1) = fieldOf(hit(1), 'BlockType');
        pairs = strtrim(split(fieldOf(hit(1), 'Outcomes'), ";"));
        tf(end+1,1) = all(arrayfun(@(q) all(startsWith(lower(strtrim(split(q, "/"))), ["true", "false"])), pairs));
    elseif any(contains(failLines, "Path=" + p))
        failed = failed + 1;
    else
        parts = split(p, "/");
        if any(recKey == key & endsWith(recPath, parts(end)))
            otherPath = otherPath + 1;
        else
            neverSeen = neverSeen + 1;
        end
    end
end
fprintf('two-way block not recorded %d: skipped by collector %d | lookup failed %d | recorded under another path %d | never seen %d\n', ...
    numel(nr), skipped, failed, otherPath, neverSeen);
[g, ~, idx] = unique(types);
for j = 1:numel(g)
    fprintf('  skipped %-20s %d (outcome texts start with true/false: %d)\n', g(j), sum(idx == j), sum(tf(idx == j)));
end
fprintf('mismatch lines: text %d | count %d\n', sum(contains(exportLog, "Decision outcome text mismatch")), ...
    sum(contains(exportLog, "Decision outcome count mismatch")));
fprintf('collector: units without coverage %d | block list failed %d | case not in target list %d\n', ...
    sum(contains(collectLog, "found no coverage for a unit")), ...
    sum(contains(collectLog, "could not list blocks")), ...
    sum(contains(collectLog, "skipped a test case not in the target list")));
```

돌려줄 것: 화면 캡처 한 장. 찍히는 것은 개수, 로그 시각, Simulink 블록 종류 이름뿐이다.

### 1-2. TriggerPort 결과 텍스트와 coverage 없는 단위 (2026-10-08: 19건 모두 TriggerPort)

1-1에서 결과가 안 붙은 19건이 모두 Triggered Subsystem(TriggerPort)이었고, 수집기는 결과
텍스트가 `true`/`false`로 시작하지 않아 건너뛰었다. 그 결과 텍스트의 모양과, coverage가 없던
단위 12개의 이유를 개수로 찍는다. 결과 텍스트는 Coverage 도구가 붙이는 표준 이름이며, 괄호
안 내용은 `(...)`로 가린다.

```matlab
clearvars  % a variable left over from an earlier block would shadow a function
st_setup
cfg = st_config();
f = dir(fullfile(cfg.ResultDir, 'logs', '*_st_collect_per_cut_results.log'));
[~, newest] = max([f.datenum]);
logText = splitlines(string(fileread(fullfile(f(newest).folder, f(newest).name))));
fieldOf = @(line, name) strtrim(string(regexprep(char(line), ['^.*?\<' name '=([^|]*).*$'], '$1')));
clc
trig = logText(contains(logText, "skipped a block without two-way decisions") & ...
    contains(logText, "BlockType=TriggerPort"));
shapes = strings(numel(trig), 1);
for k = 1:numel(trig)
    shapes(k) = regexprep(fieldOf(trig(k), 'Outcomes'), '\([^)]*\)', '(...)');
end
[g, ~, idx] = unique(shapes);
fprintf('TriggerPort skipped %d | distinct outcome-text shapes %d (decisions split by ";", outcomes by "/")\n', ...
    numel(trig), numel(g));
for j = 1:min(5, numel(g))
    fprintf('  %3d x  %s\n', sum(idx == j), extractBefore(g(j) + blanks(100), 101));
end
noCov = logText(contains(logText, "found no coverage for a unit"));
reasons = strings(numel(noCov), 1);
for k = 1:numel(noCov)
    reasons(k) = fieldOf(noCov(k), 'Reason');
end
fprintf('units without coverage %d: no object answers for the CUT %d | no coverage results %d | lookup failed %d\n', ...
    numel(noCov), sum(startsWith(reasons, "no coverage object answers")), ...
    sum(startsWith(reasons, "the unit carries no coverage results")), ...
    sum(startsWith(reasons, "getCoverageResults failed")));
stages = ["INITIAL", "FINAL"];
for s = stages
    fprintf('  scan end lines for %-7s %d\n', s, sum(contains(logText, "Decision outcome scan end | Run=" + s)));
end
```

돌려줄 것: 화면 캡처 한 장. 찍히는 것은 개수와 Coverage 도구의 결과 이름 모양뿐이다.

## 2. 단위 테스트 다시 돌리기 (기존 실패 6건을 고친 뒤)

이번 기능과 무관하게 이미 실패하던 테스트 6건을 따로 고친다. 고친 뒤 아래를 다시 돌린다.
`tests`는 `st_setup`이 path에 넣지 않으므로 파일 경로로 돌린다. 이유 문장의 경로와 계정은
`<path>`, `<user>`로 가린다.

```matlab
clearvars  % a variable left over from an earlier block (e.g. "split") would shadow a function
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
    reason = regexprep(reason, '[A-Za-z]:\\[^\s''"]*', '<path>');
    reason = strrep(reason, getenv('USERNAME'), '<user>');
    reason = strtrim(regexprep(reason, '\s+', ' '));
    if strlength(reason) > 230, reason = extractBefore(reason, 231) + "..."; end
    fprintf('%s:%d\n   %s\n', short, at, reason);
end
fclose(fid);
fprintf('known failures skipped: %d | full reports: %%TEMP%%\\failed_tests.txt (keep it on this PC)\n', skipped);
```

돌려줄 것: 화면 캡처 한 장. 고친 테스트는 `known` 목록에서 빼고 돌린다.

기존 실패 6건(이름은 이 저장소의 테스트 이름이다):

- `testScanReportsTheSubsystemNotThePortBlock`: 지금 코드에 없는 함수를 찾는다.
- `testCatalogHidesOnlySwitchCaseExpressionInTheMainCell`: `HIDE`가 SwitchCase 하나라고 가정한다.
- `testApplicationCanIsolateAndRestoreExistingFilters`: 지금 `src`에 없는 식별자를 찾는다.
- `testGeneratedFilterTargetsDirectChildSubsystems`: 큰따옴표 문자열 안의 `\\(` 정규식 오류.
- `testWorkbookKeepsFirstPrimaryOverflowPartAndAddsRowNote`: 빈 셀을 readtable이 `NaN`으로 읽는다.
- `testStaticScanIgnoresCommentsAndDocumentationStrings`: 정적 스캔 보조 함수가 호출을 찾지 못한다.
