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


function testUnexpectedSldvInputsAreIgnoredByDefault(testCase)
cfg = st_config();

verifyTrue(testCase, cfg.IgnoreUnexpectedSldvInputs);
end


function testSldvTimeLimitDefaultsToTheModelSetting(testCase)
cfg = st_config();

verifyEmpty(testCase, cfg.SldvMaxProcessTime);

source = fileread(fullfile(st_project_root(), ...
    'src', 'sldv', 'st_prepare_sldv_targets.m'));
verifyTrue(testCase, contains(source, ...
    "opts.MaxProcessTime = max_process_time(cfg.SldvMaxProcessTime);"));
end


function testConfigScopeOverridesOnlyWhileHeld(testCase)
% A workflow option reaches every stage through st_config() and must not
% outlive the command that set it.
guard = st_config_scope('enter', ...
    struct('IgnoreUnexpectedSldvInputs', false));
verifyFalse(testCase, st_config().IgnoreUnexpectedSldvInputs);

clear guard;
verifyTrue(testCase, st_config().IgnoreUnexpectedSldvInputs);
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
% The check runs inside inspect_sldv_data, which must receive cfg.
verifyTrue(testCase, contains(source, ...
    "harnessInput, ignoreUnexpectedSldvInputs, sldvTestCases, cfg)"));
verifyEqual(testCase, numel(regexp(source, ...
    'meta = inspect_sldv_data\([^;]*\<cfg\);')), 2);
verifyTrue(testCase, contains(source, ...
    "SLDV subsystem mismatch allowed by temporary compatibility"));
verifyTrue(testCase, contains(source, ...
    "Harness input interface validation remains enabled"));
end


function testExpectedUpdateIsAppliedByDefault(testCase)
cfg = st_config();

verifyEqual(testCase, cfg.ExpectedUpdateMode, 'APPLY');
end


function testSldvGenerateFollowsTheCoverageFilterColumns(testCase)
% SLDV must not chase objectives that coverage filters out of the CUT.
source = fileread(fullfile(st_project_root(), ...
    'src', 'sldv', 'st_prepare_sldv_targets.m'));
verifyTrue(testCase, contains(source, ...
    "apply_sldv_coverage_filter(cfg, opts, targetRow, ownerPath, stagingDir);"));
verifyTrue(testCase, contains(source, "opts.CovFilter = 'on';"));

plan = fileread(fullfile(st_project_root(), ...
    'src', 'workflow', 'st_build_execution_plan.m'));
verifyTrue(testCase, contains(plan, ...
    "sldv.CoverageFilterMode = char(row.CoverageFilterMode);"));
end


function testSldvCoverageFilterCanBeSwitchedOff(testCase)
% One real model stayed in sldvrun far past MaxProcessTime with the filter
% on, so it is off by default. The switch must skip the filter and keep the plan signature as it was
% before the filter existed, so switching it rewrites only the SLDV stage.
cfg = st_config();
verifyFalse(testCase, cfg.SldvCoverageFilter);
source = fileread(fullfile(st_project_root(), ...
    'src', 'sldv', 'st_prepare_sldv_targets.m'));
skipAt = strfind(source, 'coverage filter skipped: cfg.SldvCoverageFilter=false');
applyAt = strfind(source, "opts.CovFilter = 'on';");
verifyNotEmpty(testCase, skipAt);
verifyLessThan(testCase, skipAt(1), applyAt(1));
plan = fileread(fullfile(st_project_root(), ...
    'src', 'workflow', 'st_build_execution_plan.m'));
verifyTrue(testCase, contains(plan, 'logical(cfg.SldvCoverageFilter)'));
end
