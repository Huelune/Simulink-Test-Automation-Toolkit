function tests = test_sldv_naming_and_off_profile
tests = functiontests(localfunctions);
end


function testScenarioNumbering(testCase)
verifyEqual(testCase, st_scenario_name('Controller', 1), ...
    'UT_REQ_Controller_001');
verifyEqual(testCase, st_scenario_name('Controller', 12), ...
    'UT_REQ_Controller_012');
verifyEqual(testCase, st_scenario_name('Controller', 999), ...
    'UT_REQ_Controller_999');
end


function testScenarioIndexValidation(testCase)
didThrow = false;
try
    st_scenario_name('Controller', 0);
catch
    didThrow = true;
end
verifyTrue(testCase, didThrow);
end


function testOffProfileNeedsNoManifest(testCase)
target = table(1, "Controller", "TEST_TARGET_MODEL_NAME/Controller", ...
    "ControllerHarness", "ControllerTest", "OFF", "", ...
    'VariableNames', {'No','CUTName','CUTPath','HarnessName', ...
    'TestCaseName','SldvMode','SldvDataFile'});
cfg = struct('SldvManifestFile', 'does_not_exist.mat', ...
    'TopModel', 'TEST_TARGET_MODEL_NAME');

profile = st_get_sldv_profile(target, cfg);

verifyEqual(testCase, profile.Mode, 'OFF');
verifyEqual(testCase, profile.DataFileFormat, 'SLDV');
verifyEqual(testCase, profile.MatVariableName, '');
verifyEqual(testCase, profile.ScenarioNames, {'UT_REQ_Controller_001'});
verifyTrue(testCase, isnan(profile.Tmax));
verifyEqual(testCase, sort(fieldnames(profile)), ...
    sort(fieldnames(st_empty_sldv_profile())));
verifyEqual(testCase, profile.Status, 'OK');
verifyEqual(testCase, profile.AtomicAction, 'NOT_APPLICABLE');

profiles = repmat(st_empty_sldv_profile(), 2, 1);
profiles(1) = profile;
verifyEqual(testCase, profiles(1).TestCaseName, 'ControllerTest');
end


function testCachedManifestProfileIsRecoveredAsSuccessful(testCase)
temporaryRoot = tempname;
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot, 's')); %#ok<NASGU>

dataFile = fullfile(temporaryRoot, 'existing_sldvdata.mat');
fileId = fopen(dataFile, 'w');
verifyGreaterThanOrEqual(testCase, fileId, 0);
fclose(fileId);

manifestFile = fullfile(temporaryRoot, 'sldv_manifest.mat');
target = table(1, "Controller", "TestModel/Controller", ...
    "ControllerHarness", "ControllerTest", "FILE", ...
    string(dataFile), ...
    'VariableNames', {'No','CUTName','CUTPath','HarnessName', ...
    'TestCaseName','SldvMode','SldvDataFile'});

cachedProfile = struct( ...
    'No', 1, ...
    'CUTName', 'Controller', ...
    'CUTPath', 'TestModel/Controller', ...
    'HarnessName', 'ControllerHarness', ...
    'TestCaseName', 'ControllerTest', ...
    'Mode', 'FILE', ...
    'RequestedDataFile', dataFile, ...
    'EffectiveDataFile', dataFile, ...
    'Status', 'CACHED', ...
    'Message', 'Checkpoint matches');
manifest = struct( ...
    'TopModel', 'TestModel', ...
    'Profiles', cachedProfile); %#ok<NASGU>
save(manifestFile, 'manifest');

cfg = struct( ...
    'SldvManifestFile', manifestFile, ...
    'TopModel', 'TestModel');
profile = st_get_sldv_profile(target, cfg);

verifyEqual(testCase, profile.Status, 'OK');
verifyEqual(testCase, profile.EffectiveDataFile, dataFile);
verifyEqual(testCase, profile.DataFileFormat, 'SLDV');
verifyEqual(testCase, profile.MatVariableName, '');
verifyEqual(testCase, sort(fieldnames(profile)), ...
    sort(fieldnames(st_empty_sldv_profile())));

profiles = repmat(st_empty_sldv_profile(), 2, 1);
profiles(1) = profile;
verifyEqual(testCase, profiles(1).Mode, 'FILE');
end


function testMissingManifestRowNamesTheNearestRowAndTheFix(testCase)
% A stale or partial manifest (rows Enabled=false when it was written) used
% to fail with a bare "no matching row". The error must identify the target,
% the manifest, the nearest row's differing fields, and the repair command.
temporaryRoot = tempname;
mkdir(temporaryRoot);
cleanup = onCleanup(@() rmdir(temporaryRoot, 's')); %#ok<NASGU>
manifestFile = fullfile(temporaryRoot, 'sldv_manifest.mat');
knownProfile = struct( ...
    'No', 1, ...
    'CUTName', 'Controller', ...
    'CUTPath', 'TestModel/Controller', ...
    'HarnessName', 'ControllerHarness', ...
    'TestCaseName', 'ControllerTest', ...
    'Mode', 'FILE', ...
    'RequestedDataFile', 'a.mat', ...
    'EffectiveDataFile', 'a.mat', ...
    'Status', 'OK', ...
    'Message', '');
manifest = struct('TopModel', 'TestModel', 'Profiles', knownProfile); %#ok<NASGU>
save(manifestFile, 'manifest');
cfg = struct('SldvManifestFile', manifestFile, 'TopModel', 'TestModel');

% Never prepared: nothing in the manifest resembles this row.
unprepared = table(24, "Find_SnapData", "TestModel/Find_SnapData", ...
    "Find_SnapDataHarness", "Find_SnapData_1234", "FILE", "b.mat", ...
    'VariableNames', {'No','CUTName','CUTPath','HarnessName', ...
    'TestCaseName','SldvMode','SldvDataFile'});
verifyError(testCase, @() st_get_sldv_profile(unprepared, cfg), ...
    'simtest:SldvManifestRowMissing');
try
    st_get_sldv_profile(unprepared, cfg);
catch ME
end
verifyTrue(testCase, contains(ME.message, 'No=24 | CUT=Find_SnapData'));
verifyTrue(testCase, contains(ME.message, manifestFile));
verifyTrue(testCase, contains(ME.message, 'never prepared'));
verifyTrue(testCase, contains(ME.message, 'st_prepare_sldv_targets'));

% Renamed after preparation: the same No exists with another Test Case.
renamed = table(1, "Controller", "TestModel/Controller", ...
    "ControllerHarness", "Controller_5678", "FILE", "a.mat", ...
    'VariableNames', {'No','CUTName','CUTPath','HarnessName', ...
    'TestCaseName','SldvMode','SldvDataFile'});
try
    st_get_sldv_profile(renamed, cfg);
catch ME
end
verifyEqual(testCase, ME.identifier, 'simtest:SldvManifestRowMissing');
verifyTrue(testCase, contains(ME.message, 'Closest manifest row 1'));
verifyTrue(testCase, contains(ME.message, ...
    'TestCaseName: manifest=ControllerTest, Excel=Controller_5678'));
verifyFalse(testCase, contains(ME.message, 'never prepared'));
end


function testNormalizeParametersAllowsMissingSource(testCase)
raw = struct('name', 'GainValue', 'value', 4.5);
normalized = st_normalize_sldv_parameters(raw, 2);

verifyEqual(testCase, normalized.Name, 'GainValue');
verifyEqual(testCase, normalized.Value, 4.5);
verifyEqual(testCase, normalized.Source, '');
end


function testNormalizeParametersAcceptsUppercaseFields(testCase)
raw = struct('Name', 'LimitValue', 'Value', int32(7), ...
    'Source', 'model workspace');
normalized = st_normalize_sldv_parameters(raw, 3);

verifyEqual(testCase, normalized.Name, 'LimitValue');
verifyEqual(testCase, normalized.Value, int32(7));
verifyEqual(testCase, normalized.Source, 'model workspace');
end
