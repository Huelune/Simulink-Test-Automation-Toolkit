function tests = test_other_toolkit_path_entries
%TEST_OTHER_TOOLKIT_PATH_ENTRIES st_setup takes another toolkit clone off the path.
tests = functiontests(localfunctions);
end

function testOtherCloneEntriesGoAndTheRestStays(testCase)
base = temp_root(testCase);
mine = make_clone(fullfile(base, 'Secret_ModelA_toolkit'));
other = make_clone(fullfile(base, 'Secret_ModelB_toolkit'));
unrelated = fullfile(base, 'Secret_Project', 'lib');
entries = {mine, fullfile(mine, 'src', 'shared'), other, fullfile(other, 'src'), ...
    fullfile(other, 'diagnostics', 'matlab'), unrelated, [other '_moved_check']};
found = st_other_toolkit_path_entries(mine, entries, ...
    {fullfile(mine, 'st_setup.m'); fullfile(other, 'st_setup.m')});
verifyEqual(testCase, found, {other, fullfile(other, 'src'), fullfile(other, 'diagnostics', 'matlab')});
end

function testWorktreeInsideAnotherCloneKeepsItsOwnEntries(testCase)
base = temp_root(testCase);
outer = make_clone(fullfile(base, 'Secret_Main'));
inner = make_clone(fullfile(outer, '.claude', 'worktrees', 'Secret_Tree'));
entries = {outer, fullfile(outer, 'src'), inner, fullfile(inner, 'src')};
found = st_other_toolkit_path_entries(inner, entries, ...
    {fullfile(inner, 'st_setup.m'); fullfile(outer, 'st_setup.m')});
verifyEqual(testCase, found, {outer, fullfile(outer, 'src')});
end

function testFolderWithOnlySetupIsNotAClone(testCase)
base = temp_root(testCase);
mine = make_clone(fullfile(base, 'Secret_Mine'));
stub = fullfile(base, 'Secret_Stub');
mkdir(stub);
write_file(fullfile(stub, 'st_setup.m'));
found = st_other_toolkit_path_entries(mine, {mine, stub}, ...
    {fullfile(mine, 'st_setup.m'); fullfile(stub, 'st_setup.m')});
verifyEmpty(testCase, found);
end

function root = temp_root(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
root = fixture.Folder;
end

function folder = make_clone(folder)
mkdir(fullfile(folder, 'src'));
write_file(fullfile(folder, 'st_setup.m'));
write_file(fullfile(folder, 'VERSION.txt'));
end

function write_file(file)
fid = fopen(file, 'w');
fprintf(fid, '%% stub\n');
fclose(fid);
end
