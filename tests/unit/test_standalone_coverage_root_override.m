function tests = test_standalone_coverage_root_override
%TEST_STANDALONE_COVERAGE_ROOT_OVERRIDE Local override for the standalone
% coverage pipeline's output root, and the merge-safe runtime_target.mat
% writer it depends on.
tests = functiontests(localfunctions);
end


function testMergeSaveKeepsUnrelatedFields(testCase)
temporaryFile = [tempname '.mat'];
cleanup = onCleanup(@() delete_quiet(temporaryFile)); %#ok<NASGU>

TopModel = 'ExampleModel'; %#ok<NASGU>
ModelFile = 'C:\models\ExampleModel.slx'; %#ok<NASGU>
save(temporaryFile, 'TopModel', 'ModelFile');

st_save_runtime_target_fields(temporaryFile, ...
    struct('StandaloneCoverageRootDir', 'D:\stt_work'));

reloaded = load(temporaryFile);
verifyEqual(testCase, reloaded.TopModel, 'ExampleModel');
verifyEqual(testCase, reloaded.ModelFile, 'C:\models\ExampleModel.slx');
verifyEqual(testCase, reloaded.StandaloneCoverageRootDir, 'D:\stt_work');
end


function testMergeSaveOverwritesOnlyTheGivenField(testCase)
temporaryFile = [tempname '.mat'];
cleanup = onCleanup(@() delete_quiet(temporaryFile)); %#ok<NASGU>

st_save_runtime_target_fields(temporaryFile, ...
    struct('StandaloneCoverageRootDir', 'D:\first'));
st_save_runtime_target_fields(temporaryFile, ...
    struct('TopModel', 'ExampleModel'));
st_save_runtime_target_fields(temporaryFile, ...
    struct('StandaloneCoverageRootDir', 'D:\second'));

reloaded = load(temporaryFile);
verifyEqual(testCase, reloaded.TopModel, 'ExampleModel');
verifyEqual(testCase, reloaded.StandaloneCoverageRootDir, 'D:\second');
end


function testMergeSaveCreatesFileWhenMissing(testCase)
temporaryFile = [tempname '.mat'];
cleanup = onCleanup(@() delete_quiet(temporaryFile)); %#ok<NASGU>

verifyFalse(testCase, isfile(temporaryFile));
st_save_runtime_target_fields(temporaryFile, ...
    struct('StandaloneCoverageRootDir', 'D:\stt_work'));
verifyTrue(testCase, isfile(temporaryFile));

reloaded = load(temporaryFile);
verifyEqual(testCase, reloaded.StandaloneCoverageRootDir, 'D:\stt_work');
end


function testExistingWritersUseMergeSafeHelper(testCase)
% Each of these previously called save(cfg.RuntimeTargetFile, 'TopModel',
% 'ModelFile', 'SelectedAt'), which replaces the whole MAT-file and would
% silently erase an unrelated StandaloneCoverageRootDir override.
root = st_project_root();
files = { ...
    fullfile(root, 'src', 'targets', 'st_select_target_model.m'), ...
    fullfile(root, 'src', 'targets', 'st_find_target_paths.m'), ...
    fullfile(root, 'src', 'targets', 'st_export_subsystem_paths.m')};
for i = 1:numel(files)
    text = fileread(files{i});
    verifyTrue(testCase, contains(text, 'st_save_runtime_target_fields('));
end
end


function testConfigReadsStandaloneCoverageRootOverride(testCase)
root = st_project_root();
text = fileread(fullfile(root, 'src', 'config', 'st_config.m'));
verifyTrue(testCase, contains(text, 'StandaloneCoverageRootDir'));
verifyTrue(testCase, contains(text, ...
    "isfield(standaloneOverride, 'StandaloneCoverageRootDir')"));
end


function testSetAndClearOverrideRoundTrips(testCase)
cfg = st_config();
targetFile = cfg.RuntimeTargetFile;

hadOriginal = isfile(targetFile);
if hadOriginal
    originalContent = load(targetFile);
else
    originalContent = struct();
end
cleanup = onCleanup(@() restore_runtime_target( ...
    targetFile, hadOriginal, originalContent)); %#ok<NASGU>

overrideRoot = fullfile(tempdir, ['stt_root_' char(java.util.UUID.randomUUID)]);
cleanupRoot = onCleanup(@() rmdir_quiet(overrideRoot)); %#ok<NASGU>

updated = st_set_standalone_coverage_root(overrideRoot);
verifyEqual(testCase, ...
    string(updated.StandaloneCoverageRootDir), ...
    string(char(java.io.File(overrideRoot).getCanonicalPath())));
verifyTrue(testCase, isfolder(overrideRoot));

reread = st_config();
verifyEqual(testCase, ...
    string(reread.StandaloneCoverageRootDir), ...
    string(updated.StandaloneCoverageRootDir));

cleared = st_set_standalone_coverage_root('');
verifyEqual(testCase, cleared.StandaloneCoverageRootDir, ...
    fullfile(st_project_root(), 'result', 'standalone_coverage'));
end


function restore_runtime_target(targetFile, hadOriginal, originalContent)
if hadOriginal
    save(targetFile, '-struct', 'originalContent');
else
    delete_quiet(targetFile);
end
end


function delete_quiet(path)
if isfile(path)
    delete(path);
end
end


function rmdir_quiet(path)
if isfolder(path)
    rmdir(path, 's');
end
end
