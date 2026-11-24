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

printed = evalc('lines = st_probe_sldv_objectives({file});');
text = strjoin(lines, newline);
verifyTrue(testCase, contains(text, 'Unsatisfiable 1'));
verifyTrue(testCase, contains(text, '근사 1'));
verifyTrue(testCase, contains(text, 'Undecided 1'));
verifyTrue(testCase, contains(text, '결정 목표 3'));
fieldLine = lines(startsWith(lines, 'Objectives 필드:'));
verifyNotEmpty(testCase, fieldLine);
verifyTrue(testCase, contains(fieldLine{1}, 'status'));
% The CUT name comes from SubsystemPath when no target row gives it.
verifyTrue(testCase, contains(text, '첫 요소=분석 모델 예(1/1)'));
verifyTrue(testCase, contains(text, '둘째 요소=CUT 예(1/1)'));
verifyFalse(testCase, contains(printed, 'Secret'));
end
