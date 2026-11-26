function tests = test_standalone_run_folder
%TEST_STANDALONE_RUN_FOLDER A chosen folder becomes the opener's OutputRoot and PipelineId.
tests = functiontests(localfunctions);
end

function testRunFolderGivesParentAndName(testCase)
root = temp_root(testCase);
run = make_folder(fullfile(root, 'Secret_Root'), '20261126_101530_123_ab12cd34', 'pipeline-manifest.json');
[outputRoot, pipelineId] = st_standalone_run_folder(run);
verifyEqual(testCase, outputRoot, st_absolute_path(fullfile(root, 'Secret_Root')));
verifyEqual(testCase, pipelineId, '20261126_101530_123_ab12cd34');
end

function testTrailingSeparatorAndDotInName(testCase)
root = temp_root(testCase);
run = make_folder(root, 'Secret.Run', 'pipeline-manifest.json');
[outputRoot, pipelineId] = st_standalone_run_folder(string([run filesep]));
verifyEqual(testCase, outputRoot, st_absolute_path(root));
verifyEqual(testCase, pipelineId, 'Secret.Run');
end

function testRootFolderMeansLatest(testCase)
root = temp_root(testCase);
standaloneRoot = make_folder(root, 'Secret_Root', 'latest.json');
[outputRoot, pipelineId] = st_standalone_run_folder(standaloneRoot);
verifyEqual(testCase, outputRoot, st_absolute_path(standaloneRoot));
verifyEqual(testCase, pipelineId, 'LATEST');
end

function testOtherFolderIsRejectedWithoutItsPath(testCase)
root = temp_root(testCase);
other = make_folder(root, 'Secret_Other', 'notes.txt');
try
    st_standalone_run_folder(other);
    verifyFail(testCase, 'An unrelated folder must be rejected.');
catch ME
    verifyEqual(testCase, ME.identifier, 'simtest:StandaloneFolderUnknown');
    verifyFalse(testCase, contains(ME.message, 'Secret'));
end
end

function testMissingFolderIsRejectedWithoutItsPath(testCase)
root = temp_root(testCase);
for value = {fullfile(root, 'Secret_Missing'), '', "  ", 0}
    try
        st_standalone_run_folder(value{1});
        verifyFail(testCase, 'A missing folder must be rejected.');
    catch ME
        verifyEqual(testCase, ME.identifier, 'simtest:StandaloneFolderMissing');
        verifyFalse(testCase, contains(ME.message, 'Secret'));
    end
end
end

function root = temp_root(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
root = fixture.Folder;
end

function folder = make_folder(parent, name, marker)
folder = fullfile(parent, name);
mkdir(folder);
fid = fopen(fullfile(folder, marker), 'w');
fprintf(fid, '{}');
fclose(fid);
end
