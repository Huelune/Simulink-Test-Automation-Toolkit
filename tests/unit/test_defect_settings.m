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


function testStageFingerprintChangesWithDefectToggle(testCase)
cfg = st_config();
row = local_row();
on = st_stage_inputs(row, cfg);
cfg.UnreachableDefectTests = false;
off = st_stage_inputs(row, cfg);

verifyNotEqual(testCase, off.TEST_MANAGER, on.TEST_MANAGER);
verifyEqual(testCase, off.SLDV, on.SLDV);
end


function testEmptyColumnMatchesMissingColumn(testCase)
cfg = st_config();
row = local_row();
withColumn = row;
withColumn.DefectInputScenario = "";

verifyEqual(testCase, st_stage_inputs(withColumn, cfg).TEST_MANAGER, ...
    st_stage_inputs(row, cfg).TEST_MANAGER);
end


function testPlanSignatureAndLoaderCoverDefectSettings(testCase)
% No test builds a workbook for st_load_targets or calls the plan's local
% signature function, so these are source checks like the neighbouring tests.
root = st_project_root();
plan = fileread(fullfile(root, 'src', 'workflow', 'st_build_execution_plan.m'));
verifyTrue(testCase, contains(plan, 'cfg.UnreachableDefectTests'));
verifyTrue(testCase, contains(plan, 'row.DefectInputScenario'));

loader = fileread(fullfile(root, 'src', 'targets', 'st_load_targets.m'));
verifyNotEmpty(testCase, regexp(loader, ...
    'raw\{:, idxDefectInputScenario\};\s*if isnumeric\(temp\)', 'once'));
verifyTrue(testCase, contains(loader, ...
    'DefectInputScenario(valid) = string(temp(valid))'));
end
