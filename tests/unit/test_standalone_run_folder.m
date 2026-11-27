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

function testFolderInsideRunFindsTheRun(testCase)
root = temp_root(testCase);
run = make_folder(root, 'Secret_Run', 'pipeline-manifest.json');
inner = fullfile(run, 'Secret_Cut', 'Secret_Deeper');
mkdir(inner);
[outputRoot, pipelineId, how] = st_standalone_run_folder(inner);
verifyEqual(testCase, outputRoot, st_absolute_path(root));
verifyEqual(testCase, pipelineId, 'Secret_Run');
verifyEqual(testCase, how, 'INSIDE');
end

function testFolderHoldingOneRunFindsIt(testCase)
root = temp_root(testCase);
holder = fullfile(root, 'Secret_Desktop');
make_folder(holder, 'Secret_Run', 'pipeline-manifest.json');
make_folder(holder, 'Secret_Other', 'notes.txt');
[outputRoot, pipelineId, how] = st_standalone_run_folder(holder);
verifyEqual(testCase, outputRoot, st_absolute_path(holder));
verifyEqual(testCase, pipelineId, 'Secret_Run');
verifyEqual(testCase, how, 'HOLDS');
end

function testFolderHoldingSeveralRunsIsRejected(testCase)
root = temp_root(testCase);
holder = fullfile(root, 'Secret_Desktop');
make_folder(holder, 'Secret_RunA', 'pipeline-manifest.json');
make_folder(holder, 'Secret_RunB', 'pipeline-manifest.json');
verify_rejected(testCase, holder, 'simtest:StandaloneFolderSeveralRuns');
end

function testTeamTreeIsRejected(testCase)
root = temp_root(testCase);
tree = fullfile(root, 'Secret_TopModel');
make_folder(tree, '테스트 케이스', 'Secret.mat');
make_folder(tree, '테스트 보고서', 'Secret.mldatx');
verify_rejected(testCase, tree, 'simtest:StandaloneFolderTeamTree');
verify_rejected(testCase, fullfile(tree, '테스트 보고서'), 'simtest:StandaloneFolderTeamTree');
end

function verify_rejected(testCase, folder, identifier)
try
    st_standalone_run_folder(folder);
    verifyFail(testCase, 'The folder must be rejected.');
catch ME
    verifyEqual(testCase, ME.identifier, identifier);
    verifyFalse(testCase, contains(ME.message, 'Secret'));
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
