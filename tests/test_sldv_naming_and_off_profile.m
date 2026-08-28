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
