function tests = test_defect_settings
tests = functiontests(localfunctions);
end


function testConfigDefaults(testCase)
cfg = st_config();

verifyTrue(testCase, cfg.UnreachableDefectTests);
verifyEqual(testCase, cfg.DefectReasonSheet, 'DefectReasons');
end


function testStageFingerprintChangesWithDefectInput(testCase)
cfg = st_config();
row = local_row();
row.DefectInputScenario = "";
base = st_stage_inputs(row, cfg);
row.DefectInputScenario = "2";
changed = st_stage_inputs(row, cfg);

verifyNotEqual(testCase, changed.TEST_MANAGER, base.TEST_MANAGER);
verifyEqual(testCase, changed.SLDV, base.SLDV);
end


function testStageFingerprintToleratesMissingColumn(testCase)
cfg = st_config();
inputs = st_stage_inputs(local_row(), cfg);

verifyTrue(testCase, isfield(inputs, 'TEST_MANAGER'));
end


function row = local_row()
row = table("cut", "path", "harness", "tc", "OFF", "SLDV", "", "", ...
    'VariableNames', {'CUTName','CUTPath','HarnessName','TestCaseName', ...
    'SldvMode','DataFileFormat','MatVariableName','SldvTestCases'});
end
