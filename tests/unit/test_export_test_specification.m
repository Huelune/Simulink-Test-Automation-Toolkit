function tests = test_export_test_specification
%TEST_EXPORT_TEST_SPECIFICATION No model simulation is required by these tests.
tests = functiontests(localfunctions);
end

function testInputLastSamplesAndNestedArrays(testCase)
bus(1).BB = timeseries([10 20; 30 40], [0 1]);
bus(2).BB = timeseries([50 60; 70 80], [0 5]);
data.AAA = bus;
data.DDD = timeseries([1; 3], [0 10]);
[text, notes] = st_specification_input_lines(data);
verifyEqual(testCase, text, join(["AAA(1).BB(1): 30"; "AAA(1).BB(2): 40"; ...
    "AAA(2).BB(1): 70"; "AAA(2).BB(2): 80"; "DDD: 3"], newline));
verifyEqual(testCase, notes, "");
end

function testMatrixSamplesUseLastTimeDimensionAndColumnMajorLeaves(testCase)
samples = cat(3, zeros(2,2), [1 3; 2 4]);
data.A = timeseries(samples, [0 1]);
[text, notes] = st_specification_input_lines(data);
verifyEqual(testCase, text, join(["A(1): 1"; "A(2): 2"; "A(3): 3"; "A(4): 4"], newline));
verifyEqual(testCase, notes, "");
end

function testBusMatrixSubscriptsAndNumericLeafSubscripts(testCase)
data.Bus = repmat(struct('X', [1 2]), 2, 2);
[text, notes] = st_specification_input_lines(data);
verifyTrue(testCase, startsWith(text, "Bus(1,1).X(1): 1"));
verifyTrue(testCase, contains(text, "Bus(2,1).X(2): 2"));
verifyTrue(testCase, contains(text, "Bus(1,2).X(1): 1"));
verifyTrue(testCase, endsWith(text, "Bus(2,2).X(2): 2"));
verifyEqual(testCase, notes, "");
end

function testUnsupportedLeafDoesNotHideOtherInputs(testCase)
data.Bad = @sin;
data.Good = uint64(9007199254740992) + uint64(1);
[text, notes] = st_specification_input_lines(data);
verifyTrue(testCase, contains(text, "Bad: <읽기 실패>"));
verifyTrue(testCase, contains(text, "Good: 9007199254740993"));
verifyTrue(testCase, contains(notes, 'function_handle'));
end

function testDatasetAndTimetable(testCase)
assumeTrue(testCase, ~isempty(which('Simulink.SimulationData.Dataset')));
ds = Simulink.SimulationData.Dataset;
ds = addElement(ds, timeseries([1; 2], [0 1]), 'ABC');
ds = addElement(ds, timetable(seconds([0; 2]), [3 4; 5 6], ...
    'VariableNames', {'Values'}), 'DDD');
[text, notes] = st_specification_input_lines(ds);
verifyEqual(testCase, text, join(["ABC: 2"; "DDD(1): 5"; "DDD(2): 6"], newline));
verifyEqual(testCase, notes, "");
end

function testVerifyKeepsIndexAndLiteralWithoutEvaluation(testCase)
action = sprintf(['verify(AAA(1) == 0);\nverify(AAA(2) == 1);\n' ...
    'verify(BBB(1,2).CC(3) == uint8(2));\nverify(AAA(1) == 4);']);
[text, notes] = st_specification_verify_lines(action);
verifyEqual(testCase, text, join(["AAA(1): 0"; "AAA(2): 1"; ...
    "BBB(1,2).CC(3): uint8(2)"; "AAA(1): 4"], newline));
verifyEqual(testCase, notes, "");
end

function testVerifyScannerIgnoresCommentsStringsAndKeepsComplexCalls(testCase)
action = sprintf(['%% verify(Wrong == 1);\n' ...
    'label = "verify(Wrong == 2);";\n' ...
    '%%{\nverify(Wrong == 3);\n%%}\n' ...
    'verify(A(1) == max(1, 2)); verify(B > 0);\n' ...
    'verify(C == 1 && D == 2);\n' ...
    'verify(E == 1, "message");\nverify(F == "a)b");']);
[text, notes] = st_specification_verify_lines(action);
verifyFalse(testCase, contains(text, 'Wrong'));
verifyEqual(testCase, text, join(["A(1): max(1, 2)"; "verify(B > 0);"; ...
    "verify(C == 1 && D == 2);"; 'verify(E == 1, "message");'; 'F: "a)b"'], newline));
verifyTrue(testCase, contains(notes, 'Complex verify'));
end

function testBindingParserDoesNotConfuseScenarioNamePrefixes(testCase)
params = {'SignalBuilderGroup', 'input_010'; 'TestSequenceScenario', 'Custom Assessment'};
[value, note] = st_specification_parameter(params, {'TestSequenceScenario'});
verifyEqual(testCase, value, "Custom Assessment");
verifyEqual(testCase, note, "");
[value, ~] = st_specification_parameter(params, {'SignalEditorScenario','SignalBuilderGroup'});
verifyEqual(testCase, value, "input_010");
[value, ~] = st_specification_parameter({'OtherTestSequenceScenario', 'wrong'}, {'TestSequenceScenario'});
verifyEqual(testCase, value, "");
[value, note] = st_specification_parameter( ...
    {'SignalEditorScenario','a'; 'SignalBuilderGroup','b'}, ...
    {'SignalEditorScenario','SignalBuilderGroup'});
verifyEqual(testCase, value, "");
verifyTrue(testCase, contains(note, 'Ambiguous'));
end

function testBindingParserNestedAndStructShapes(testCase)
params = {{'TestSequenceScenario','renamed'}; ...
    struct('Name','SignalBuilderGroup','Value','inputs')};
[value, ~] = st_specification_parameter(params, {'TestSequenceScenario'});
verifyEqual(testCase, value, "renamed");
[value, ~] = st_specification_parameter(params, {'SignalBuilderGroup'});
verifyEqual(testCase, value, "inputs");
[value, ~] = st_specification_parameter('TestSequenceScenario = ''with spaces''', {'TestSequenceScenario'});
verifyEqual(testCase, value, "with spaces");
end

function testActualTableIterationParameterRepresentation(testCase)
assumeTrue(testCase, ~isempty(which('sltest.testmanager.TestIteration')));
iteration = sltest.testmanager.TestIteration;
setTestParam(iteration, 'SignalEditorScenario', 'input_custom_10');
setTestParam(iteration, 'TestSequenceScenario', 'assessment_renamed');
[value, note] = st_specification_parameter(iteration.TestParams, {'TestSequenceScenario'});
verifyEqual(testCase, value, "assessment_renamed");
verifyEqual(testCase, note, "");
[value, note] = st_specification_parameter(iteration.TestParams, ...
    {'SignalEditorScenario','SignalBuilderGroup'});
verifyEqual(testCase, value, "input_custom_10");
verifyEqual(testCase, note, "");
end

function testSharedBusIndexingPreservesExistingRules(testCase)
verifyEqual(testCase, st_indexed_expressions('A', [1 1], true), {'A(1,1)'});
verifyEqual(testCase, st_indexed_expressions('A', 2, true), {'A(1)'; 'A(2)'});
verifyEqual(testCase, st_indexed_expressions('A', [2 2], true), ...
    {'A(1,1)'; 'A(2,1)'; 'A(1,2)'; 'A(2,2)'});
end

function testWorkbookKeepsFirstPrimaryOverflowPartAndAddsRowNote(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
path = fullfile(folder, 'spec.xlsx');
longText = string(repmat('가', 1, 33000));
manyLines = strjoin(repmat("ABC(1): 2", 300, 1), newline);
original = table(["케이스1"; "케이스2"], ["ABC: 1" + newline + "DDD: 2"; longText], ...
    ["AAA(1): 0"; manyLines], [""; ""], ...
    'VariableNames', {'Case','input 시나리오 내용','verify 내용','비고'});
details = table("step1", longText, "", ...
    'VariableNames', {'Step','Action','Message'});
[written, writtenDetails] = st_write_specification_workbook(original, details, path);
readback = readtable(path, 'Sheet', 'TestSpecification', 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
verifyEqual(testCase, readback{1,'input 시나리오 내용'}, original{1,'input 시나리오 내용'});
longCharacters = char(longText);
verifyEqual(testCase, char(readback{2,'input 시나리오 내용'}), longCharacters(1:30000));
verifyLessThanOrEqual(testCase, sum(char(readback{2,'verify 내용'}) == newline), 250);
verifyTrue(testCase, contains(readback{2,'비고'}, "input 시나리오 내용"));
verifyTrue(testCase, contains(readback{2,'비고'}, "verify 내용"));
verifyTrue(testCase, contains(readback{2,'비고'}, "[OverflowDetails!E"));
verifyEqual(testCase, written{:,'input 시나리오 내용'}, readback{:,'input 시나리오 내용'});
verifyEqual(testCase, written{2,'비고'}, readback{2,'비고'});
detailReadback = readtable(path, 'Sheet', 'AssessmentDetails', 'TextType', 'string');
verifyTrue(testCase, startsWith(writtenDetails.Action, "[OverflowDetails!E"));
verifyEqual(testCase, writtenDetails.Action, detailReadback.Action);
verifyEqual(testCase, writtenDetails.Message, detailReadback.Message);
overflow = readtable(path, 'Sheet', 'OverflowDetails', 'TextType', 'string');
inputOverflowRows = find(overflow.Column == "input 시나리오 내용");
verifyOverflowRows = find(overflow.Column == "verify 내용");
verifyEqual(testCase, readback{2,'input 시나리오 내용'}, overflow.Text(inputOverflowRows(1)));
verifyEqual(testCase, readback{2,'verify 내용'}, overflow.Text(verifyOverflowRows(1)));
verifyTrue(testCase, contains(readback{2,'비고'}, sprintf( ...
    '[OverflowDetails!E%d:E%d]', inputOverflowRows(1) + 1, inputOverflowRows(end) + 1)));
verifyTrue(testCase, contains(readback{2,'비고'}, sprintf( ...
    '[OverflowDetails!E%d:E%d]', verifyOverflowRows(1) + 1, verifyOverflowRows(end) + 1)));
verifyEqual(testCase, strjoin(overflow.Text(overflow.Column == "input 시나리오 내용"), ''), longText);
verifyEqual(testCase, strjoin(overflow.Text(overflow.Column == "verify 내용"), ''), manyLines);
verifyEqual(testCase, strjoin(overflow.Text(overflow.Column == "Action"), ''), longText);
package = fullfile(folder, 'unpacked');
unzip(path, package);
style = xmlread(fullfile(package, 'xl', 'styles.xml'));
align = style.getElementsByTagName('alignment');
wrapped = false;
for k = 0:align.getLength()-1
    wrapped = wrapped || strcmp(char(align.item(k).getAttribute('wrapText')), '1');
end
verifyTrue(testCase, wrapped);
signature = st_file_signature(path);
verifyError(testCase, @() st_write_specification_workbook(original, details, path), ...
    'simtest:SpecificationOutputExists');
after = st_file_signature(path);
verifyEqual(testCase, after.SHA256, signature.SHA256);
end

function testWorkbookShowsDecisionNamesAndWritesJsonDetailSheet(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
path = fullfile(folder, 'decision_blocks.xlsx');
raw = "[" + newline + ...
    '{"BlockType":"Switch","Name":"Switch","Path":"Top/CUT/Switch"},' + newline + ...
    '{"BlockType":"Switch","Name":"Switch2","Path":"Top/CUT/Switch2"},' + newline + ...
    '{"BlockType":"If","Name":"If (a==1)","Path":"Top/CUT/If"},' + newline + ...
    '{"BlockType":"If","Name":"elseIF(a!=1)","Path":"Top/CUT/ElseIf"},' + newline + ...
    '{"BlockType":"If","Name":"else","Path":"Top/CUT/Else"}' + newline + "]";
specification = table(["Case1"; "Case2"], ["Top/CUT"; "Top/Empty"], ...
    [raw; "[]"], strings(2,1), 'VariableNames', ...
    {'테스트 케이스명','CUTPath','DecisionBlocks','비고'});
assessmentDetails = table(strings(0,1), 'VariableNames', {'Message'});
[written, ~] = st_write_specification_workbook( ...
    specification, assessmentDetails, path);
expected = strjoin(["D1 Switch"; "D2 Switch2"; "D3 If (a==1)"; ...
    "D4 elseIF(a!=1)"; "D5 else"], newline);
verifyEqual(testCase, written.DecisionBlocks(1), expected);
verifyEqual(testCase, written.DecisionBlocks(2), "");
readback = readtable(path, 'Sheet', 'TestSpecification', 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
verifyEqual(testCase, readback.DecisionBlocks(1), expected);
decisionDetails = readtable(path, 'Sheet', 'DecisionBlockDetails', 'TextType', 'string');
verifyEqual(testCase, decisionDetails.Decision(1:5), compose("D%d", (1:5).'));
verifyEqual(testCase, decisionDetails.Name(1:5), ...
    ["Switch"; "Switch2"; "If (a==1)"; "elseIF(a!=1)"; "else"]);
verifyEqual(testCase, decisionDetails.JSON(6), "[]");
decoded = jsondecode(char(decisionDetails.JSON(4)));
verifyEqual(testCase, string(decoded.BlockType), "If");
verifyEqual(testCase, string(decoded.Name), "elseIF(a!=1)");
verifyEqual(testCase, string(decoded.Path), "Top/CUT/ElseIf");
verifyTrue(testCase, all(decisionDetails.ReadStatus == "OK"));
verifyTrue(testCase, any(string(sheetnames(path)) == "DecisionBlockDetails"));
verifyTrue(testCase, any(string(sheetnames(path)) == "OverflowDetails"));
end

function testWorkbookStartsWithUsageSheetAndListsExecutionUnits(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
path = fullfile(folder, 'usage.xlsx');
specification = table("Case1", "", 'VariableNames', {'Case','비고'});
assessmentDetails = table(strings(0,1), 'VariableNames', {'Message'});
st_write_specification_workbook(specification, assessmentDetails, path);
sheets = string(sheetnames(path));
verifyEqual(testCase, sheets(:), ["사용법"; "TestSpecification"; ...
    "AssessmentDetails"; "DecisionBlockDetails"; "OverflowDetails"]);
usage = readtable(path, 'Sheet', '사용법', 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
verifyEqual(testCase, usage.Properties.VariableNames, ...
    {'구분','실행파일','직접실행','역할','사용시점','대표사용법'});
files = usage{:,'실행파일'};
verifyTrue(testCase, any(files == "st_run_from_harness.m"));
verifyTrue(testCase, any(files == "st_run_after_harness.m"));
verifyTrue(testCase, any(files == "st_run_tests_per_cut.m"));
verifyTrue(testCase, any(files == "st_export_test_specification.m"));
verifyTrue(testCase, any(files == "st_check_actual_system.m"));
verifyFalse(testCase, any(files == "st_run_workflow.m"));
end

function testExporterHasNoSimulationOrSourceMutationCalls(testCase)
folder = fullfile(st_project_root(), 'src', 'exporting');
files = [dir(fullfile(folder, 'st_*specification*.m')); ...
    dir(fullfile(folder, 'st_specification_*.m'))];
for i = 1:numel(files)
    source = fileread(fullfile(files(i).folder, files(i).name));
    forbidden = {'\bsim\s*\(', 'sltest\.testmanager\.run\s*\(', ...
        '\bsave_system\s*\(', '\bsaveToFile\s*\(', ...
        'sltest\.testsequence\.(activateScenario|editStep|addScenario)\s*\(', ...
        '\bst_run_\w*\s*\(', '\bst_update_expected_from_results\s*\('};
    for j = 1:numel(forbidden)
        verifyEmpty(testCase, regexp(source, forbidden{j}, 'once'), files(i).name);
    end
end
end

function testDirtyModelRejectionDoesNotWarnOrCloseUserModel(testCase)
% Exercise the actual early-error/unwind path from the field report.
% Only st_config/st_load_targets are redirected to disposable local inputs.
assumeTrue(testCase, ~isempty(which('new_system')));
folder = tempname;
mkdir(folder);
[~, token] = fileparts(folder);
model = matlab.lang.makeValidName(['SpecCleanup_' token]);
originalPath = path;
testCase.addTeardown(@() cleanup_dirty_fixture(model, folder, originalPath));
cfg = struct('TopModel', model, 'ModelFile', fullfile(folder, [model '.slx']), ...
    'TestFile', fullfile(folder, 'test.mldatx'), ...
    'ManagementExcel', fullfile(folder, 'targets.xlsx'), ...
    'ResultDir', folder, 'HasRuntimeTarget', true, ...
    'OnlyEnabled', true, 'VerboseLogging', false);
new_system(model);
save_system(model, cfg.ModelFile);
set_param(model, 'Dirty', 'on');
write_fixture_file(cfg.TestFile, 'unused: rejected before Test Manager load');
write_fixture_file(cfg.ManagementExcel, 'unused: targets supplied by fixture');
save(fullfile(folder, 'cfg.mat'), 'cfg');
write_fixture_file(fullfile(folder, 'st_config.m'), sprintf([ ...
    'function cfg = st_config()\n' ...
    's = load(fullfile(fileparts(mfilename(''fullpath'')), ''cfg.mat''));\n' ...
    'cfg = s.cfg;\nend\n']));
write_fixture_file(fullfile(folder, 'st_load_targets.m'), sprintf([ ...
    'function targets = st_load_targets(varargin)\n' ...
    'targets = table(strings(0,1), ''VariableNames'', {''HarnessName''});\nend\n']));
addpath(folder, '-begin');
clear st_config st_load_targets;
signature = st_file_signature(cfg.ModelFile);
output = fullfile(folder, 'rejected.xlsx');
lastwarn('');
verifyError(testCase, @() st_export_test_specification('OutputFile', output), ...
    'simtest:SpecificationUnsaved');
[warningText, ~] = lastwarn;
verifyEmpty(testCase, warningText);
verifyTrue(testCase, bdIsLoaded(model));
verifyEqual(testCase, get_param(model, 'Dirty'), 'on');
verifyFalse(testCase, isfile(output));
after = st_file_signature(cfg.ModelFile);
verifyEqual(testCase, after.SHA256, signature.SHA256);
end

function write_fixture_file(file, text)
fid = fopen(file, 'w');
assert(fid >= 0, 'Cannot create test fixture file.');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', text);
end

function cleanup_dirty_fixture(model, folder, originalPath)
path(originalPath);
clear st_config st_load_targets;
if bdIsLoaded(model), close_system(model, 0); end
if isfolder(folder), rmdir(folder, 's'); end
end
