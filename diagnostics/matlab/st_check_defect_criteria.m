function st_check_defect_criteria(extraLines, title, includeStandalone)
%ST_CHECK_DEFECT_CRITERIA Read the defect iterations' Custom Criteria of both runs.
%
% st_check_defect_criteria(extraLines, title, includeStandalone)
%
% includeStandalone false (default true) skips step 1 and reads the PER_CUT
% run alone. title replaces the screen title.
%
% Replaces the hand check of todo.md: opening each defect iteration's
% Custom Criteria Results in Test Manager.
%   1. Opens the latest standalone pipeline the way its manual does
%      (st_open_standalone_test_manager: Test Manager cleared first, the
%      saved result imported, each CUT's saved coverage report opened in the
%      browser and the standalone model highlighted).
%   2. Imports the latest PER_CUT run's saved ResultSets beside it, the
%      stage the final document reads (FINAL, else INITIAL).
%   3. For every target and both runs, reads each defect iteration's Custom
%      Criteria result and counts it by st_defect_criteria_kind.
% The screen shows Excel row numbers, counts, fixed words and error
% identifiers only. extraLines go under the title. Long error reports go to
% tempdir/st_todo_check.txt. What is left to look at by eye is the report's
% Filter section and the model highlight, and both stay open.
if nargin < 1, extraLines = {}; end
if nargin < 2 || isempty(title), title = '결함 TC Custom Criteria'; end
if nargin < 3, includeStandalone = true; end
clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
lines = [{sprintf('MATLAB %s | %s', version('-release'), title)}, ...
    reshape(extraLines, 1, [])];
report = "";
cfg = st_config();
st_log(cfg, 'INFO', 'Defect criteria check start | standalone %d', includeStandalone);

% Only the standalone opener closes and loads models.
loaded = find_system('type', 'block_diagram');
if includeStandalone && ~isempty(loaded) && any(strcmp(get_param(loaded, 'Dirty'), 'on'))
    lines{end+1} = '저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요';
    show(lines, report);
    st_log(cfg, 'WARN', 'Defect criteria check stopped | unsaved models');
    return;
end

% Variables that evalc assigns are named first, or MATLAB may take them for functions.
targets = table();
sldvProfile = [];
openInfo = [];
runSource = [];
imported = [];
try
    evalc('targets = st_load_targets(cfg.OnlyEnabled);');
catch ME
    [lines, report] = failure(lines, report, '대상 목록 읽기', ME);
    show(lines, report);
    return;
end
defectNames = cell(height(targets), 1);
for i = 1:height(targets)
    defectNames{i} = strings(0, 1);
    try
        evalc('sldvProfile = st_get_sldv_profile(targets(i,:), cfg);');
        defectNames{i} = reshape(string({sldvProfile.DefectIterations.Name}), [], 1);
    catch ME
        [lines, report] = failure(lines, report, ...
            sprintf('대상 %d SLDV profile 읽기', double(targets.No(i))), ME);
    end
end

standaloneSets = [];
saved = table();
if includeStandalone
    try
        if ~isempty(loaded), bdclose('all'); end
        evalc(['openInfo = st_open_standalone_test_manager(''ClearTestManager'', true, ' ...
            '''ImportResults'', true, ''ShowSavedCoverage'', true);']);
        saved = openInfo.SavedCoverage;
        if strcmp(openInfo.ResultStatus, 'IMPORTED')
            standaloneSets = sltest.testmanager.getResultSets;
        end
        lines{end+1} = sprintf('standalone 결과 %s | 저장 Coverage 보고서 OK %d 실패 %d', ...
            openInfo.ResultStatus, sum(saved.Status == "OK"), sum(saved.Status ~= "OK"));
    catch ME
        [lines, report] = failure(lines, report, 'standalone 열기', ME);
    end
end

perCutSets = cell(height(targets), 1);
perCutStage = repmat("없음", height(targets), 1);
try
    evalc('runSource = st_final_document_run_source(cfg, ''PER_CUT'');');
    rows = runSource.ResultSets;
    for i = 1:height(targets)
        hit = find(rows.TestCaseName == string(targets.TestCaseName(i)), 1);
        if isempty(hit), continue; end
        if ~isfile(rows.File(hit))
            perCutStage(i) = rows.Stage(hit) + " 파일 없음";
            continue;
        end
        try
            evalc('imported = sltest.testmanager.importResults(char(rows.File(hit)));');
            perCutSets{i} = imported;
            perCutStage(i) = rows.Stage(hit);
        catch ME
            perCutStage(i) = rows.Stage(hit) + " 가져오기 실패 " + id_of(ME);
            report = report + sprintf("[대상 %d 1단계 가져오기]\n%s\n\n", ...
                double(targets.No(i)), getReport(ME, 'extended', 'hyperlinks', 'off'));
        end
    end
    lines{end+1} = sprintf('1단계 결과 가져옴 %d / 대상 %d', ...
        sum(~cellfun(@isempty, perCutSets)), height(targets));
catch ME
    [lines, report] = failure(lines, report, '1단계 결과 찾기', ME);
end

totals = zeros(1, 2);
for i = 1:height(targets)
    no = double(targets.No(i));
    caseName = string(targets.TestCaseName(i));
    names = defectNames{i};
    coverageText = '저장 Coverage 없음';
    savedRow = [];
    if height(saved) > 0, savedRow = find(saved.TestCaseName == caseName, 1); end
    if ~isempty(savedRow) && saved.Status(savedRow) == "OK"
        coverageText = sprintf('CUT 결정 %d/%d 실행 %d/%d', ...
            saved.DecisionCovered(savedRow), saved.DecisionTotal(savedRow), ...
            saved.ExecutionCovered(savedRow), saved.ExecutionTotal(savedRow));
    elseif ~isempty(savedRow)
        coverageText = sprintf('저장 Coverage 실패 %s', saved.ErrorId(savedRow));
    end
    if includeStandalone
        % One line per target and run, so a model with many targets still fits one screen.
        [kinds, details, caseText] = read_defects(standaloneSets, caseName, names);
        totals(1) = totals(1) + sum(kinds == "verify 실패");
        lines{end+1} = sprintf('대상 %d | standalone %s | %s | 결함 %d: %s', no, caseText, coverageText, ...
            numel(names), kind_summary(kinds, details, ~isempty(standaloneSets))); %#ok<AGROW>
    end
    [kinds, details, caseText] = read_defects(perCutSets{i}, caseName, names);
    totals(2) = totals(2) + sum(kinds == "verify 실패");
    lines{end+1} = sprintf('대상 %d | 1단계 %s | %s | 결함 %d: %s', no, perCutStage(i), ...
        caseText, numel(names), kind_summary(kinds, details, ~isempty(perCutSets{i}))); %#ok<AGROW>
end
lines{end+1} = sprintf('합계 | 결함 TC %d | verify 실패 standalone %d, 1단계 %d', ...
    sum(cellfun(@numel, defectNames)), totals);
if includeStandalone
    lines{end+1} = '눈으로 볼 것: 열린 보고서의 Filter 항목, standalone 모델 색 표시와 하위 Subsystem 빠짐';
end
st_log(cfg, 'INFO', 'Defect criteria check complete | targets %d | verify failures %d/%d', ...
    height(targets), totals);
show(lines, report);
end


function [kinds, details, caseText] = read_defects(resultSets, caseName, names)
%READ_DEFECTS One kind per defect iteration name; "못 찾음" when absent.
% caseText counts every iteration of the Test Case by outcome.
kinds = repmat("못 찾음", numel(names), 1);
details = strings(numel(names), 1);
caseText = 'Iteration 없음';
if isempty(resultSets), return; end
caseResults = st_collect_test_case_results(resultSets);
for c = 1:numel(caseResults)
    if string(caseResults{c}.Name) ~= caseName, continue; end
    iterations = getIterationResults(caseResults{c});
    outcomes = strings(numel(iterations), 1);
    for k = 1:numel(iterations), outcomes(k) = string(iterations(k).Outcome); end
    caseText = sprintf('Iteration %d 통과 %d 실패 %d', numel(iterations), ...
        sum(outcomes == "Passed"), sum(outcomes == "Failed"));
    for k = 1:numel(iterations)
        hit = find(names == st_result_iteration_name(iterations(k), k), 1);
        if isempty(hit), continue; end
        try
            [kinds(hit), details(hit)] = st_defect_criteria_kind( ...
                getCustomCriteriaResult(iterations(k)));
        catch ME
            kinds(hit) = "읽기 실패";
            details(hit) = id_of(ME);
        end
    end
end
end


function text = kind_summary(kinds, details, haveResult)
if ~haveResult
    text = '결과 없음';
    return;
end
if isempty(kinds)
    text = '결함 Iteration 없음';
    return;
end
summary = sprintf("verify 실패 %d | 오류 %d", sum(kinds == "verify 실패"), sum(kinds == "오류"));
others = kinds(~ismember(kinds, ["verify 실패", "오류"]));
if ~isempty(others)
    names = unique(others).';
    counts = arrayfun(@(x) sum(others == x), names);
    % Not compose: with row vectors it fills one row's values in turn, a name into %d.
    summary = summary + " | " + strjoin(names + " " + counts, ", ");
end
notes = unique(details(strlength(details) > 0)).';
if ~isempty(notes)
    summary = summary + " | 식별자·이벤트 " + strjoin(notes, ", ");
end
text = char(summary);
end


function [lines, report] = failure(lines, report, stage, ME)
lines{end+1} = sprintf('%s 실패 | %s', stage, id_of(ME));
report = report + sprintf("[%s]\n%s\n\n", stage, getReport(ME, 'extended', 'hyperlinks', 'off'));
end


function show(lines, report)
clc;
if strlength(report) > 0
    % Appended: a caller may have written its own part first.
    fid = fopen(fullfile(tempdir, 'st_todo_check.txt'), 'a');
    if fid >= 0
        fprintf(fid, '%s', report);
        fclose(fid);
    end
    lines{end+1} = '오류 전문: st_todo_check.txt (임시 폴더)';
end
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
if numel(lines) > 38, fprintf('%d줄 더 있음\n', numel(lines) - 38); end
end


function text = id_of(ME)
% The identifier, then where it broke in toolkit names (st_error_place).
text = string(ME.identifier);
if strlength(text) == 0, text = "(식별자 없음)"; end
place = string(st_error_place(ME));
if strlength(place) > 0, text = text + " | " + place; end
end
