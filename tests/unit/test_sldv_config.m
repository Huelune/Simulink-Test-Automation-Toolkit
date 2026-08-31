function tests = test_sldv_config
tests = functiontests(localfunctions);
end


function testGenerateAutoAtomicIsEnabledByDefault(testCase)
cfg = st_config();

verifyTrue(testCase, cfg.AutoEnableAtomicForSldvGenerate);
end


function testSharedSignalEditorDataFileCheckIsDisabledByDefault(testCase)
cfg = st_config();

verifyFalse(testCase, cfg.CheckSharedSignalEditorDataFile);
end


function testExpectedUpdateIsAppliedByDefault(testCase)
cfg = st_config();

verifyEqual(testCase, cfg.ExpectedUpdateMode, 'APPLY');
end
