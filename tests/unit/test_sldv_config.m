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


function testSldvSubsystemPathMismatchIsTemporarilyAllowed(testCase)
cfg = st_config();

verifyTrue(testCase, cfg.AllowSldvSubsystemPathMismatch);

source = fileread(fullfile(st_project_root(), ...
    'src', 'sldv', 'st_prepare_sldv_targets.m'));
verifyTrue(testCase, contains(source, ...
    "if ~allowPathMismatch"));
verifyTrue(testCase, contains(source, ...
    "SLDV subsystem mismatch allowed by temporary compatibility"));
verifyTrue(testCase, contains(source, ...
    "Harness input interface validation remains enabled"));
end


function testExpectedUpdateIsAppliedByDefault(testCase)
cfg = st_config();

verifyEqual(testCase, cfg.ExpectedUpdateMode, 'APPLY');
end
