function tests = test_call_quiet
%TEST_CALL_QUIET MathWorks console output goes to the run log.
tests = functiontests(localfunctions);
end

function setup(testCase)
testCase.TestData.Dir = tempname;
mkdir(testCase.TestData.Dir);
testCase.TestData.Guard = st_log_scope('enter', 'quiet_cmd', testCase.TestData.Dir);
testCase.TestData.Cfg = struct('ConsoleLogLevel', 'STEP');
end

function teardown(testCase)
testCase.TestData.Guard = [];
if isfolder(testCase.TestData.Dir)
    rmdir(testCase.TestData.Dir, 's');
end
end

function testOutputGoesToLogNotConsole(testCase)
cfg = testCase.TestData.Cfg; %#ok<NASGU>
out = evalc('st_call_quiet(cfg, ''probe'', @() fprintf(''system-chatter\n''));');
verifyFalse(testCase, contains(out, 'system-chatter'));
verifyTrue(testCase, contains(log_text(), '[SYS probe] system-chatter'));
end

function testReturnsEveryOutput(testCase)
[a, b] = st_call_quiet(testCase.TestData.Cfg, 'probe', @() deal(1, 2));
verifyEqual(testCase, [a b], [1 2]);
end

function testWarningsAreCountedIncludingKoreanLocale(testCase)
cfg = testCase.TestData.Cfg; %#ok<NASGU>
korean = char([0xACBD 0xACE0]); %#ok<NASGU>
out = evalc(['st_call_quiet(cfg, ''probe'', @() fprintf(' ...
    '''Warning: first\nWarning: first\n%s: second\nplain line\n'', korean));']);
verifyTrue(testCase, contains(out, 'probe system warnings: 3 (2 distinct)'));
end

function testMatlabWarningIsCaptured(testCase)
% Pins the assumption that evalc captures warning() output on this release.
cfg = testCase.TestData.Cfg; %#ok<NASGU>
state = warning('on', 'simtest:QuietProbe');
restore = onCleanup(@() warning(state)); %#ok<NASGU>
out = evalc(['st_call_quiet(cfg, ''probe'', ' ...
    '@() warning(''simtest:QuietProbe'', ''quiet-probe-warning''));']);
verifyTrue(testCase, contains(out, 'probe system warnings: 1'));
verifyTrue(testCase, contains(log_text(), 'quiet-probe-warning'));
end

function testErrorKeepsOutputAndRethrows(testCase)
verifyError(testCase, @() st_call_quiet(testCase.TestData.Cfg, ...
    'probe', @emit_then_fail), 'simtest:QuietProbeFailed');
verifyTrue(testCase, contains(log_text(), '[SYS probe] before-failure'));
end

function emit_then_fail()
fprintf('before-failure\n');
error('simtest:QuietProbeFailed', 'boom');
end

function text = log_text()
state = st_log_scope('current');
text = fileread(state.LogPath);
end
