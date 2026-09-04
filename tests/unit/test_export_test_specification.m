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

function testWorkbookWrapAndLosslessOverflow(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
path = fullfile(folder, 'spec.xlsx');
longText = string(repmat('가', 1, 33000));
manyLines = strjoin(repmat("ABC(1): 2", 300, 1), newline);
original = table(["케이스1"; "케이스2"], ["ABC: 1" + newline + "DDD: 2"; longText], ...
    ["AAA(1): 0"; manyLines], 'VariableNames', {'Case','Input','Verify'});
details = table("step1", "verify(AAA(1) == 0);", 'VariableNames', {'Step','Action'});
st_write_specification_workbook(original, details, path);
readback = readtable(path, 'Sheet', 'TestSpecification', 'TextType', 'string');
verifyEqual(testCase, readback.Input(1), original.Input(1));
verifyTrue(testCase, startsWith(readback.Input(2), '[OverflowDetails!'));
overflow = readtable(path, 'Sheet', 'OverflowDetails', 'TextType', 'string');
verifyEqual(testCase, strjoin(overflow.Text(overflow.Column == "Input"), ''), longText);
verifyEqual(testCase, strjoin(overflow.Text(overflow.Column == "Verify"), ''), manyLines);
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
