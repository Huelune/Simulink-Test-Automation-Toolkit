# MATLAB 실행 요청

작성: 2026-10-07. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 단위 테스트 다시 돌리기 (기존 실패 6건을 고친 뒤)

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
