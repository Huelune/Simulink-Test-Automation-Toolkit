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
