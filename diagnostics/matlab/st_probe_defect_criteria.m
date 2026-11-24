function st_probe_defect_criteria()
%ST_PROBE_DEFECT_CRITERIA Can a Custom Criteria read its iteration's coverage?
%
%   st_probe_defect_criteria
%
% The unreachable-outcome defect TC fails because a Custom Criteria reads
% the decision coverage of its own iteration and verifies that the outcome
% SLDV proved unreachable ran at least once. Whether that coverage is
% attached when the criteria runs is not documented, so this builds a
% throwaway case and looks. No company model is used.
%
% In a short temporary folder: a model whose Subsystem holds one Switch
% with the constant 1 on its control input, so the false outcome can never
% run; a harness on that Subsystem; a Test File whose Test Case records
% Decision coverage and has one iteration; and a Custom Criteria that
% records what it can reach in tempdir/st_probe_defect_criteria.mat and then
% only calls verifyGreaterThan(false count, 0). After the run the Test File
% is saved, closed, reopened and run again. Six lines, no names or paths:
%
%   [1] Iteration 결과 객체 예 | test.<property> | <class>
%   [2] 커버리지 있음 | 얻은 경로 <candidate>
%   [3] false 결과 실행 횟수 0 | decisioninfo sltest_sut 예, 원래 모델 예, sltest_bdroot 예 | sltest_sut=<kind>
%   [4] Iteration 판정 Failed | 실행 뒤 커버리지 있음 | false 횟수 0
%   [5] 다시 연 뒤 콜백 남음 예 | 다시 실행 판정 Failed
%   [6] test 속성: <public property names of the criteria's test object>
%
% Coverage candidates, tried in this order: getCoverageResults on the
% result object, the cvdata variables in test.sltest_simout, any property
% of test that holds cvdata. decisioninfo is asked for the Switch through
% test.sltest_sut, the original model and test.sltest_bdroot, each answer
% reported. [4] also reads the iteration's coverage after the run the way
% the toolkit does: coverage there but not in [2] is a platform limit,
% coverage missing in both is this probe's setup. A step that fails prints
% 아니오 and the error identifier only. What the probe created (model,
% harness, Test File, folder, MAT) is closed and removed at the end; other
% Test Files are left alone.

cfg = [];
try, cfg = st_config(); catch, end
if isstruct(cfg)
    % DEBUG lines carry paths, and this screen leaves the company.
    cfg.ConsoleLogLevel = 'STEP';
end
log_line(cfg, 'INFO', 'Defect criteria probe start');
model = 'st_probe_defect_model';
harness = 'st_probe_defect_harness';
owner = [model '/Unit'];
suiteName = 'Probe';
caseName = 'Probe';
marker = '% simtest:unreachable-defect-criteria v1';
probeFile = fullfile(tempdir, 'st_probe_defect_criteria.mat');

stage = 'build folder';
try
    % evalc: the short build folder logs its path on failure, never on screen.
    buildCleanup = [];
    evalc('buildCleanup = st_enter_short_build_directory(cfg, ''PROBE'');');
    cleanup = onCleanup(@() remove_probe(model, owner, harness, probeFile, ...
        buildCleanup, cfg)); %#ok<NASGU>
    testFilePath = fullfile(pwd, 'st_probe_defect.mldatx');
    stage = 'model';
    build_model(model, owner);
    stage = 'harness';
    st_call_quiet(cfg, 'sltest.harness.create', ...
        @() sltest.harness.create(owner, 'Name', harness));
    save_system(model);
    stage = 'test file';
    [tf, tc] = build_test_case(testFilePath, suiteName, caseName, model, owner, harness);
    stage = 'custom criteria';
    criteria = getCustomCriteria(tc);
    criteria.Callback = callback_text(marker, owner);
    criteria.Enabled = true;
catch setupError
    log_line(cfg, 'WARN', 'Defect criteria probe setup failed | Stage=%s | Id=%s', ...
        stage, id_text(setupError));
    fprintf('[0] 준비 아니오 | 단계 %s | 식별자 %s\n', stage, id_text(setupError));
    return;
end
log_line(cfg, 'INFO', 'Defect criteria probe setup done');

if isfile(probeFile), delete(probeFile); end
[outcome, iteration] = run_outcome(cfg, tc, 'run(testCase)');
probe = [];
try
    loaded = load(probeFile, 'probe');
    probe = loaded.probe;
catch
    % No file means the criteria never reached its save; the lines say so.
end
lines = describe_probe(probe, owner, harness);
lines{4} = sprintf('[4] Iteration 판정 %s | %s', outcome, ...
    after_run_coverage(iteration, [owner '/Choose']));

try
    saveToFile(tf);
    close(tf);
    tf = sltest.testmanager.TestFile(testFilePath, false);
    tc = getTestCaseByName(getTestSuiteByName(tf, suiteName), caseName);
    criteria = getCustomCriteria(tc);
    kept = logical(criteria.Enabled) && startsWith(strtrim(char(criteria.Callback)), marker);
    lines{5} = sprintf('[5] 다시 연 뒤 콜백 남음 %s | 다시 실행 판정 %s', yes_no(kept), ...
        run_outcome(cfg, tc, 'run(testCase) after reopen'));
catch reopenError
    lines{5} = sprintf('[5] 다시 연 뒤 아니오 | 식별자 %s', id_text(reopenError));
    log_line(cfg, 'WARN', 'Defect criteria probe reopen failed | Id=%s', id_text(reopenError));
end

for k = 1:numel(lines)
    fprintf('%s\n', lines{k});
end
log_line(cfg, 'INFO', 'Defect criteria probe end | Outcome=%s | CoverageSource=%d', ...
    outcome, coverage_source(probe));
end


function build_model(model, owner)
%BUILD_MODEL Subsystem whose Switch false outcome can never run.
if bdIsLoaded(model), close_system(model, 0); end
new_system(model);
set_param(model, 'StopTime', '1', 'BlockReduction', 'off');
add_block('simulink/Ports & Subsystems/Subsystem', owner);
delete_line(owner, 'In1/1', 'Out1/1');
add_block('simulink/Sources/Constant', [owner '/Control'], 'Value', '1');
add_block('simulink/Signal Routing/Switch', [owner '/Choose'], ...
    'Criteria', 'u2 >= Threshold', 'Threshold', '1');
add_line(owner, 'In1/1', 'Choose/1');
add_line(owner, 'Control/1', 'Choose/2');
add_line(owner, 'In1/1', 'Choose/3');
add_line(owner, 'Choose/1', 'Out1/1');
add_block('simulink/Sources/Constant', [model '/Source'], 'Value', '0');
add_block('simulink/Sinks/Terminator', [model '/Sink']);
add_line(model, 'Source/1', 'Unit/1');
add_line(model, 'Unit/1', 'Sink/1');
save_system(model, fullfile(pwd, [model '.slx']));
end


function [tf, tc] = build_test_case(testFilePath, suiteName, caseName, model, owner, harness)
tf = sltest.testmanager.TestFile(testFilePath, true);
coverage = getCoverageSettings(tf);
coverage.RecordCoverage = true;
coverage.MetricSettings = 'd';
ts = createTestSuite(tf, suiteName);
coverage = getCoverageSettings(ts);
coverage.RecordCoverage = true;
tc = createTestCase(ts, 'simulation', caseName);
setProperty(tc, 'Model', model, 'HarnessOwner', owner, 'HarnessName', harness);
coverage = getCoverageSettings(tc);
coverage.RecordCoverage = true;
addIteration(tc, sltest.testmanager.TestIteration, 'Iteration 1');
end


function text = callback_text(marker, owner)
%CALLBACK_TEXT The Custom Criteria script. Test Manager runs it with only
% `test` defined, so it calls no toolkit function, and it stays ASCII.
% It saves once right after the property names, so a criteria that dies
% later still leaves them (Stage stays 'properties'), and again at the end.
% decisioninfo is asked for the Switch through test.sltest_sut, the
% original model path (what harness coverage answers to elsewhere in the
% toolkit) and test.sltest_bdroot; every path's answer is kept.
code = [
    string(marker)
    "% Written by st_probe_defect_criteria: records what a Custom Criteria can reach."
    "probeFile = fullfile(tempdir, 'st_probe_defect_criteria.mat');"
    "probe = struct();"
    "probe.Stage = 'properties';"
    "probe.Properties = {};"
    "probe.PropertiesError = '';"
    "probe.ResultProperty = '';"
    "probe.ResultClass = '';"
    "probe.ResultError = '';"
    "probe.CoverageSource = 0;"
    "probe.CoverageErrors = {'-', '-', '-'};"
    "probe.Sut = '';"
    "probe.SutError = '';"
    "probe.Bdroot = '';"
    "probe.BdrootError = '';"
    "probe.PathResults = {'-', '-', '-'};"
    "probe.CountPath = 0;"
    "probe.CountError = '';"
    "probe.OutcomeCount = 0;"
    "probe.FalseCount = NaN;"
    "try"
    "    probe.Properties = properties(test);"
    "catch probeError"
    "    probe.PropertiesError = probeError.identifier;"
    "end"
    "save(probeFile, 'probe');"
    "probeResult = [];"
    "try"
    "    probeResult = test.TestResult;"
    "    probe.ResultProperty = 'TestResult';"
    "catch probeError"
    "    probe.ResultError = probeError.identifier;"
    "end"
    "for probeK = 1:numel(probe.Properties)"
    "    if ~isempty(probeResult), break; end"
    "    try"
    "        probeValue = test.(probe.Properties{probeK});"
    "        if startsWith(class(probeValue), 'sltest.testmanager.') && contains(class(probeValue), 'Result')"
    "            probeResult = probeValue;"
    "            probe.ResultProperty = probe.Properties{probeK};"
    "        end"
    "    catch"
    "    end"
    "end"
    "if ~isempty(probeResult)"
    "    probe.ResultClass = class(probeResult);"
    "end"
    "probeCvd = {};"
    "for probeC = 1:3"
    "    try"
    "        probeRaw = {};"
    "        if probeC == 1"
    "            if isempty(probeResult)"
    "                error('simtest:ProbeNoResult', 'No result object reached.');"
    "            end"
    "            probeRaw = {getCoverageResults(probeResult)};"
    "        elseif probeC == 2"
    "            probeSimout = test.sltest_simout;"
    "            probeNames = who(probeSimout);"
    "            for probeK = 1:numel(probeNames)"
    "                probeRaw{end+1} = get(probeSimout, probeNames{probeK});"
    "            end"
    "        else"
    "            for probeK = 1:numel(probe.Properties)"
    "                try"
    "                    probeRaw{end+1} = test.(probe.Properties{probeK});"
    "                catch"
    "                end"
    "            end"
    "        end"
    "        probeList = {};"
    "        while ~isempty(probeRaw)"
    "            probeValue = probeRaw{1};"
    "            probeRaw(1) = [];"
    "            if iscell(probeValue)"
    "                probeRaw = [probeRaw, reshape(probeValue, 1, [])];"
    "            elseif isa(probeValue, 'cv.cvdatagroup')"
    "                probeRaw{end+1} = getAll(probeValue);"
    "            elseif isa(probeValue, 'cvdata')"
    "                for probeK = 1:numel(probeValue)"
    "                    probeList{end+1} = probeValue(probeK);"
    "                end"
    "            end"
    "        end"
    "    catch probeError"
    "        probe.CoverageErrors{probeC} = probeError.identifier;"
    "        if isempty(probe.CoverageErrors{probeC}), probe.CoverageErrors{probeC} = 'no-identifier'; end"
    "        continue;"
    "    end"
    "    if ~isempty(probeList)"
    "        probeCvd = probeList;"
    "        probe.CoverageSource = probeC;"
    "        break;"
    "    end"
    "    probe.CoverageErrors{probeC} = 'empty';"
    "end"
    "try"
    "    probe.Sut = char(test.sltest_sut);"
    "catch probeError"
    "    probe.SutError = probeError.identifier;"
    "    if isempty(probe.SutError), probe.SutError = 'no-identifier'; end"
    "end"
    "try"
    "    probe.Bdroot = char(test.sltest_bdroot);"
    "catch probeError"
    "    probe.BdrootError = probeError.identifier;"
    "    if isempty(probe.BdrootError), probe.BdrootError = 'no-identifier'; end"
    "end"
    "probePaths = {'', '" + string(owner) + "/Choose', ''};"
    "if ~isempty(probe.Sut), probePaths{1} = [probe.Sut '/Choose']; end"
    "if ~isempty(probe.Bdroot), probePaths{3} = [probe.Bdroot '/" + string(extractAfter(owner, '/')) + "/Choose']; end"
    "probeInfo = [];"
    "for probeP = 1:3"
    "    if isempty(probePaths{probeP}) || isempty(probeCvd), continue; end"
    "    probe.PathResults{probeP} = 'empty';"
    "    for probeK = 1:numel(probeCvd)"
    "        try"
    "            [probeValues, probeFound] = decisioninfo(probeCvd{probeK}, probePaths{probeP});"
    "            if ~isempty(probeValues)"
    "                probe.PathResults{probeP} = 'ok';"
    "                if isempty(probeInfo)"
    "                    probeInfo = probeFound;"
    "                    probe.CountPath = probeP;"
    "                end"
    "                break;"
    "            end"
    "        catch probeError"
    "            probe.PathResults{probeP} = probeError.identifier;"
    "            if isempty(probe.PathResults{probeP}), probe.PathResults{probeP} = 'no-identifier'; end"
    "        end"
    "    end"
    "end"
    "if ~isempty(probeInfo)"
    "    try"
    "        probeOutcomes = probeInfo.decision(1).outcome;"
    "        probe.OutcomeCount = numel(probeOutcomes);"
    "        probe.CountError = 'no-false-outcome';"
    "        for probeK = 1:numel(probeOutcomes)"
    "            if startsWith(lower(strtrim(char(probeOutcomes(probeK).text))), 'false')"
    "                probe.FalseCount = double(probeOutcomes(probeK).executionCount);"
    "                probe.CountError = '';"
    "            end"
    "        end"
    "    catch probeError"
    "        probe.CountError = probeError.identifier;"
    "        if isempty(probe.CountError), probe.CountError = 'no-identifier'; end"
    "    end"
    "end"
    "probe.Stage = 'done';"
    "save(probeFile, 'probe');"
    "if isnan(probe.FalseCount)"
    "    error('simtest:ProbeCoverageUnreadable', 'The criteria could not read the false outcome count.');"
    "end"
    "test.verifyGreaterThan(probe.FalseCount, 0, 'Switch [false] execution count');"
    ];
text = strjoin(cellstr(code).', newline);
end


function [text, iteration] = run_outcome(cfg, tc, label)
%RUN_OUTCOME Outcome of the Test Case's only iteration, or why there is none.
% Every run leaves a result set in Test Manager. There is no documented API
% that removes one result set, and clearResults would also take the user's
% own results, so they stay.
iteration = [];
try
    resultSet = st_call_quiet(cfg, label, @() run(tc));
    caseResults = st_collect_test_case_results(resultSet);
    iterations = getIterationResults(caseResults{1});
    iteration = iterations(1);
    text = char(string(iteration.Outcome));
    log_line(cfg, 'INFO', 'Defect criteria probe run | Label=%s | Outcome=%s', label, text);
catch runError
    text = ['아니오 | 식별자 ' id_text(runError)];
    log_line(cfg, 'WARN', 'Defect criteria probe run failed | Label=%s | Id=%s', ...
        label, id_text(runError));
end
end


function text = after_run_coverage(iteration, switchPath)
%AFTER_RUN_COVERAGE The control for [2]: the iteration's own coverage read
% after the run the way st_collect_decision_outcomes reads it.
if isempty(iteration)
    text = '실행 뒤 커버리지 확인 못 함';
    return;
end
try
    objects = st_flatten_coverage_results(getCoverageResults(iteration));
catch coverageError
    text = ['실행 뒤 커버리지 없음(' id_text(coverageError) ')'];
    return;
end
if isempty(objects)
    text = '실행 뒤 커버리지 없음(비어 있음)';
    return;
end
reason = '비어 있음';
for k = 1:numel(objects)
    try
        [values, description] = decisioninfo(objects{k}, switchPath);
    catch lookupError
        reason = id_text(lookupError);
        continue;
    end
    if isempty(values), continue; end
    counts = st_decision_outcome_counts(description);
    if isempty(counts)
        text = '실행 뒤 커버리지 있음 | false 횟수 아니오(true/false 결과 아님)';
    else
        text = sprintf('실행 뒤 커버리지 있음 | false 횟수 %d', counts(1, 2));
    end
    return;
end
text = ['실행 뒤 커버리지 있음 | false 횟수 아니오(decisioninfo ' reason ')'];
end


function lines = describe_probe(probe, owner, harness)
%DESCRIBE_PROBE Lines [1] [2] [3] [6] from what the criteria recorded.
lines = cell(1, 6);
if isempty(probe)
    lines{1} = '[1] Iteration 결과 객체 아니오 | 콜백 기록 없음';
    lines{2} = '[2] 커버리지 없음 | 콜백 기록 없음';
    lines{3} = '[3] false 결과 실행 횟수 아니오 | 콜백 기록 없음';
    lines{6} = '[6] test 속성 아니오 | 콜백 기록 없음';
    return;
end
% Saved only by the early save: the criteria stopped after the names.
stopped = '';
if ~strcmp(probe.Stage, 'done'), stopped = ' | 콜백이 속성 기록 뒤 멈춤'; end

if startsWith(probe.ResultClass, 'sltest.testmanager.')
    lines{1} = sprintf('[1] Iteration 결과 객체 예 | test.%s | %s', ...
        probe.ResultProperty, probe.ResultClass);
elseif ~isempty(probe.ResultClass)
    lines{1} = sprintf('[1] Iteration 결과 객체 아니오 | test.%s | %s', ...
        probe.ResultProperty, probe.ResultClass);
else
    lines{1} = sprintf('[1] Iteration 결과 객체 아니오 | test.TestResult 식별자 %s%s', ...
        none_text(probe.ResultError), stopped);
end

labels = {'getCoverageResults', 'sltest_simout', 'cvdata 속성'};
if probe.CoverageSource > 0
    lines{2} = ['[2] 커버리지 있음 | 얻은 경로 ' labels{probe.CoverageSource}];
else
    lines{2} = ['[2] 커버리지 없음' stopped];
end
for c = 1:numel(labels)
    if strcmp(probe.CoverageErrors{c}, '-'), continue; end
    lines{2} = sprintf('%s | %s: %s', lines{2}, labels{c}, reason_text(probe.CoverageErrors{c}));
end

if strcmp(probe.Sut, owner)
    kind = '원래 모델 Subsystem';
elseif startsWith(probe.Sut, harness)
    kind = '하네스';
elseif isempty(probe.Sut)
    kind = '모름';
else
    kind = '기타';
end
haveCoverage = probe.CoverageSource > 0;
paths = sprintf('sltest_sut %s, 원래 모델 %s, sltest_bdroot %s', ...
    path_text(probe.PathResults{1}, probe.SutError, haveCoverage), ...
    path_text(probe.PathResults{2}, '', haveCoverage), ...
    path_text(probe.PathResults{3}, probe.BdrootError, haveCoverage));
if ~isnan(probe.FalseCount)
    count = sprintf('%d', probe.FalseCount);
elseif strcmp(probe.CountError, 'no-false-outcome')
    count = sprintf('아니오(false 결과 없음, 결과 %d개)', probe.OutcomeCount);
elseif ~isempty(probe.CountError)
    count = ['아니오(' reason_text(probe.CountError) ')'];
else
    count = ['아니오(decisioninfo 답 없음)' stopped];
end
lines{3} = sprintf('[3] false 결과 실행 횟수 %s | decisioninfo %s | sltest_sut=%s', ...
    count, paths, kind);

if isempty(probe.Properties)
    lines{6} = ['[6] test 속성 아니오 | 식별자 ' none_text(probe.PropertiesError)];
else
    lines{6} = ['[6] test 속성: ' strjoin(reshape(probe.Properties, 1, []), ', ')];
end
end


function text = path_text(result, readError, haveCoverage)
%PATH_TEXT One decisioninfo path as the criteria recorded it.
if ~isempty(readError)
    text = ['읽기 실패(' reason_text(readError) ')'];
elseif strcmp(result, 'ok')
    text = '예';
elseif ~strcmp(result, '-')
    text = ['아니오(' reason_text(result) ')'];
elseif haveCoverage
    text = '값 비어 있음';
else
    text = '시도 못 함';
end
end


function text = reason_text(reason)
switch reason
    case 'empty', text = '비어 있음';
    case 'no-identifier', text = '식별자 없음';
    otherwise, text = reason;
end
end


function remove_probe(model, owner, harness, probeFile, buildCleanup, cfg)
%REMOVE_PROBE Close and delete only what the probe created.
try
    openFiles = sltest.testmanager.getTestFiles;
    for k = 1:numel(openFiles)
        % By name: FilePath can spell a tempdir 8.3 short path in full.
        [~, name, ext] = fileparts(openFiles(k).FilePath);
        if strcmpi([name ext], 'st_probe_defect.mldatx'), close(openFiles(k)); end
    end
catch
end
try, sltest.harness.close(owner, harness); catch, end
try, close_system(model, 0); catch, end
try, if isfile(probeFile), delete(probeFile); end, catch, end
% Back to the caller's folder and cache folders; the probe folder is removed.
evalc('delete(buildCleanup)');
log_line(cfg, 'INFO', 'Defect criteria probe cleanup done');
end


function value = coverage_source(probe)
value = 0;
if isstruct(probe), value = probe.CoverageSource; end
end


function text = yes_no(flag)
text = '아니오';
if flag, text = '예'; end
end


function text = none_text(identifier)
text = identifier;
if isempty(text), text = '없음'; end
end


function text = id_text(err)
text = none_text(err.identifier);
end


function log_line(cfg, level, varargin)
if isempty(cfg), return; end
try, st_log(cfg, level, varargin{:}); catch, end
end
