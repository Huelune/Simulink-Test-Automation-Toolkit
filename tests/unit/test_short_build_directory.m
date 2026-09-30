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


function remove_folder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
