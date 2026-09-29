function tests = test_log_scope
%TEST_LOG_SCOPE One run log per top-level command.
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

function testOutermostEnterCreatesOneLogFile(testCase)
logDir = testCase.TestData.Dir;
cfg = struct('ConsoleLogLevel', 'STEP');
guard = st_log_scope('enter', 'outer_cmd', logDir);
st_log(cfg, 'DEBUG', 'detail-%d', 7);
inner = st_log_scope('enter', 'inner_cmd', logDir);
st_log(cfg, 'INFO', 'inner-line');
clear inner;
state = st_log_scope('current');
verifyEqual(testCase, state.Depth, 1);
clear guard;

files = dir(fullfile(logDir, '*_outer_cmd.log'));
verifyEqual(testCase, numel(files), 1);
verifyEmpty(testCase, dir(fullfile(logDir, '*inner_cmd*.log')));
text = fileread(fullfile(files(1).folder, files(1).name));
verifyTrue(testCase, contains(text, '[DEBUG] detail-7'));
verifyTrue(testCase, contains(text, '[INFO] inner-line'));
verifyTrue(testCase, contains(text, '==> outer_cmd start'));
verifyTrue(testCase, contains(text, '<== outer_cmd done'));
state = st_log_scope('current');
verifyEqual(testCase, state.Depth, 0);
verifyEqual(testCase, state.LogPath, '');
end

function testSameCommandTwiceGetsTwoFiles(testCase)
logDir = testCase.TestData.Dir;
guard = st_log_scope('enter', 'twice_cmd', logDir); %#ok<NASGU>
clear guard;
guard = st_log_scope('enter', 'twice_cmd', logDir); %#ok<NASGU>
clear guard;
files = dir(fullfile(logDir, '*twice_cmd*.log'));
files = files(~endsWith({files.name}, '.console.log'));
verifyEqual(testCase, numel(files), 2);
end

function testOutsideScopeUsesSessionFile(testCase)
cfg = struct('ResultDir', testCase.TestData.Dir, 'ConsoleLogLevel', 'STEP');
st_log(cfg, 'INFO', 'session-line');
files = dir(fullfile(testCase.TestData.Dir, 'logs', 'session_*.log'));
verifyEqual(testCase, numel(files), 1);
text = fileread(fullfile(files(1).folder, files(1).name));
verifyTrue(testCase, contains(text, '[INFO] session-line'));
end

function testWriteFailureWarnsOnceAndContinues(testCase)
% A file where the log folder should be makes every write fail.
blocker = fullfile(testCase.TestData.Dir, 'blocker');
fileId = fopen(blocker, 'w'); fclose(fileId);
logDir = fullfile(blocker, 'logs'); %#ok<NASGU>
cfg = struct('ConsoleLogLevel', 'STEP'); %#ok<NASGU>
out = evalc(['guard = st_log_scope(''enter'', ''blocked_cmd'', logDir); ' ...
    'st_log(cfg, ''INFO'', ''a''); st_log(cfg, ''INFO'', ''b''); ' ...
    'clear guard']);
verifyEqual(testCase, numel(strfind(out, 'Log file write failed')), 1);
end

function testElapsedText(testCase)
verifyEqual(testCase, st_log_elapsed_text(30.94), '30.9s');
verifyEqual(testCase, st_log_elapsed_text(758), '12m38s');
verifyEqual(testCase, st_log_elapsed_text(3725), '1h02m');
end

function testConsoleIsCopiedToConsoleLog(testCase)
assumeEqual(testCase, get(0, 'Diary'), 'off');
logDir = testCase.TestData.Dir;
previousFile = get(0, 'DiaryFile');
guard = st_log_scope('enter', 'diary_cmd', logDir); %#ok<NASGU>
fprintf('console-probe-line\n');
clear guard;
verifyEqual(testCase, get(0, 'Diary'), 'off');
verifyEqual(testCase, get(0, 'DiaryFile'), previousFile);
files = dir(fullfile(logDir, '*_diary_cmd.console.log'));
verifyEqual(testCase, numel(files), 1);
text = fileread(fullfile(files(1).folder, files(1).name));
verifyTrue(testCase, contains(text, 'console-probe-line'));
end

function testExistingDiaryIsLeftAlone(testCase)
assumeEqual(testCase, get(0, 'Diary'), 'off');
logDir = testCase.TestData.Dir;
previousFile = get(0, 'DiaryFile');
userDiary = fullfile(logDir, 'user_diary.txt');
diary(userDiary);
restore = onCleanup(@() restore_diary(previousFile)); %#ok<NASGU>
guard = st_log_scope('enter', 'busy_diary_cmd', logDir); %#ok<NASGU>
clear guard;
verifyEqual(testCase, get(0, 'Diary'), 'on');
verifyEqual(testCase, get(0, 'DiaryFile'), userDiary);
verifyEmpty(testCase, dir(fullfile(logDir, '*busy_diary_cmd.console.log')));
end

function restore_diary(previousFile)
diary('off');
set(0, 'DiaryFile', previousFile);
end