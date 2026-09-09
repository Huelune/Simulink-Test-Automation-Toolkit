function tests = test_mat_file_mode
%TEST_MAT_FILE_MODE FILE+MAT parsing and compatibility contracts.
tests = functiontests(localfunctions);
end

function testDataFileFormatDefaultsAndValidation(testCase)
actual = st_resolve_data_file_formats( ...
    ["FILE";"FILE";"OFF";"GENERATE"], ["";"mat";"ABC";"MAT"]);
verifyEqual(testCase, actual, ["SLDV";"MAT";"SLDV";"SLDV"]);
verifyError(testCase, ...
    @() st_resolve_data_file_formats("FILE", "ABC"), ...
    'simtest:UnsupportedDataFileFormat');

target = table(1, "CUT", "Model/CUT", "Harness", "TC", "FILE", ...
    "input.mat", "ABC", ...
    'VariableNames', {'No','CUTName','CUTPath','HarnessName', ...
    'TestCaseName','SldvMode','SldvDataFile','DataFileFormat'});
cfg = struct('SldvManifestFile', 'unused.mat', 'TopModel', 'Model');
verifyError(testCase, @() st_get_sldv_profile(target, cfg), ...
    'simtest:UnsupportedDataFileFormat');
end

function testTargetLoaderDeclaresBackwardCompatibleColumns(testCase)
source = fileread(fullfile(st_project_root(), ...
    'src', 'targets', 'st_load_targets.m'));
verifyTrue(testCase, contains(source, ...
    'DataFileFormat = repmat("SLDV", n, 1)'));
verifyTrue(testCase, contains(source, ...
    "MatVariableName = strings(n,1)"));
verifyTrue(testCase, contains(source, ...
    "DataFileFormat = st_resolve_data_file_formats"));
end

function testNestedDataNoEffectIsHandled(testCase)
verifyTrue(testCase, st_testcase_has_no_effect( ...
    struct('dataNoEffect', {{{true, {1, logical([1 1])}, []}}})));
verifyFalse(testCase, st_testcase_has_no_effect( ...
    struct('dataNoEffect', {{{true, {1, 0}, []}}})));
verifyFalse(testCase, st_testcase_has_no_effect( ...
    struct('dataNoEffect', {{[], {[]}}})));
verifyFalse(testCase, st_testcase_has_no_effect(struct()));
end

function testSingleDatasetAndMaximumSignalTime(testCase)
assumeDatasetRuntime(testCase);
folder = temporary_folder(testCase);
path = fullfile(folder, 'single.mat');
SnapshotScenario = make_dataset({'A','B'}, {'uint8','double'}, ...
    {[0 1.0], [0 1.5]}); %#ok<NASGU>
Auxiliary = 42; %#ok<NASGU>
save(path, 'SnapshotScenario', 'Auxiliary');

meta = st_inspect_mat_data(path, 'Controller', 0.01, '', quiet_cfg());
verifyEqual(testCase, meta.OriginalNames, {'SnapshotScenario'});
verifyEqual(testCase, meta.ScenarioNames, {'UT_REQ_Controller_001'});
verifyEqual(testCase, meta.SourceIndices, 1);
verifyEqual(testCase, meta.EndTimes, 1.5, 'AbsTol', 1e-12);
verifyEqual(testCase, meta.ParameterCounts, 0);
verifyEqual(testCase, meta.InputNames, {'A';'B'});
end

function testMultipleDatasetsAreSortedByVariableName(testCase)
assumeDatasetRuntime(testCase);
folder = temporary_folder(testCase);
path = fullfile(folder, 'multiple.mat');
Scenario_Z = make_dataset({'A'}, {'double'}, {[0 2]}); %#ok<NASGU>
Scenario_A = make_dataset({'A'}, {'double'}, {[0 1]}); %#ok<NASGU>
save(path, 'Scenario_Z', 'Scenario_A');

meta = st_inspect_mat_data(path, 'CUT', 0.01, '', quiet_cfg());
verifyEqual(testCase, meta.OriginalNames, {'Scenario_A';'Scenario_Z'});
verifyEqual(testCase, meta.ScenarioNames, ...
    {'UT_REQ_CUT_001';'UT_REQ_CUT_002'});
verifyEqual(testCase, meta.EndTimes, [1;2], 'AbsTol', 1e-12);

selected = st_inspect_mat_data( ...
    path, 'CUT', 0.01, 'Scenario_Z', quiet_cfg());
verifyEqual(testCase, selected.OriginalNames, {'Scenario_Z'});
verifyEqual(testCase, selected.EndTimes, 2, 'AbsTol', 1e-12);
end

function testDatasetInterfaceMismatchFails(testCase)
assumeDatasetRuntime(testCase);
folder = temporary_folder(testCase);
path = fullfile(folder, 'mismatch.mat');
Scenario_001 = make_dataset({'A'}, {'double'}, {[0 1]}); %#ok<NASGU>
Scenario_002 = make_dataset({'B'}, {'double'}, {[0 1]}); %#ok<NASGU>
save(path, 'Scenario_001', 'Scenario_002');
verifyError(testCase, ...
    @() st_inspect_mat_data(path, 'CUT', 0.01, '', quiet_cfg()), ...
    'simtest:MatScenarioInterfaceMismatch');
end

function testNoDatasetAndInvalidSelectionFailClearly(testCase)
assumeDatasetRuntime(testCase);
folder = temporary_folder(testCase);
path = fullfile(folder, 'none.mat');
Value = 1; %#ok<NASGU>
save(path, 'Value');
verifyError(testCase, ...
    @() st_inspect_mat_data(path, 'CUT', 0.01, '', quiet_cfg()), ...
    'simtest:MatDatasetMissing');
verifyError(testCase, ...
    @() st_inspect_mat_data(path, 'CUT', 0.01, 'Missing', quiet_cfg()), ...
    'simtest:MatVariableMissing');
verifyError(testCase, ...
    @() st_inspect_mat_data(path, 'CUT', 0.01, 'Value', quiet_cfg()), ...
    'simtest:MatVariableNotDataset');
end

function testDatasetWithoutTimeFails(testCase)
assumeDatasetRuntime(testCase);
folder = temporary_folder(testCase);
path = fullfile(folder, 'no_time.mat');
Scenario = Simulink.SimulationData.Dataset;
signal = Simulink.SimulationData.Signal;
signal.Name = 'A';
signal.Values = [1 2];
Scenario = addElement(Scenario, signal); %#ok<NASGU>
save(path, 'Scenario');
verifyError(testCase, ...
    @() st_inspect_mat_data(path, 'CUT', 0.01, '', quiet_cfg()), ...
    'simtest:MatScenarioTimeMissing');
end

function testStructureWithTimeContributesEndTime(testCase)
assumeDatasetRuntime(testCase);
folder = temporary_folder(testCase);
path = fullfile(folder, 'structure_time.mat');
Scenario = Simulink.SimulationData.Dataset;
signal = Simulink.SimulationData.Signal;
signal.Name = 'A';
signal.Values = struct('time', [0; 2.25], 'signals', ...
    struct('values', [1; 2], 'dimensions', 1));
Scenario = addElement(Scenario, signal); %#ok<NASGU>
save(path, 'Scenario');
meta = st_inspect_mat_data(path, 'CUT', 0.01, '', quiet_cfg());
verifyEqual(testCase, meta.EndTimes, 2.25, 'AbsTol', 1e-12);
end

function testHarnessInterfaceMustMatchExactly(testCase)
harness = struct('Names', {{'A';'B'}}, 'Types', {{'double';'uint8'}}, ...
    'Dimensions', {{1;[2 1]}});
st_validate_mat_harness_interface( ...
    harness, {'A';'B'}, {'double';'uint8'}, {1;[2 1]});
verifyError(testCase, ...
    @() st_validate_mat_harness_interface( ...
        harness, {'B';'A'}, {'uint8';'double'}, {[2 1];1}), ...
    'simtest:MatHarnessInterfaceMismatch');
verifyError(testCase, ...
    @() st_validate_mat_harness_interface( ...
        harness, {'A';'B'}, {'double'}, {1;[2 1]}), ...
    'simtest:MatHarnessInterfaceMismatch');
end

function testDatasetNamesUseGetElementNamesAndMatSkipsSldvParameters(testCase)
root = st_project_root();
signatureSource = fileread(fullfile( ...
    root, 'src', 'sldv', 'st_dataset_signature.m'));
verifyTrue(testCase, contains(signatureSource, 'getElementNames(dataset)'));
verifyFalse(testCase, contains(signatureSource, 'element.Name'));
managerSource = fileread(fullfile( ...
    root, 'src', 'test_manager', 'st_create_test_manager.m'));
verifyTrue(testCase, contains(managerSource, ...
    "elseif strcmp(profile.DataFileFormat, 'MAT')"));
prepareSource = fileread(fullfile( ...
    root, 'src', 'sldv', 'st_prepare_sldv_targets.m'));
verifyTrue(testCase, contains(prepareSource, "case 'SLDV'"));
verifyTrue(testCase, contains(prepareSource, "case 'MAT'"));
verifyFalse(testCase, contains(prepareSource, ...
    'fakeSldvData', 'IgnoreCase', true));
end

function dataset = make_dataset(names, types, times)
dataset = Simulink.SimulationData.Dataset;
for i = 1:numel(names)
    switch types{i}
        case 'uint8'
            data = uint8([1;2]);
        otherwise
            data = [1;2];
    end
    signal = Simulink.SimulationData.Signal;
    signal.Name = names{i};
    signal.Values = timeseries(data, times{i}(:));
    dataset = addElement(dataset, signal);
end
end

function assumeDatasetRuntime(testCase)
assumeTrue(testCase, ...
    ~isempty(which('Simulink.SimulationData.Dataset')) && ...
    ~isempty(which('timeseries')));
end

function folder = temporary_folder(testCase)
folder = tempname;
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
end

function cfg = quiet_cfg()
cfg = struct('VerboseLogging', false);
end
