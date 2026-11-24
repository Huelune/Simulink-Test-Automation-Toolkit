function tests = test_probe_sldv_objectives
%TEST_PROBE_SLDV_OBJECTIVES Name-free counts and field names of SLDV data.
tests = functiontests(localfunctions);
end

function testCountsAndFieldNamesOnlyWithoutNames(testCase)
% Three decision objectives (one of each status the defect TC cares about)
% and one condition objective that must not be counted. Every name in the
% file carries "Secret"; the screen leaves the company, so none may print.
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
file = fullfile(folder, 'Secret_sldvdata.mat');
sldvData = struct();
sldvData.ModelInformation = struct('Name', 'Secret_Model', ...
    'SubsystemPath', 'Secret_Model/Secret_CUT');
sldvData.ModelObjects = struct('descr', 'Secret_Switch', ...
    'slPath', 'Secret_Model/Secret_CUT/Secret_Switch');
sldvData.Objectives = struct( ...
    'type', {'Decision', 'Decision', 'Decision', 'Condition'}, ...
    'status', {'Unsatisfiable', 'Unsatisfiable under approximation', ...
        'Undecided', 'Satisfied'}, ...
    'descr', {'Secret_Switch false', 'Secret_Switch true', ...
        'Secret_Switch false', 'Secret_Switch input'}, ...
    'modelObjectIdx', {1, 1, 1, 1});
save(file, 'sldvData');

% Declared first: a name only evalc assigns would bind to a function.
probeLines = {};
printed = evalc('probeLines = st_probe_sldv_objectives({file});');
joined = strjoin(probeLines, newline);
% The screen itself must carry the counts, or the Secret check below would
% pass on an empty screen.
verifyTrue(testCase, contains(printed, 'Unsatisfiable 1'));
verifyTrue(testCase, contains(joined, 'Unsatisfiable 1'));
verifyTrue(testCase, contains(joined, '근사 1'));
verifyTrue(testCase, contains(joined, 'Undecided 1'));
verifyTrue(testCase, contains(joined, '결정 목표 3'));
verifyTrue(testCase, contains(joined, '기타 0'));
fieldLine = probeLines(startsWith(probeLines, 'Objectives 필드:'));
verifyNotEmpty(testCase, fieldLine);
verifyTrue(testCase, contains(fieldLine{1}, 'status'));
% The CUT name comes from SubsystemPath when no target row gives it.
verifyTrue(testCase, contains(joined, '첫 요소=분석 모델 예(1/1)'));
verifyTrue(testCase, contains(joined, '둘째 요소=CUT 예(1/1)'));
verifyFalse(testCase, contains(printed, 'Secret'));
end

function testOtherStatusesAreNamed(testCase)
% A decision status outside the known groups is counted under 기타 with
% its MathWorks status text, once per distinct value.
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
file = fullfile(folder, 'Secret_sldvdata.mat');
sldvData = struct();
sldvData.ModelInformation = struct('Name', 'Secret_Model', ...
    'SubsystemPath', 'Secret_Model/Secret_CUT');
sldvData.ModelObjects = struct('slPath', 'Secret_Model/Secret_CUT/Secret_Switch');
sldvData.Objectives = struct('type', {'Decision', 'Decision', 'Decision'}, ...
    'status', {'Excluded', 'Excluded', 'Satisfied'}, 'modelObjectIdx', {1, 1, 1});
save(file, 'sldvData');

probeLines = {};
printed = evalc('probeLines = st_probe_sldv_objectives({file});');
verifyTrue(testCase, contains(strjoin(probeLines, newline), ...
    'Satisfied 1 | Unsatisfiable 0 | 근사 0 | Undecided 0 | 기타 2 (Excluded)'));
verifyFalse(testCase, contains(printed, 'Secret'));
end
