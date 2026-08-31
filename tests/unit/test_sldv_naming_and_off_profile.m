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
verifyEqual(testCase, profile.ScenarioNames, {'UT_REQ_Controller_001'});
verifyTrue(testCase, isnan(profile.Tmax));
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
