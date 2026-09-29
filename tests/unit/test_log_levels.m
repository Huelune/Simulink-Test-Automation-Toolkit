function tests = test_log_levels
%TEST_LOG_LEVELS Console filtering by cfg.ConsoleLogLevel.
tests = functiontests(localfunctions);
end

function testStepLevelHidesInfoAndDebug(testCase)
cfg = struct('ConsoleLogLevel', 'STEP');
out = evalc(['st_log(cfg, ''INFO'', ''info-line''); ' ...
    'st_log(cfg, ''DEBUG'', ''debug-line''); ' ...
    'st_log(cfg, ''STEP'', ''step-line''); ' ...
    'st_log(cfg, ''WARN'', ''warn-line''); ' ...
    'st_log(cfg, ''ERROR'', ''error-line'');']);
verifyFalse(testCase, contains(out, 'info-line'));
verifyFalse(testCase, contains(out, 'debug-line'));
verifyTrue(testCase, contains(out, 'step-line'));
verifyTrue(testCase, contains(out, 'WARN  warn-line'));
verifyTrue(testCase, contains(out, 'ERROR error-line'));
end

function testInfoLevelShowsInfoButNotDebug(testCase)
cfg = struct('ConsoleLogLevel', 'INFO');
out = evalc(['st_log(cfg, ''INFO'', ''info-line''); ' ...
    'st_log(cfg, ''DEBUG'', ''debug-line'');']);
verifyTrue(testCase, contains(out, 'INFO  info-line'));
verifyFalse(testCase, contains(out, 'debug-line'));
end

function testStepLineHasNoLevelTag(testCase)
cfg = struct('ConsoleLogLevel', 'STEP');
out = evalc('st_log(cfg, ''STEP'', ''step-line'');');
verifyNotEmpty(testCase, regexp(out, ...
    '^\[\d\d:\d\d:\d\d\] step-line', 'once', 'lineanchors'));
end

function testUnknownConsoleLevelFallsBackToStep(testCase)
% A typo in the setting must not break logging or flood the console.
cfg = struct('ConsoleLogLevel', 'LOUD');
out = evalc(['st_log(cfg, ''INFO'', ''info-line''); ' ...
    'st_log(cfg, ''STEP'', ''step-line'');']);
verifyFalse(testCase, contains(out, 'info-line'));
verifyTrue(testCase, contains(out, 'step-line'));
end

function testVerboseLoggingStructStillWorks(testCase)
verbose = struct('VerboseLogging', true);
out = evalc('st_log(verbose, ''DEBUG'', ''debug-line'');');
verifyTrue(testCase, contains(out, 'debug-line'));
quiet = struct('VerboseLogging', false);
out = evalc('st_log(quiet, ''INFO'', ''info-line'');');
verifyFalse(testCase, contains(out, 'info-line'));
end

function testNonStructConfigUsesStep(testCase)
out = evalc(['st_log([], ''INFO'', ''info-line''); ' ...
    'st_log([], ''WARN'', ''warn-line'');']);
verifyFalse(testCase, contains(out, 'info-line'));
verifyTrue(testCase, contains(out, 'warn-line'));
end

function testConfigDefaultsToStep(testCase)
source = fileread(fullfile(st_project_root(), 'src', 'config', 'st_config.m'));
verifyTrue(testCase, contains(source, "cfg.ConsoleLogLevel = 'STEP';"));
verifyFalse(testCase, contains(source, 'cfg.VerboseLogging ='));
end