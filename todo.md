# MATLAB 실행 요청

작성: 2026-10-07. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 단위 테스트 전부 통과 확인 (기존 실패 6건을 고친 뒤, 2026-10-12)

이미 실패하던 6건과, 아무것도 검사하지 않던 금지 호출 검사 2곳을 고쳤다(`a1ea839`). 이제
5개 파일이 모두 통과해야 한다. `tests`는 `st_setup`이 path에 넣지 않으므로 파일 경로로
돌린다. 한 테스트 안에서 여러 검사가 실패하면 첫 실패와 함께 `(+N more)`로 개수를 찍는다.
이유 문장의 경로와 계정은 `<path>`, `<user>`로 가린다.

```matlab
clearvars  % a variable left over from an earlier block (e.g. "split") would shadow a function
st_setup
unitDir = fullfile(st_project_root(), 'tests', 'unit');
names = ["test_decision_outcomes", "test_export_final_document", ...
    "test_export_test_specification", "test_specification_decision_blocks", ...
    "test_coverage_filters"];
r = runtests(cellstr(fullfile(unitDir, names + ".m")));
clc
logFile = fullfile(tempdir, 'failed_tests.txt');
fid = fopen(logFile, 'w', 'n', 'UTF-8');
fprintf('Passed %d / %d\n', sum([r.Passed]), numel(r));
for k = find(~[r.Passed])
    name = string(r(k).Name);
    short = extractAfter(name, "/");
    records = r(k).Details.DiagnosticRecord;
    at = NaN;
    reason = "(no diagnostic)";
    more = "";
    if ~isempty(records)
        for q = 1:numel(records)
            fprintf(fid, '%s [%d]\n%s\n\n', name, q, records(q).Report);
        end
        if numel(records) > 1, more = sprintf(' (+%d more)', numel(records) - 1); end
        rec = records(1);
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
    reason = regexprep(reason, '[A-Za-z]:\\[^\s''"]*', '<path>');
    reason = strrep(reason, getenv('USERNAME'), '<user>');
    reason = strtrim(regexprep(reason, '\s+', ' '));
    if strlength(reason) > 230, reason = extractBefore(reason, 231) + "..."; end
    fprintf('%s:%d%s\n   %s\n', short, at, more, reason);
end
fclose(fid);
fprintf('full reports: %%TEMP%%\\failed_tests.txt (keep it on this PC)\n');
```

확인할 것: `Passed n / n`으로 실패가 0이다. 실패가 남으면 그 줄이 원인이다.

돌려줄 것: 화면 캡처 한 장.
