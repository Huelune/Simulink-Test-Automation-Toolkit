function st_probe_defect_criteria_results()
%ST_PROBE_DEFECT_CRITERIA_RESULTS Why a defect iteration's Custom Criteria result cannot be read.
%
% getCustomCriteriaResult(iterationResult) raised MATLAB:unassignedOutputs
% for every defect iteration of the saved PER_CUT results. This tries every
% way in one run, per target, without running anything:
%   - the Test Case in the Test File: Custom Criteria enabled, and whether
%     its callback is the toolkit's defect criteria (marker line)
%   - the defect iterations of the saved PER_CUT result (FINAL, else
%     INITIAL): outcome, and their verify results counted by result
%   - getCustomCriteriaResult on a defect iteration, on an ordinary
%     iteration and on the Test Case result
%   - the iteration result's property and method names that mention
%     criteria (MathWorks API names)
% Three lines per target; counts, API names and error identifiers only.
clc;
warnState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warnState)); %#ok<NASGU>
lines = {sprintf('MATLAB %s | 결함 Custom Criteria 결과 읽는 길 찾기', version('-release'))};
cfg = st_config();
st_log(cfg, 'INFO', 'Defect criteria result probe start');
marker = '% simtest:unreachable-defect-criteria v1';
% Variables that evalc assigns are named first, or MATLAB may take them for functions.
targets = table();
sldvProfile = [];
runSource = [];
imported = [];
try
    evalc('targets = st_load_targets(cfg.OnlyEnabled);');
    evalc('runSource = st_final_document_run_source(cfg, ''PER_CUT'');');
    testFile = sltest.testmanager.TestFile(cfg.TestFile);
    suite = getTestSuiteByName(testFile, cfg.TestSuiteName);
catch ME
    lines{end+1} = sprintf('준비 실패 | %s', id_of(ME));
    show(lines);
    return;
end
rows = runSource.ResultSets;
for i = 1:height(targets)
    no = double(targets.No(i));
    caseName = string(targets.TestCaseName(i));
    names = strings(0, 1);
    try
        evalc('sldvProfile = st_get_sldv_profile(targets(i,:), cfg);');
        names = reshape(string({sldvProfile.DefectIterations.Name}), [], 1);
    catch ME
        lines{end+1} = sprintf('대상 %d | 프로필 실패 %s', no, id_of(ME)); %#ok<AGROW>
        continue;
    end
    criteriaText = '기준 읽기 실패';
    try
        criteria = getCustomCriteria(getTestCaseByName(suite, char(caseName)));
        criteriaText = sprintf('기준 켜짐 %s | 표지 %s', yes_no(logical(criteria.Enabled)), ...
            yes_no(startsWith(strtrim(char(criteria.Callback)), marker)));
    catch ME
        criteriaText = sprintf('기준 읽기 실패 %s', id_of(ME));
    end

    hit = find(rows.TestCaseName == caseName, 1);
    if isempty(hit) || ~isfile(rows.File(hit))
        lines{end+1} = sprintf('대상 %d | %s | 1단계 결과 파일 없음', no, criteriaText); %#ok<AGROW>
        continue;
    end
    try
        evalc('imported = sltest.testmanager.importResults(char(rows.File(hit)));');
        caseResults = st_collect_test_case_results(imported);
        caseResult = [];
        for c = 1:numel(caseResults)
            if string(caseResults{c}.Name) == caseName, caseResult = caseResults{c}; end
        end
        iterations = getIterationResults(caseResult);
    catch ME
        lines{end+1} = sprintf('대상 %d | %s | 결과 가져오기 실패 %s', no, criteriaText, id_of(ME)); %#ok<AGROW>
        continue;
    end
    iterationNames = strings(numel(iterations), 1);
    for k = 1:numel(iterations), iterationNames(k) = st_result_iteration_name(iterations(k), k); end
    defectIndex = find(ismember(iterationNames, names));
    ordinaryIndex = find(~ismember(iterationNames, names), 1);

    outcomes = strings(numel(defectIndex), 1);
    verifyCounts = zeros(1, 3);
    verifyText = '';
    for k = 1:numel(defectIndex)
        outcomes(k) = string(iterations(defectIndex(k)).Outcome);
        [counts, failure] = verify_counts(iterations(defectIndex(k)));
        verifyCounts = verifyCounts + counts;
        if ~isempty(failure), verifyText = [' 읽기 실패 ' failure]; end
    end
    lines{end+1} = sprintf('대상 %d | %s | %s %d개 Failed %d | 그 verify 실패 %d 통과 %d 미판정 %d%s', ...
        no, stage_of(rows, hit), criteriaText, numel(defectIndex), sum(outcomes == "Failed"), ...
        verifyCounts, verifyText); %#ok<AGROW>

    defectRead = '결함 Iteration 없음';
    if ~isempty(defectIndex), defectRead = criteria_read(@() getCustomCriteriaResult(iterations(defectIndex(1)))); end
    ordinaryRead = '보통 Iteration 없음';
    if ~isempty(ordinaryIndex), ordinaryRead = criteria_read(@() getCustomCriteriaResult(iterations(ordinaryIndex))); end
    caseRead = criteria_read(@() getCustomCriteriaResult(caseResult));
    lines{end+1} = sprintf('대상 %d | 기준 결과 Iteration: 결함 %s | 보통 %s', no, ...
        defectRead, ordinaryRead); %#ok<AGROW>
    lines{end+1} = sprintf('대상 %d | 기준 결과 Test Case: %s | criteria 이름 %s', no, ...
        caseRead, criteria_members(iterations(1))); %#ok<AGROW>
end
st_log(cfg, 'INFO', 'Defect criteria result probe complete | targets %d', height(targets));
show(lines);
end


function [counts, failure] = verify_counts(iteration)
%VERIFY_COUNTS [Fail Pass Untested] over every verify result of the iteration.
counts = zeros(1, 3);
failure = '';
try
    runs = getVerifyRuns(iteration);
    for r = 1:numel(runs)
        data = export(runs(r));
        if isempty(data), continue; end
        for e = 1:numElements(data)
            text = lower(char(string(data{e}.Result)));
            if endsWith(text, 'fail'), counts(1) = counts(1) + 1;
            elseif endsWith(text, 'pass'), counts(2) = counts(2) + 1;
            else, counts(3) = counts(3) + 1;
            end
        end
    end
catch ME
    failure = id_of(ME);
end
end


function text = criteria_read(reader)
%CRITERIA_READ What one getCustomCriteriaResult call gave back.
try
    result = reader();
catch ME
    text = ['오류 ' id_of(ME)];
    return;
end
if isempty(result)
    text = sprintf('빈 값(%s)', class(result));
    return;
end
outcome = "";
try, outcome = string(result(1).Outcome); catch, end
kind = "종류 읽기 실패";
detail = "";
try, [kind, detail] = st_defect_criteria_kind(result(1)); catch, end
className = class(result);
className = className(find(className == '.', 1, 'last') + 1:end);
text = sprintf('%d개 %s 판정 %s %s', numel(result), className, outcome, kind);
if strlength(detail) > 0, text = sprintf('%s(%s)', text, detail); end
end


function text = criteria_members(iteration)
%CRITERIA_MEMBERS Property and method names of the iteration result that mention criteria.
names = [reshape(string(properties(iteration)), 1, []), reshape(string(methods(iteration)), 1, [])];
names = unique(names(contains(lower(names), 'criteria')));
text = '없음';
if ~isempty(names), text = char(strjoin(names, ',')); end
end


function text = stage_of(rows, hit)
text = char(rows.Stage(hit));
end


function show(lines)
clc;
for k = 1:min(38, numel(lines)), fprintf('%s\n', lines{k}); end
if numel(lines) > 38, fprintf('%d줄 더 있음\n', numel(lines) - 38); end
end


function text = yes_no(flag)
text = '아니오';
if flag, text = '예'; end
end


function text = id_of(ME)
text = ME.identifier;
if isempty(text), text = '(식별자 없음)'; end
end
