function tests = test_old_standalone_items
%TEST_OLD_STANDALONE_ITEMS Only what the toolkit made under the standalone root is picked for deletion.
tests = functiontests(localfunctions);
end

function testPicksRunsTreesAndTheLatestPointer(testCase)
root = temp_root(testCase);
write_file(fullfile(root, '20261126_101530_123_ab12cd34', 'pipeline-manifest.json'));
write_file(fullfile(root, '20261126_101530_123_ab12cd34', '001_Secret', 'UT_REQ_Secret.cvf'));
write_file(fullfile(root, 'Secret_Top', '테스트 보고서', 'Secret_Top.mldatx'));
mkdir(fullfile(root, 'Secret_Top', '프로젝트'));
write_file(fullfile(root, 'latest.json'));
[items, kept] = st_old_standalone_items(root);
verifyEqual(testCase, sort(items.Kind), ["LATEST"; "RUN"; "TREE"]);
verifyEqual(testCase, kept, 0);
verifyTrue(testCase, all(startsWith(items.Path, string(root))));
end

function testLeavesEverythingElse(testCase)
root = temp_root(testCase);
write_file(fullfile(root, 'Secret_Notes.txt'));
write_file(fullfile(root, 'Secret_Other', 'a.txt'));
mkdir(fullfile(root, 'Secret_Empty'));
% A tree with anything beside the categories is not a tree.
mkdir(fullfile(root, 'Secret_Top', '테스트 보고서'));
write_file(fullfile(root, 'Secret_Top', 'notes.txt'));
% A run folder without its manifest is not a run folder.
write_file(fullfile(root, '20261126_101530_123_ab12cd34', 'CoverageSummary.xlsx'));
[items, kept] = st_old_standalone_items(root);
verifyEmpty(testCase, items);
verifyEqual(testCase, kept, 5);
end

function testMissingRootGivesNothing(testCase)
root = temp_root(testCase);
[items, kept] = st_old_standalone_items(fullfile(root, 'Secret_Missing'));
verifyEmpty(testCase, items);
verifyEqual(testCase, kept, 0);
end

function testNothingIsDeleted(testCase)
root = temp_root(testCase);
write_file(fullfile(root, 'run1', 'pipeline-manifest.json'));
write_file(fullfile(root, 'latest.json'));
st_old_standalone_items(root);
verifyTrue(testCase, isfile(fullfile(root, 'run1', 'pipeline-manifest.json')));
verifyTrue(testCase, isfile(fullfile(root, 'latest.json')));
end

function root = temp_root(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
root = fixture.Folder;
end

function write_file(path)
folder = fileparts(path);
if ~isfolder(folder), mkdir(folder); end
fid = fopen(path, 'w');
fwrite(fid, 'x');
fclose(fid);
end
