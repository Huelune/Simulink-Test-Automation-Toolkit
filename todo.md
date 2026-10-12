# MATLAB 실행 요청

작성: 2026-10-07. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 실제 모델로 최종 문서의 분기 결과 확인

분기 결과(`DecisionOutcomes` 시트)는 **결과 정리 때** 기록된다. 그래서 블록 맨 앞에서 결과
정리를 다시 한다. 코드를 고친 뒤 결과 정리를 건너뛰면 예전 결과가 그대로 나온다
(2026-10-12 확인: 결과 정리가 10-08이라 수정이 반영되지 않았다). PER_CUT 기준이며, BATCH로
돌렸으면 첫 줄을 `st_generate_test_report`로 바꾼다. 결과 정리는 CUT 수만큼 시간이 걸린다.

```matlab
clearvars  % a variable left over from an earlier block (e.g. "split") would shadow a function
st_setup
st_collect_per_cut_results();
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

확인할 것: `DecisionOutcomeUnits`가 0보다 크다. `[T]`·`[F]`·`[-]`가 나온다.
2026-10-12 수정 뒤에는 함수 호출 Triggered Subsystem 행도 `[T]`(실행됨)나 `[-]`가 되어
`DECISION_OUTCOME_UNAVAILABLE`이 0이어야 한다(10-08 확인 때는 19행이 남았다). 0이 아니면
결과를 알려 주면 원인 분류 진단을 다시 올린다.

돌려줄 것: 화면 캡처 한 장.

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
