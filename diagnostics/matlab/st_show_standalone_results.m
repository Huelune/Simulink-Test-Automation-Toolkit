function st_show_standalone_results()
%ST_SHOW_STANDALONE_RESULTS Open the latest standalone submission's results to look at.
%
% For todo.md: the user wants to see the standalone results. Calls
% st_open_standalone_test_manager the way the manual's step 6 does, with
% the console it prints (paths and names) kept off the screen:
%   - Test Manager cleared first, then the saved standalone Result imported
%     and the window shown. Its coverage values carry no CVF.
%   - Each CUT's saved coverage (CVT) with its CVF: a report in the browser
%     and the standalone model highlighted.
% Stops when a model has unsaved changes; otherwise closes open models
% first, since a model of the same name from elsewhere stops the opener.
% One line per target: iteration outcomes and the CVF-applied CUT numbers.
clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
lines = {sprintf('MATLAB %s | standalone 결과 보기', version('-release'))};
cfg = st_config();
st_log(cfg, 'INFO', 'Show standalone results start');

loaded = find_system('type', 'block_diagram');
if ~isempty(loaded) && any(strcmp(get_param(loaded, 'Dirty'), 'on'))
    lines{end+1} = '저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요';
    show(lines);
    st_log(cfg, 'WARN', 'Show standalone results stopped | unsaved models');
    return;
end
if ~isempty(loaded), bdclose('all'); end

% Variables that evalc assigns are named first, or MATLAB may take them for functions.
openInfo = [];
try
    evalc(['openInfo = st_open_standalone_test_manager(''ClearTestManager'', true, ' ...
        '''ImportResults'', true, ''ShowSavedCoverage'', true);']);
catch ME
    lines{end+1} = sprintf('열기 실패 | %s | 전문 st_todo_check.txt (임시 폴더)', id_of(ME));
    fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
    if fid >= 0
        fprintf(fid, '[standalone 결과 보기]\n%s\n\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
        fclose(fid);
    end
    st_log(cfg, 'ERROR', 'Show standalone results failed | %s', id_of(ME));
    show(lines);
    return;
end

saved = openInfo.SavedCoverage;
lines{end+1} = sprintf('Test Manager 결과 %s | 브라우저 보고서(CVF 적용) OK %d 실패 %d', ...
    openInfo.ResultStatus, sum(saved.Status == "OK"), sum(saved.Status ~= "OK"));
caseResults = {};
if strcmp(openInfo.ResultStatus, 'IMPORTED')
    try
        caseResults = st_collect_test_case_results(sltest.testmanager.getResultSets);
    catch
    end
end
for k = 1:height(saved)
    coverageText = sprintf('CUT 결정 %d/%d 실행 %d/%d', saved.DecisionCovered(k), ...
        saved.DecisionTotal(k), saved.ExecutionCovered(k), saved.ExecutionTotal(k));
    if saved.Status(k) ~= "OK"
        coverageText = sprintf('Coverage 실패 %s', saved.ErrorId(k));
    end
    lines{end+1} = sprintf('대상 %d | %s | %s', k, ...
        iteration_text(caseResults, saved.TestCaseName(k)), coverageText); %#ok<AGROW>
end
lines{end+1} = 'Test Manager의 Coverage 값은 CVF가 빠진 값입니다. CVF를 건 값은 브라우저 보고서와 모델 색 표시로 보세요';
st_log(cfg, 'INFO', 'Show standalone results complete | result %s | reports %d', ...
    openInfo.ResultStatus, sum(saved.Status == "OK"));
show(lines);
end


function text = iteration_text(caseResults, caseName)
text = 'Iteration 없음';
for c = 1:numel(caseResults)
    if string(caseResults{c}.Name) ~= caseName, continue; end
    try
        iterations = getIterationResults(caseResults{c});
        outcomes = strings(numel(iterations), 1);
        for i = 1:numel(iterations), outcomes(i) = string(iterations(i).Outcome); end
        text = sprintf('Iteration %d 통과 %d 실패 %d', numel(iterations), ...
            sum(outcomes == "Passed"), sum(outcomes == "Failed"));
    catch ME
        text = sprintf('Iteration 읽기 실패 %s', id_of(ME));
    end
    return;
end
end


function show(lines)
clc;
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
if numel(lines) > 38, fprintf('%d줄 더 있음\n', numel(lines) - 38); end
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
