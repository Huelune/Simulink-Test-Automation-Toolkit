function st_check_per_cut_collect_cvf()
%ST_CHECK_PER_CUT_COLLECT_CVF Collect the latest PER_CUT run again and compare.
%
% st_check_per_cut_collect_cvf
%
% Closes every loaded model, runs the coverage-filter and PER_CUT unit tests,
% collects the latest PER_CUT run again, and prints one screen comparing the
% previous collect with this one: CVF copies, CUT decision and execution
% coverage, decision-point counts, and what held each Harness name. Only
% counts and kinds are printed, never a model, test case or file name. Full
% error reports go to st_cvf_collect_check.txt in tempdir.
%
% Kept as a function so a stale copy of a pasted block cannot run old checks.

clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
loadedNames = find_system('type', 'block_diagram');
if ~isempty(loadedNames) && any(strcmp(get_param(loadedNames, 'Dirty'), 'on'))
    fprintf('저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요\n');
    return;
end
bdclose('all');
cfg = st_config();
st_log(cfg, 'INFO', 'PER_CUT collect CVF check start');
diagFile = 'st_cvf_collect_check.txt';
fid = fopen(fullfile(tempdir, diagFile), 'w');
if fid < 0, fid = fopen('nul', 'w'); end
closeDiag = onCleanup(@() fclose(fid)); %#ok<NASGU>
lines = {sprintf('MATLAB %s | 결과 정리 다시 하기', version('-release'))};

% Variables that evalc assigns are named first, or MATLAB may take them for functions.
testResults = [];
T = table();
testFiles = fullfile(st_project_root(), 'tests', 'unit', ...
    {'test_coverage_filters.m', 'test_per_cut_execution.m'});
try
    evalc('testResults = runtests(testFiles);');
    lines{end+1} = sprintf('단위 테스트 | %d | 통과 %d | 실패 %d | 미완료 %d', ...
        numel(testResults), sum([testResults.Passed]), ...
        sum([testResults.Failed]), sum([testResults.Incomplete]));
    failedTests = testResults([testResults.Failed] | [testResults.Incomplete]);
    for k = 1:numel(failedTests)
        lines{end+1} = sprintf('  실패 | %s', failedTests(k).Name); %#ok<AGROW>
    end
catch ME
    lines{end+1} = sprintf('단위 테스트 | 실행 오류 | %s', id_of(ME));
end
try
    evalc('T = st_load_targets(cfg.OnlyEnabled);');
catch ME
    lines{end+1} = sprintf('대상 목록 읽기 실패 | %s', id_of(ME));
end
harnessNames = strings(1, 0);
if ismember('HarnessName', T.Properties.VariableNames)
    names = string(T.HarnessName);
    harnessNames = reshape(unique(names(strlength(names) > 0)), 1, []);
end
pathKinds = strings(1, 0);
for name = harnessNames
    pathKinds(end+1) = st_model_file_kind(which(char(name)), cfg); %#ok<AGROW>
end
pathText = "-";
if ~isempty(pathKinds), pathText = strjoin(unique(pathKinds), ", "); end

try
    evalc('st_require_runtime_target();');
catch
end
stateBefore = harness_state(harnessNames, cfg);
[numbersBefore, message] = read_coverage(T, cfg, fid, 1);
if ~isempty(message), lines{end+1} = message; end
[logBefore, before] = newest_collect_log(cfg, "", fid);

collectText = 'OK';
try
    evalc('st_collect_per_cut_results();');
catch ME
    collectText = ['실패 ' id_of(ME)];
    fprintf(fid, '[결과 정리]\n%s\n\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
    st_log(cfg, 'WARN', 'PER_CUT collect CVF check | collect failed | %s', id_of(ME));
end
stateAfter = harness_state(harnessNames, cfg);
[~, after] = newest_collect_log(cfg, logBefore, fid);
numbersAfter = nan(height(T), 5);
if strcmp(collectText, 'OK')
    [numbersAfter, message] = read_coverage(T, cfg, fid, 2);
    if ~isempty(message), lines{end+1} = message; end
end

lines{end+1} = sprintf('결과 정리 다시 하기 %s', collectText);
lines{end+1} = dash(sprintf('결과 정리 로그 | 전 %s | 후 %s | 대상 시작 전 %g개 후 %g개', ...
    before.Name, after.Name, before.Starts, after.Starts));
lines{end+1} = sprintf('Harness 이름 %d개 | 경로가 가리키는 파일 %s', numel(harnessNames), pathText);
lines{end+1} = sprintf('Harness 이름 모델 | 결과 정리 전 %s', stateBefore);
lines{end+1} = sprintf('Harness 이름 모델 | 결과 정리 뒤 %s', stateAfter);
lines{end+1} = sprintf('이름을 차지한 다른 모델 | 전 %s', before.Held);
lines{end+1} = sprintf('이름을 차지한 다른 모델 | 후 %s', after.Held);
lines{end+1} = sprintf('결과 정리가 연 Harness 판정 | 후 %s', after.Loaded);
lines{end+1} = dash(sprintf('CVF 복사 0개/1개 이상 | 전 %g/%g | 후 %g/%g', before.Copies, after.Copies));
for r = 1:height(T)
    b = numbersBefore(r, :);
    a = numbersAfter(r, :);
    lines{end+1} = dash(sprintf(['대상 %d | CUT 결정 전 %g/%g 후 %g/%g | CUT 실행 전 %g/%g 후 %g/%g' ...
        ' | 결정 목록 전 %g 후 %g'], double(T.No(r)), b(1:2), a(1:2), b(3:4), a(3:4), b(5), a(5))); %#ok<AGROW>
end
fprintf(fid, '[화면 전체]\n');
fprintf(fid, '%s\n', lines{:});
clc;
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
if numel(lines) > 38, fprintf('%d줄 더 있음. 진단 파일 끝에 모두 있습니다\n', numel(lines) - 38); end
fprintf('진단 전문 파일: %s (임시 폴더)\n', diagFile);
st_log(cfg, 'INFO', 'PER_CUT collect CVF check complete | collectOK=%d', ...
    strcmp(collectText, 'OK'));
end


function text = harness_state(harnessNames, cfg)
% "없음", or the state of the last Harness name that is loaded, as kinds only.
text = "없음";
for name = harnessNames
    model = char(name);
    if ~bdIsLoaded(model), continue; end
    isHarness = "?";
    try
        isHarness = string(get_param(model, 'IsHarness'));
    catch
    end
    openHarness = "?";
    if bdIsLoaded(cfg.TopModel)
        try
            found = sltest.harness.find(cfg.TopModel, 'OpenOnly', 'on');
            openHarness = "아님";
            if any(strcmp({found.name}, model)), openHarness = "맞음"; end
        catch
        end
    end
    text = sprintf("열림(IsHarness %s, 열린 Harness %s, 파일 %s)", isHarness, openHarness, ...
        st_model_file_kind(get_param(model, 'FileName'), cfg));
end
end


function [file, info] = newest_collect_log(cfg, previous, fid)
% The newest collect log, unless it is still the one named by previous.
file = "";
info = struct('Name', '-', 'Starts', NaN, 'Copies', [NaN NaN], 'Held', "-", 'Loaded', "-");
logs = dir(fullfile(char(cfg.ResultDir), 'logs', '*_st_collect_per_cut_results*.log'));
if ~isempty(logs), logs = logs(~endsWith({logs.name}, '.console.log')); end
if isempty(logs), return; end
[~, newest] = max([logs.datenum]);
file = string(fullfile(logs(newest).folder, logs(newest).name));
if file == previous, return; end
try
    summary = st_summarize_collect_log(file, cfg);
    info = summary;
    info.Name = logs(newest).name(1:min(15, end));
catch ME
    fprintf(fid, '[로그 읽기]\n%s\n\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
end
end


function [values, message] = read_coverage(T, cfg, fid, phase)
% CUT decision covered/total, execution covered/total, decision points, per target.
values = nan(height(T), 5);
message = '';
runSource = [];
try
    evalc('runSource = st_final_document_run_source(cfg, ''PER_CUT'');');
catch ME
    message = sprintf('결과 정리 파일 찾기 실패 %d | %s', phase, id_of(ME));
    fprintf(fid, '[결과 정리 파일 %d]\n%s\n\n', phase, getReport(ME, 'extended', 'hyperlinks', 'off'));
    return;
end
for r = 1:height(T)
    files = runSource.Workbooks.File(runSource.Workbooks.No == double(T.No(r)));
    if isempty(files), continue; end
    try
        rows = readtable(files(end), 'Sheet', 'Coverage', 'TextType', 'string', ...
            'VariableNamingRule', 'preserve');
        cut = rows(rows.Level == "CUT", :);
        decision = cut(cut.Metric == "Decision", :);
        execution = cut(cut.Metric == "Execution", :);
        if height(decision) > 0, values(r, 1:2) = [decision.Covered(1), decision.Total(1)]; end
        if height(execution) > 0, values(r, 3:4) = [execution.Covered(1), execution.Total(1)]; end
        points = readtable(files(end), 'Sheet', 'DecisionPoints', 'TextType', 'string', ...
            'VariableNamingRule', 'preserve');
        values(r, 5) = height(points);
    catch ME
        fprintf(fid, '[대상 %d 읽기 %d]\n%s\n\n', double(T.No(r)), phase, ...
            getReport(ME, 'extended', 'hyperlinks', 'off'));
    end
end
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end


function text = dash(text)
text = strrep(text, 'NaN', '-');
end
