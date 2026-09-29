function tests = test_sldv_config
tests = functiontests(localfunctions);
end


function testSldvTargetAtomicConversionIsEnabledByDefault(testCase)
cfg = st_config();

verifyTrue(testCase, cfg.AutoConvertSldvTargetsToAtomic);
end


function testLibraryLinkIsNeverDisabledByDefault(testCase)
cfg = st_config();

verifyFalse(testCase, cfg.DisableLibraryLinkForSldvTargets);
end


function testSharedSignalEditorDataFileCheckIsDisabledByDefault(testCase)
cfg = st_config();

verifyFalse(testCase, cfg.CheckSharedSignalEditorDataFile);
end


function testUnexpectedSldvInputsAreRejectedByDefault(testCase)
cfg = st_config();

verifyFalse(testCase, cfg.IgnoreUnexpectedSldvInputs);
end


function testConfigScopeOverridesOnlyWhileHeld(testCase)
% A workflow option reaches every stage through st_config() and must not
% outlive the command that set it.
guard = st_config_scope('enter', ...
    struct('IgnoreUnexpectedSldvInputs', true));
verifyTrue(testCase, st_config().IgnoreUnexpectedSldvInputs);

clear guard;
verifyFalse(testCase, st_config().IgnoreUnexpectedSldvInputs);
end


function testConfigScopeRejectsUnknownField(testCase)
guard = st_config_scope('enter', struct('NoSuchSetting', true)); %#ok<NASGU>
verifyError(testCase, @() st_config(), 'simtest:UnknownConfigOverride');
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
