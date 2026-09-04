function tests = test_specification_verify_modes
%TEST_SPECIFICATION_VERIFY_MODES No MATLAB model or simulation is required.
tests = functiontests(localfunctions);
end

function testStep2IsReadFirstAndDoesNotUseStep1OrActiveStep(testCase)
[reader, calls] = fixture_reader(["S.step1"; "S.step2"], ...
    {step_info(1, 'verify(A == 11);'), step_info(2, 'verify(A == 22);')});
[cells, details, notes] = read_fixture(reader, 'STEP2');
verifyEqual(testCase, cells, "A: 22");
verifyEqual(testCase, calls('paths'), ["S.step2"; "S.step1"]);
verifyEqual(testCase, details(:,8), ["A: 11"; "A: 22"]);
verifyEqual(testCase, notes, "");
% Reader deliberately provides no active-step/scenario API or activation API.
end

function testAllStepsFollowIndexAndKeepNestedPaths(testCase)
paths = ["S.step3.child"; "S.step2"; "S.step10"; "S.step3"];
[reader, ~] = fixture_reader(paths, {step_info(1, 'verify(A == 33);'), ...
    step_info(2, 'verify(A == 22);'), step_info(1, 'verify(A == 11);'), step_info(3, '')});
[cells, details, notes] = read_fixture(reader, 'ALL_STEPS_COLUMNS');
verifyEqual(testCase, cells, ["[step10]" + newline + "A: 11", ...
    "[step2]" + newline + "A: 22", "[step3.child]" + newline + "A: 33"]);
verifyEqual(testCase, details(:,5), ["S.step10"; "S.step2"; "S.step3"; "S.step3.child"]);
verifyEqual(testCase, notes, "");
end

function testMissingDirectStep2DoesNotFallBackToNestedStep2(testCase)
[reader, ~] = fixture_reader(["S.step1"; "S.parent"; "S.parent.step2"], ...
    {step_info(1, 'verify(A == 11);'), step_info(2, ''), step_info(1, 'verify(A == 99);')});
[cells, details, notes] = read_fixture(reader, 'STEP2');
verifyEqual(testCase, cells, "step2 없음");
verifyTrue(testCase, contains(notes, 'Direct step2 missing'));
verifyTrue(testCase, any(details(:,8) == "A: 99"));
end

function testEmptyStep2DoesNotUseAnotherStep(testCase)
[reader, ~] = fixture_reader(["S.step1"; "S.step2"], ...
    {step_info(1, 'verify(A == 11);'), step_info(2, '% no verification')});
[cells, ~, notes] = read_fixture(reader, 'STEP2');
verifyEqual(testCase, cells, "verify 없음");
verifyTrue(testCase, contains(notes, 'No verify in direct step2'));
end

function testStep1FailureCannotDiscardStep2(testCase)
[reader, ~] = fixture_reader(["S.step1"; "S.step2"], ...
    {MException('fixture:ReadFailed', 'Cannot read step1'), step_info(2, 'verify(A(1).BB == 7);')});
[cells, details, notes] = read_fixture(reader, 'STEP2');
verifyEqual(testCase, cells, "A(1).BB: 7");
verifyTrue(testCase, any(details(:,9) == "FAIL"));
verifyTrue(testCase, contains(notes, 'Cannot read step1'));
[cells, ~, ~] = read_fixture(reader, 'ALL_STEPS_COLUMNS');
verifyEqual(testCase, cells, "[step2]" + newline + "A(1).BB: 7");
end

function testTransitionFailurePreservesOriginalActionAndSummary(testCase)
info = step_info(2, 'verify(A == 22);');
info.TransitionCount = 1;
[reader, ~] = fixture_reader("S.step2", {info});
[cells, details, notes] = read_fixture(reader, 'STEP2');
verifyEqual(testCase, cells, "A: 22");
verifyEqual(testCase, details(1,6), "verify(A == 22);");
verifyEqual(testCase, details(1,9), "WARN");
verifyTrue(testCase, contains(notes, 'Transition 1'));
end

function testFindStepFailureStillReturnsDirectStep2(testCase)
[reader, ~] = fixture_reader("S.step2", {step_info(2, 'verify(A == 22);')});
reader.FindSteps = @(block) fail_enumeration(block);
[cells, details, notes] = read_fixture(reader, 'STEP2');
verifyEqual(testCase, cells, "A: 22");
verifyEqual(testCase, details(1,5), "S.step2");
verifyTrue(testCase, contains(notes, 'Step enumeration failed'));
end

function testTablePadsDifferentScenarioCountsAndKeepsMetadata(testCase)
rows = strings(3,13);
rows(:,1) = ["Case1"; "Case2"; "Case2"];
rows(:,5) = ["Scenario1"; "Scenario2"; "Scenario2"];
rows(:,8:13) = repmat(["Top" "Top/CUT" "Iteration" "Input" "OK" "note"],3,1);
groups = {"[step2]" + newline + "A: 1"; ...
    ["[step1]" + newline + "A: 2", "[step2]" + newline + "A: 3"]; ...
    ["[step1]" + newline + "A: 2", "[step2]" + newline + "A: 3"]};
output = st_specification_table(rows, groups, [2;4;4]);
verifyEqual(testCase, height(output), 3);
verifyEqual(testCase, output.Properties.VariableNames(7:9), {'verify 내용','verify 내용 2','TopModel'});
verifyEqual(testCase, output{1,8}, "");
verifyEqual(testCase, output{2,7:8}, groups{2});
verifyEqual(testCase, output{3,7:8}, groups{3});
verifyEqual(testCase, output{:, [9:12 14:15]}, rows(:,8:13));
verifyEqual(testCase, output.MaxTime, [2;4;4]);
verifyEqual(testCase, output.Properties.VariableNames{13}, 'MaxTime');
singleStepTable = st_specification_table(rows, {"A: 1"; "A: 2"; "A: 3"});
verifyEqual(testCase, width(singleStepTable), 14);
verifyEqual(testCase, singleStepTable.Properties.VariableNames{8}, 'TopModel');
end

function testAdditionalVerifyColumnsWrapAndOverflow(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
rows = strings(1,13);
longText = "[step3]" + newline + strjoin(repmat("A: 1", 260, 1), newline);
groups = {["[step1]" + newline + "A: 0", "[step2]" + newline + "A: 1", longText]};
spec = st_specification_table(rows, groups, 7);
details = table("S.step3", 'VariableNames', {'StepPath'});
file = fullfile(folder, 'verify_columns.xlsx');
st_write_specification_workbook(spec, details, file);
readback = readtable(file, 'Sheet', 'TestSpecification', 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
verifyEqual(testCase, readback.Properties.VariableNames, spec.Properties.VariableNames);
verifyEqual(testCase, readback{1,7:8}, spec{1,7:8});
verifyEqual(testCase, readback.MaxTime, 7);
verifyTrue(testCase, startsWith(readback{1,9}, '[OverflowDetails!'));
overflow = readtable(file, 'Sheet', 'OverflowDetails', 'TextType', 'string');
verifyEqual(testCase, strjoin(overflow.Text(overflow.Column == "verify 내용 3"), ''), longText);
package = fullfile(folder, 'unpacked');
unzip(file, package);
sheet = xmlread(fullfile(package, 'xl', 'worksheets', 'sheet1.xml'));
cols = sheet.getElementsByTagName('col');
verifyEqual(testCase, cols.getLength(), width(spec));
for k = 6:8
    verifyEqual(testCase, char(cols.item(k).getAttribute('width')), '60');
end
end

function testInvalidModeRejectedBeforeEnvironmentAccess(testCase)
verifyError(testCase, @() st_export_test_specification('VerifyMode', 'STEP1'), ...
    'simtest:SpecificationVerifyMode');
end

function testWorkbookMissingTextAndNaNMaxTimeRemainBlank(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
file = fullfile(folder, 'missing_values.xlsx');
original = table(["Case1"; "Case2"; "Case3"; "Case4"], ...
    [string(missing); ""; "<missing>"; "A: 1"], [NaN; 0; 7.5; NaN], ...
    'VariableNames', {'Case','Input','MaxTime'});
details = table("S.step2", string(missing), ...
    'VariableNames', {'StepPath','OriginalAction'});
st_write_specification_workbook(original, details, file);
readback = readtable(file, 'Sheet', 'TestSpecification', 'TextType', 'string');
verifyEqual(testCase, height(readback), 4);
verifyTrue(testCase, ismissing(readback.Input(1)) || strlength(readback.Input(1)) == 0);
verifyTrue(testCase, ismissing(readback.Input(2)) || strlength(readback.Input(2)) == 0);
verifyEqual(testCase, readback.Input(3), "<missing>");
verifyEqual(testCase, readback.Input(4), "A: 1");
verifyTrue(testCase, isnan(readback.MaxTime(1)));
verifyEqual(testCase, readback.MaxTime(2:3), [0; 7.5]);
verifyTrue(testCase, isnan(readback.MaxTime(4)));
detailReadback = readtable(file, 'Sheet', 'AssessmentDetails', 'TextType', 'string');
verifyTrue(testCase, all(ismissing(detailReadback.OriginalAction)));
overflow = readtable(file, 'Sheet', 'OverflowDetails', 'TextType', 'string');
verifyEqual(testCase, height(overflow), 0);
verifyTrue(testCase, ismissing(original.Input(1)));
verifyTrue(testCase, isnan(original.MaxTime(1)));
end

function testMaxTimeUsesAllSignalsAndConvertsUnitsToSeconds(testCase)
first = timeseries([1;2], [0;2000]);
first.TimeInfo.Units = 'milliseconds';
first.Time = [0;2000];
data.A = first;
data.Bus(1).B = timeseries([3;4], [0;5]);
data.Bus(2).B = timeseries([5;6], [0;3]);
[text, notes, maxTime] = st_specification_input_lines(data);
verifyEqual(testCase, maxTime, 5);
verifyEqual(testCase, notes, "");
verifyTrue(testCase, contains(text, 'A: 2'));
verifyTrue(testCase, contains(text, 'Bus(1).B: 4'));
verifyTrue(testCase, contains(text, 'Bus(2).B: 6'));
end

function testMaxTimeUnavailableAndDurationTimetable(testCase)
[~, ~, maxTime] = st_specification_input_lines(struct('A', [1 2]));
verifyTrue(testCase, isnan(maxTime));
data.A = timetable(seconds([0; 7]), [1;2], 'VariableNames', {'Values'});
[~, notes, maxTime] = st_specification_input_lines(data);
verifyEqual(testCase, maxTime, 7);
verifyEqual(testCase, notes, "");
data.B = timetable(datetime(2026,9,4) + seconds([0;2]), [3;4], ...
    'VariableNames', {'Values'});
[text, notes, maxTime] = st_specification_input_lines(data);
verifyTrue(testCase, isnan(maxTime));
verifyTrue(testCase, contains(notes, 'elapsed time'));
verifyTrue(testCase, contains(text, 'B: 4'));
end

function [reader, calls] = fixture_reader(paths, info)
data = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(paths), data(char(paths(k))) = info{k}; end
calls = containers.Map('KeyType', 'char', 'ValueType', 'any');
calls('paths') = strings(0,1);
reader = struct('FindSteps', @(block) paths, ...
    'ReadStep', @(block, step) read_mock(data, calls, step), ...
    'ReadTransition', @(block, step, index) fail_transition(block, step, index));
end

function info = read_mock(data, calls, step)
calls('paths') = [calls('paths'); string(step)];
if ~isKey(data, step), error('fixture:MissingStep', 'Step not found: %s', step); end
info = data(step);
if isa(info, 'MException'), throw(info); end
end

function info = step_info(index, action)
info = struct('Index', index, 'Action', action, 'TransitionCount', 0);
end

function [cells, details, notes] = read_fixture(reader, mode)
target = struct('TestCaseName', "Case", 'HarnessName', "Harness");
cfg = struct('VerboseLogging', false);
[cells, details, notes] = st_read_specification_assessment( ...
    'Harness/Assessment', "S", target, cfg, mode, reader);
end

function value = fail_enumeration(~)
error('fixture:Enumeration', 'Step enumeration failed.');
value = []; %#ok<UNRCH>
end

function value = fail_transition(~, ~, ~)
error('fixture:Transition', 'Transition read failed.');
value = []; %#ok<UNRCH>
end
