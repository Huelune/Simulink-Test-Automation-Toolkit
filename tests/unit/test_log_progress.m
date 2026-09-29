function tests = test_log_progress
%TEST_LOG_PROGRESS Stage and per-target progress lines.
tests = functiontests(localfunctions);
end

function setup(testCase)
testCase.TestData.Dir = tempname;
mkdir(testCase.TestData.Dir);
end

function teardown(testCase)
if isfolder(testCase.TestData.Dir)
    rmdir(testCase.TestData.Dir, 's');
end
end

function testProgressLineFormat(testCase)
cfg = struct('ConsoleLogLevel', 'STEP'); %#ok<NASGU>
out = evalc(['st_log_progress(cfg, 3, 26, ''OK'', ''OBC_Harness'', ' ...
    '''Elapsed'', 30.94);']);
verifyTrue(testCase, contains(out, '[ 3/26] OK'));
verifyTrue(testCase, contains(out, 'OBC_Harness'));
verifyTrue(testCase, contains(out, '30.9s'));
end

function testFailProgressIsErrorClippedOnConsoleFullInLog(testCase)
guard = st_log_scope('enter', 'progress_cmd', testCase.TestData.Dir); %#ok<NASGU>
cfg = struct('ConsoleLogLevel', 'STEP'); %#ok<NASGU>
longMessage = [repmat('x', 1, 100) 'TAIL-OF-MESSAGE']; %#ok<NASGU>
out = evalc(['st_log_progress(cfg, 1, 2, ''FAIL'', ''H1'', ' ...
    '''Message'', longMessage, ''Detail'', ''Top/CUT'');']);
verifyTrue(testCase, contains(out, 'ERROR'));
verifyFalse(testCase, contains(out, 'TAIL-OF-MESSAGE'));
state = st_log_scope('current');
text = fileread(state.LogPath);
verifyTrue(testCase, contains(text, 'TAIL-OF-MESSAGE'));
verifyTrue(testCase, contains(text, 'Top/CUT'));
end

function testStageLinesCountAndListFailures(testCase)
guard = st_log_scope('enter', 'stage_cmd', testCase.TestData.Dir); %#ok<NASGU>
cfg = struct('ConsoleLogLevel', 'STEP'); %#ok<NASGU>
T = table([1;2], ["A";"B"], ["H1";"H2"], ["OK";"FAIL"], ["";"bad port"], ...
    'VariableNames', {'No','CUTName','HarnessName','Status','Message'}); %#ok<NASGU>
out = evalc(['st_log_stage(cfg, ''start'', ''Probe Stage''); ' ...
    'st_log_stage(cfg, ''end'', ''Probe Stage'', ''Result'', T, ''Elapsed'', 5);']);
verifyTrue(testCase, contains(out, '--> [1] Probe Stage'));
verifyTrue(testCase, contains(out, '<-- [1] Probe Stage | OK=1, FAIL=1 | 5.0s'));
verifyTrue(testCase, contains(out, 'CUTName=B'));
verifyTrue(testCase, contains(out, 'bad port'));
end

function testStageFailLine(testCase)
cfg = struct('ConsoleLogLevel', 'STEP'); %#ok<NASGU>
ME = MException('simtest:Probe', 'stage broke'); %#ok<NASGU>
out = evalc(['st_log_stage(cfg, ''fail'', ''Probe Stage'', ' ...
    '''Exception'', ME, ''Elapsed'', 2);']);
verifyTrue(testCase, contains(out, 'Probe Stage | FAILED | 2.0s | simtest:Probe: stage broke'));
end

function testNestedFailureDoesNotFailOuter(testCase)
logDir = testCase.TestData.Dir;
guard = st_log_scope('enter', 'outer_ok_cmd', logDir);
try
    st_log_run('inner_cmd', @() error('simtest:Probe', 'inner broke'), logDir);
catch
    % The outer command handles it, as ContinueOnFailure does.
end
clear guard;
files = dir(fullfile(logDir, '*_outer_ok_cmd.log'));
text = fileread(fullfile(files(1).folder, files(1).name));
verifyTrue(testCase, contains(text, '<== outer_ok_cmd done'));
verifyFalse(testCase, contains(text, 'FAILED'));
end

function testOuterFailureIsRecordedAndStateResets(testCase)
logDir = testCase.TestData.Dir;
verifyError(testCase, @() st_log_run('boom_cmd', ...
    @() error('simtest:Probe', 'boom'), logDir), 'simtest:Probe');
state = st_log_scope('current');
verifyEqual(testCase, state.Depth, 0);
files = dir(fullfile(logDir, '*_boom_cmd.log'));
text = fileread(fullfile(files(1).folder, files(1).name));
verifyTrue(testCase, contains(text, '<== boom_cmd FAILED'));
verifyTrue(testCase, contains(text, 'simtest:Probe'));
end

function testRunForwardsOutputs(testCase)
[a, b] = st_log_run('forward_cmd', @() deal(1, 2), testCase.TestData.Dir);
verifyEqual(testCase, [a b], [1 2]);
end
