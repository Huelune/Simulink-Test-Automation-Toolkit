function tests = test_short_build_directory
tests = functiontests(localfunctions);
end


function testEntersShortFolderAndRestores(testCase)
base = tempname;
testCase.addTeardown(@() remove_folder(base));
cfg = struct('StandaloneBuildCacheDir', base, 'VerboseLogging', false);
previousDirectory = pwd;
previousPath = path;
previousConfig = Simulink.fileGenControl('getConfig');

cleanup = st_enter_short_build_directory(cfg, 'TEST');
folder = pwd;
verifyTrue(testCase, startsWith(folder, base));
current = Simulink.fileGenControl('getConfig');
verifyEqual(testCase, char(current.CacheFolder), folder);
verifyEqual(testCase, char(current.CodeGenFolder), folder);
verifyTrue(testCase, contains(path, previousDirectory));

clear cleanup
verifyEqual(testCase, pwd, previousDirectory);
verifyEqual(testCase, path, previousPath);
restored = Simulink.fileGenControl('getConfig');
verifyEqual(testCase, char(restored.CacheFolder), ...
    char(previousConfig.CacheFolder));
verifyFalse(testCase, isfolder(folder));
end


function testCallerFolderStaysOnPathWhenItWasTheCacheFolder(testCase)
% Simulink.fileGenControl('set') drops the previous cache folder from the
% path unless keepPreviousPath is true. When that folder is also where the
% caller works, the Harness input MAT files there stop resolving by name.
base = tempname;
caller = tempname;
mkdir(caller);
testCase.addTeardown(@() remove_folder(base));
testCase.addTeardown(@() remove_folder(caller));
testCase.addTeardown(@restore_session, pwd, path, ...
    Simulink.fileGenControl('getConfig'));
cd(caller);
Simulink.fileGenControl('set', 'CacheFolder', caller, 'CodeGenFolder', caller);
cfg = struct('StandaloneBuildCacheDir', base, 'VerboseLogging', false);

cleanup = st_enter_short_build_directory(cfg, 'TEST');

entries = string(strsplit(path, pathsep));
verifyTrue(testCase, any(strcmpi(entries, caller)));
clear cleanup
end


function testLeavesACallerInsideTheBaseAlone(testCase)
base = tempname;
mkdir(base);
testCase.addTeardown(@() remove_folder(base));
previousDirectory = pwd;
testCase.addTeardown(@() cd(previousDirectory));
cd(base);
cfg = struct('StandaloneBuildCacheDir', base, 'VerboseLogging', false);

cleanup = st_enter_short_build_directory(cfg, 'TEST'); %#ok<NASGU>

verifyEqual(testCase, pwd, base);
end


function testPerCutRunsTheLoopFromTheShortFolder(testCase)
text = fileread(fullfile(st_project_root(), 'src', 'execution', ...
    'st_run_tests_per_cut.m'));
enterPosition = regexp(text, ...
    'shortBuildDirectory = st_enter_short_build_directory\(cfg, ''PER_CUT''\);', 'once');
loopPosition = regexp(text, '\nfor i = 1:n', 'once');
clearPosition = regexp(text, '\nclear shortBuildDirectory', 'once');
verifyNotEmpty(testCase, enterPosition);
verifyTrue(testCase, enterPosition < loopPosition);
verifyTrue(testCase, loopPosition < clearPosition);
end


function testSldvAndHarnessLoopsRunFromTheShortFolder(testCase)
root = st_project_root();
stages = { ...
    fullfile(root, 'src', 'sldv', 'st_prepare_sldv_targets.m'), 'SLDV'; ...
    fullfile(root, 'src', 'harness', 'st_create_harnesses.m'), 'HARNESS'};
for k = 1:size(stages, 1)
    text = fileread(stages{k, 1});
    enterPosition = regexp(text, ['shortBuildDirectory = ' ...
        'st_enter_short_build_directory\(cfg, ''' stages{k, 2} '''\);'], 'once');
    loopPosition = regexp(text, '\nfor i = 1:n', 'once');
    clearPosition = regexp(text, '\nclear shortBuildDirectory', 'once');
    verifyNotEmpty(testCase, enterPosition, stages{k, 1});
    verifyTrue(testCase, enterPosition < loopPosition, stages{k, 1});
    verifyTrue(testCase, loopPosition < clearPosition, stages{k, 1});
end
end


function testHarnessIsCreatedAndSavedFromTheCallerFolder(testCase)
% sltest.harness.create writes <Harness>_HarnessInputs.mat into pwd, and
% the short folder is deleted when the stage ends. Creating there left the
% Signal Editor pointing at a file that no longer existed.
text = fileread(fullfile(st_project_root(), 'src', 'harness', ...
    'st_create_harnesses.m'));
callerPosition = regexp(text, '\ncallerDirectory = pwd;', 'once');
enterPosition = regexp(text, ['shortBuildDirectory = ' ...
    'st_enter_short_build_directory\(cfg, ''HARNESS''\);'], 'once');
verifyNotEmpty(testCase, callerPosition);
verifyTrue(testCase, callerPosition < enterPosition);

createCalls = regexp(text, 'sltest\.harness\.create\(');
verifyNumElements(testCase, createCalls, 1);
verifyNotEmpty(testCase, regexp(text, ['run_in_folder\(callerDirectory, ' ...
    '@\(\) \.\.\.\s+sltest\.harness\.create\('], 'once'));

saveCalls = regexp(text, 'save_system\(');
verifyNumElements(testCase, saveCalls, 1);
verifyNotEmpty(testCase, regexp(text, ['run_in_folder\(callerDirectory, ' ...
    '@\(\) \.\.\.\s+save_system\(cfg\.TopModel\)\)'], 'once'));
end


function testSldvStagesOutputInTheShortBase(testCase)
text = fileread(fullfile(st_project_root(), 'src', 'sldv', ...
    'st_prepare_sldv_targets.m'));
verifyTrue(testCase, contains(text, ...
    'stagingDir = fullfile(st_short_build_base(cfg), ...'));
verifyFalse(testCase, contains(text, 'tempname(targetDir)'));
end


function testShortBuildBaseDefaultsToTempdir(testCase)
verifyEqual(testCase, st_short_build_base(struct()), ...
    fullfile(tempdir, 'stt_build'));
verifyEqual(testCase, ...
    st_short_build_base(struct('StandaloneBuildCacheDir', 'E:\b')), 'E:\b');
end


function remove_folder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end


function restore_session(directory, oldPath, config)
cd(directory);
try
    Simulink.fileGenControl('set', 'config', config);
catch
    Simulink.fileGenControl('reset');
end
path(oldPath);
end
