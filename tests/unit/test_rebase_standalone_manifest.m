function tests = test_rebase_standalone_manifest
%TEST_REBASE_STANDALONE_MANIFEST A moved run folder's recorded paths point at where it is now.
tests = functiontests(localfunctions);
end

function testFolderInPlaceIsLeftAlone(testCase)
root = temp_root(testCase);
run = fullfile(root, 'Secret_Run');
manifest = make_manifest(run, fullfile(root, 'Secret_Bundle'));
[rebased, movedFrom] = st_rebase_standalone_manifest(manifest, run);
verifyEqual(testCase, rebased, manifest);
verifyEqual(testCase, movedFrom, '');
end

function testMovedFolderPathsPointAtTheNewPlace(testCase)
root = temp_root(testCase);
old = fullfile(root, 'Secret_Old', 'Run1');
newRun = fullfile(root, 'Secret_New', 'Run1');
bundle = fullfile(root, 'Secret_Bundle');
[rebased, movedFrom] = st_rebase_standalone_manifest(make_manifest(old, bundle), newRun);
here = st_absolute_path(newRun);
verifyEqual(testCase, movedFrom, st_absolute_path(old));
verifyEqual(testCase, rebased.PipelineRoot, here);
verifyEqual(testCase, rebased.TestManagerFile, fullfile(here, 'TestManager', 'Secret_Top.mldatx'));
verifyEqual(testCase, rebased.ResultFile, fullfile(here, 'StandaloneCoverageResults.mldatx'));
verifyEqual(testCase, rebased.Targets(2).PackagedCVF, fullfile(here, '002_Secret', 'UT_REQ_Secret.cvf'));
verifyEqual(testCase, rebased.Targets(2).CoverageResult, fullfile(here, '002_Secret', 'UT_REQ_Secret.cvt'));
verifyEqual(testCase, rebased.Targets(1).OutputDirectory, fullfile(here, '001_Secret'));
% Outside the recorded root, empty, numbers and words stay as they are.
verifyEqual(testCase, rebased.BundleDirectory, bundle);
verifyEqual(testCase, rebased.Targets(1).TestReport, '');
verifyEqual(testCase, rebased.Targets(1).No, 1);
verifyEqual(testCase, rebased.Targets(1).StandaloneCUTPath, 'Secret_Top/Secret_CUT');
verifyEqual(testCase, rebased.Status, 'OK');
end

function testSiblingWithTheSamePrefixIsNotRebased(testCase)
root = temp_root(testCase);
old = fullfile(root, 'Run1');
manifest = make_manifest(old, fullfile(root, 'Bundle'));
manifest.BundleDirectory = fullfile(root, 'Run10', 'Secret');
rebased = st_rebase_standalone_manifest(manifest, fullfile(root, 'Moved', 'Run1'));
verifyEqual(testCase, rebased.BundleDirectory, manifest.BundleDirectory);
end

function testWordsStayWhenTheCurrentFolderIsInsideTheOldRoot(testCase)
% 'OK' must not resolve against a current folder that lies in the old root.
root = temp_root(testCase);
old = fullfile(root, 'Secret_Old');
mkdir(old);
testCase.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(old));
rebased = st_rebase_standalone_manifest(make_manifest(old, fullfile(root, 'B')), ...
    fullfile(root, 'Secret_New'));
verifyEqual(testCase, rebased.Status, 'OK');
verifyEqual(testCase, rebased.Targets(1).StandaloneCUTPath, 'Secret_Top/Secret_CUT');
end

function testManifestWithoutRootIsLeftAlone(testCase)
root = temp_root(testCase);
manifest = rmfield(make_manifest(fullfile(root, 'Old'), fullfile(root, 'B')), 'PipelineRoot');
[rebased, movedFrom] = st_rebase_standalone_manifest(manifest, fullfile(root, 'New'));
verifyEqual(testCase, rebased, manifest);
verifyEqual(testCase, movedFrom, '');
end

function root = temp_root(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
root = fixture.Folder;
end

function manifest = make_manifest(run, bundle)
manifest = struct('PipelineId', 'Run1', 'PipelineRoot', run, 'Status', 'OK', ...
    'TestManagerFile', fullfile(run, 'TestManager', 'Secret_Top.mldatx'), ...
    'ResultFile', fullfile(run, 'StandaloneCoverageResults.mldatx'), ...
    'BundleDirectory', bundle);
for k = 1:2
    folder = fullfile(run, sprintf('%03d_Secret', k));
    target = struct('No', k, 'OutputDirectory', folder, ...
        'PackagedCVF', fullfile(folder, 'UT_REQ_Secret.cvf'), ...
        'CoverageResult', fullfile(folder, 'UT_REQ_Secret.cvt'), ...
        'StandaloneCUTPath', 'Secret_Top/Secret_CUT', 'TestReport', '');
    manifest.Targets(k, 1) = target;
end
end
