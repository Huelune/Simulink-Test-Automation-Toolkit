function st_show_unit_tests(names)
%ST_SHOW_UNIT_TESTS Run unit test files and show the result on one screen.
%
% st_show_unit_tests({'test_a.m', 'test_b.m'})
%
% One line per file with its counts, then one line per failed test with
% the identifier of what stopped it. The full failure reports go to
% tempdir/st_unit_tests.txt. Fixture values never reach the screen.
cfg = st_config();
st_log(cfg, 'INFO', 'Unit test check start | files=%d', numel(names));
reportFile = fullfile(tempdir, 'st_unit_tests.txt');
if isfile(reportFile), delete(reportFile); end
lines = {};
failedTotal = 0;
for f = 1:numel(names)
    file = fullfile(st_project_root(), 'tests', 'unit', names{f});
    results = [];
    try
        evalc('results = runtests(file);');
    catch ME
        lines{end+1} = sprintf('%s | 실행 오류 | %s', names{f}, ME.identifier); %#ok<AGROW>
        failedTotal = failedTotal + 1;
        continue;
    end
    bad = results([results.Failed] | [results.Incomplete]);
    failedTotal = failedTotal + numel(bad);
    lines{end+1} = sprintf('%s | %d | 통과 %d | 실패 %d | 미완료 %d', names{f}, numel(results), ...
        sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete])); %#ok<AGROW>
    for k = 1:numel(bad)
        lines{end+1} = sprintf('  실패 | %s | %s', test_name(bad(k)), failure_id(bad(k))); %#ok<AGROW>
        write_report(bad(k), reportFile);
    end
end
if failedTotal == 0
    lines{end+1} = '모두 통과';
    st_log(cfg, 'INFO', 'Unit test check complete | all passed');
else
    lines{end+1} = '실패 전문: st_unit_tests.txt (임시 폴더, 이 PC에서만 보세요). 이 화면을 보내 주세요';
    st_log(cfg, 'WARN', 'Unit test check found failures | failed=%d', failedTotal);
end
clc;
lines = [{sprintf('MATLAB %s | 단위 테스트', version('-release'))}, lines];
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
if numel(lines) > 38, fprintf('%d줄 더 있음\n', numel(lines) - 38); end
end


function text = test_name(result)
% "file/testName" -> the test function name only.
text = string(result.Name);
if contains(text, '/'), text = extractAfter(text, '/'); end
end


function text = failure_id(result)
% The identifier of the error or failed verification, never its message.
text = '(식별자 없음)';
try
    records = result.Details.DiagnosticRecord;
    for k = 1:numel(records)
        if isprop(records(k), 'Exception') && ~isempty(records(k).Exception) && ...
                ~isempty(records(k).Exception.identifier)
            text = records(k).Exception.identifier;
            return;
        end
        if isprop(records(k), 'Event') && ~isempty(records(k).Event)
            text = char(records(k).Event);
        end
    end
catch
end
end


function write_report(result, file)
fid = fopen(file, 'a');
if fid < 0, return; end
fprintf(fid, '[%s]\n', result.Name);
try
    records = result.Details.DiagnosticRecord;
    for k = 1:numel(records), fprintf(fid, '%s\n', records(k).Report); end
catch
end
fprintf(fid, '\n');
fclose(fid);
end
