function tests = test_sldv_config
tests = functiontests(localfunctions);
end


function testSldvTargetAtomicConversionIsEnabledByDefault(testCase)
cfg = st_config();

verifyTrue(testCase, cfg.AutoConvertSldvTargetsToAtomic);
end


function testSharedSignalEditorDataFileCheckIsDisabledByDefault(testCase)
cfg = st_config();

verifyFalse(testCase, cfg.CheckSharedSignalEditorDataFile);
end


function testUnexpectedSldvInputsAreRejectedByDefault(testCase)
cfg = st_config();

verifyFalse(testCase, cfg.IgnoreUnexpectedSldvInputs);
end


function testExpectedUpdateIsAppliedByDefault(testCase)
cfg = st_config();

verifyEqual(testCase, cfg.ExpectedUpdateMode, 'APPLY');
end
