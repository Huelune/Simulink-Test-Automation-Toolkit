function tests = test_remove_moved_check_copy
%TEST_REMOVE_MOVED_CHECK_COPY The moved-folder check's copy goes, path entries with it.
tests = functiontests(localfunctions);
end

function testCopyAndItsPathEntriesGo(testCase)
root = fullfile(temp_root(testCase), 'Secret_Root');
mkdir(root);
inner = fullfile([root '_moved_check'], 'Secret_Run', 'Secret_Cut');
mkdir(inner);
addpath(inner);
testCase.addTeardown(@() rmpath_quietly(inner));
[removed, folder] = st_remove_moved_check_copy(struct('StandaloneCoverageRootDir', root));
verifyTrue(testCase, removed);
verifyFalse(testCase, isfolder(folder));
verifyFalse(testCase, any(strcmpi(strsplit(path, pathsep), inner)));
verifyTrue(testCase, isfolder(root));
end

function testNoCopyRemovesNothing(testCase)
root = fullfile(temp_root(testCase), 'Secret_Root');
mkdir(root);
[removed, folder] = st_remove_moved_check_copy(struct('StandaloneCoverageRootDir', root));
verifyFalse(testCase, removed);
verifyEqual(testCase, folder, [st_absolute_path(root) '_moved_check']);
end

function testTrailingSeparatorStillMeansNextToTheRoot(testCase)
root = fullfile(temp_root(testCase), 'Secret_Root');
mkdir(fullfile(root, '_moved_check'));
[removed, folder] = st_remove_moved_check_copy(struct('StandaloneCoverageRootDir', [root filesep]));
verifyFalse(testCase, removed);
verifyEqual(testCase, folder, [st_absolute_path(root) '_moved_check']);
verifyTrue(testCase, isfolder(fullfile(root, '_moved_check')));
end

function root = temp_root(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
root = fixture.Folder;
end

function rmpath_quietly(folder)
if any(strcmpi(strsplit(path, pathsep), folder)), rmpath(folder); end
end
