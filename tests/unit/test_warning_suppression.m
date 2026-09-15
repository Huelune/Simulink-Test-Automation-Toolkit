function tests = test_warning_suppression
%TEST_WARNING_SUPPRESSION Scoped warning suppression contracts.
tests = functiontests(localfunctions);
end

function testConfiguredIdentifierIsDisabledAndRestored(testCase)
cfg = struct('VerboseLogging', false);
cfg.SuppressedWarnings = {'simtest:WarningSuppressionProbe'};
entryState = warning();
restoreEntry = onCleanup(@() warning(entryState)); %#ok<NASGU>

cleanup = st_suppress_warnings(cfg, 'UNIT_TEST');
active = warning('query', 'simtest:WarningSuppressionProbe');
verifyEqual(testCase, active.state, 'off');

clear cleanup;
restored = warning('query', 'simtest:WarningSuppressionProbe');
verifyEqual(testCase, restored.state, 'on');
end

function testBareWordIsNotAcceptedAsIdentifier(testCase)
% A typo must not widen into warning('off','all') and hide everything.
cfg = struct('VerboseLogging', false);
cfg.SuppressedWarnings = {'all', 'verbose', 'simtest:WarningSuppressionProbe'};
entryState = warning();
restoreEntry = onCleanup(@() warning(entryState)); %#ok<NASGU>

cleanup = st_suppress_warnings(cfg, 'UNIT_TEST'); %#ok<NASGU>
allState = warning('query', 'all');
verifyEqual(testCase, allState.state, 'on');
probe = warning('query', 'simtest:WarningSuppressionProbe');
verifyEqual(testCase, probe.state, 'off');
end

function testEmptyConfigurationSuppressesNothing(testCase)
cfg = struct('VerboseLogging', false, 'SuppressedWarnings', {{}});
entryState = warning();
cleanup = st_suppress_warnings(cfg, 'UNIT_TEST'); %#ok<NASGU>
verifyEqual(testCase, warning(), entryState);
end

function testExportLoopUsesTheScopedHelper(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'exporting', ...
    'st_export_standalone_harnesses.m'));
verifyTrue(testCase, contains(source, 'st_suppress_warnings('));
verifyTrue(testCase, contains(source, "'STANDALONE_HARNESS_EXPORT'"));

helper = fileread(fullfile(root, 'src', 'shared', ...
    'st_suppress_warnings.m'));
verifyTrue(testCase, contains(helper, "warning('off', identifiers{i})"));
verifyTrue(testCase, contains(helper, 'onCleanup(@() restore_warnings('));
verifyFalse(testCase, contains(helper, "warning('off', 'all')"));

config = fileread(fullfile(root, 'src', 'config', 'st_config.m'));
verifyTrue(testCase, contains(config, 'cfg.SuppressedWarnings = {}'));
end
