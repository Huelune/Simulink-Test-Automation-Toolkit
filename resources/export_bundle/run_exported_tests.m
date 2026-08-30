function info = run_exported_tests(varargin)
%RUN_EXPORTED_TESTS Run this exported test bundle in a fresh workspace.
%
%   RUN_EXPORTED_TESTS validates the bundle, copies template/ into a new
%   executions/<timestamp>/workspace folder, updates portable paths only in
%   that copy, runs the Test File, and creates a new integrated report.
%
%   RUN_EXPORTED_TESTS('AllowReleaseMismatch', true) bypasses the default
%   exact MATLAB release check. Results may then differ from the reference.

p = inputParser;
addParameter(p, 'AllowReleaseMismatch', false, ...
    @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

bundleRoot = fileparts(mfilename('fullpath'));
manifestPath = fullfile(bundleRoot, 'manifest.json');
if ~isfile(manifestPath)
    error('simtest:BundleManifestMissing', ...
        'manifest.json is missing: %s', manifestPath);
end
manifest = jsondecode(fileread(manifestPath));

validate_release(manifest, p.Results.AllowReleaseMismatch);
validate_files(bundleRoot, manifest.Files);
prepare_existing_session(bundleRoot, manifest);

executionId = make_execution_id();
executionRoot = fullfile(bundleRoot, 'executions', executionId);
workRoot = fullfile(executionRoot, 'workspace');
templateRoot = fullfile(bundleRoot, char(manifest.TemplateRoot));
if ~isfolder(fileparts(workRoot))
    mkdir(fileparts(workRoot));
end
[ok, message] = copyfile(templateRoot, workRoot);
if ~ok
    error('simtest:BundleWorkspaceCopyFailed', ...
        'Cannot create execution workspace: %s', message);
end

modelFile = work_path(bundleRoot, workRoot, manifest.ModelFile);
TopModel = char(manifest.TopModel); %#ok<NASGU>
ModelFile = modelFile; %#ok<NASGU>
save(fullfile(workRoot, 'runtime_target.mat'), 'TopModel', 'ModelFile');

previousDirectory = pwd;
pathCleanup = onCleanup(@() restore_environment(previousDirectory, workRoot)); %#ok<NASGU>
cd(workRoot);
addpath(workRoot, '-begin');
clear st_setup st_config st_project_root
st_setup();
addpath(genpath(fullfile(workRoot, 'workspace')), '-begin');

rewrite_sldv_manifest(bundleRoot, workRoot, manifest);
rewrite_signal_editor_paths(bundleRoot, workRoot, manifest, modelFile);

[~, ~, runContext] = st_run_generated_tests();
workflowResult = table( ...
    string('EXPORTED_BUNDLE'), string('OK'), ...
    string(['Bundle ' char(manifest.BundleId)]), ...
    'VariableNames', {'Stage', 'Status', 'Message'});
workflowPlan = table();
reportInfo = st_generate_test_report( ...
    runContext, workflowResult, workflowPlan);

info = struct( ...
    'ExecutionId', executionId, ...
    'ExecutionDirectory', executionRoot, ...
    'Workspace', workRoot, ...
    'Report', reportInfo, ...
    'ReferenceRunId', char(manifest.ReferenceRunId), ...
    'CompletedAt', timestamp_text());
write_json(fullfile(executionRoot, 'execution.json'), info);

fprintf('\nExported bundle test completed\n');
fprintf('Execution : %s\n', executionRoot);
fprintf('Report    : %s\n', reportInfo.RunDirectory);
fprintf('Reference : %s\n', ...
    fullfile(bundleRoot, char(manifest.ReferenceReport)));
end

function validate_release(manifest, allowMismatch)
expected = char(manifest.MATLABRelease);
actual = version('-release');
if ~strcmp(expected, actual) && ~allowMismatch
    error('simtest:BundleReleaseMismatch', ...
        ['This bundle was exported with MATLAB %s, but this session is ' ...
         '%s. Use the same release or explicitly call ' ...
         'run_exported_tests(''AllowReleaseMismatch'', true).'], ...
        expected, actual);
end
end

function validate_files(root, files)
for i = 1:numel(files)
    path = fullfile(root, char(files(i).BundlePath));
    if ~isfile(path)
        error('simtest:BundleFileMissing', ...
            'Bundle file is missing: %s', path);
    end
    actual = file_sha256(path);
    expected = char(files(i).SHA256);
    if ~strcmpi(actual, expected)
        error('simtest:BundleChecksumMismatch', ...
            'Bundle file was changed: %s', path);
    end
end
end

function prepare_existing_session(bundleRoot, manifest)
executionRoot = fullfile(bundleRoot, 'executions');
topModel = char(manifest.TopModel);
if bdIsLoaded(topModel)
    loadedFile = get_param(topModel, 'FileName');
    if ~is_under_root(loadedFile, executionRoot)
        error('simtest:BundleModelAlreadyLoaded', ...
            ['A model with the same name is loaded outside this bundle. ' ...
             'Save and close it before running the bundle: %s'], loadedFile);
    end
    if strcmp(get_param(topModel, 'Dirty'), 'on')
        save_system(topModel);
    end
    close_system(topModel, 0);
end

openFiles = sltest.testmanager.getTestFiles;
for i = 1:numel(openFiles)
    try
        if is_under_root(openFiles(i).FilePath, executionRoot)
            if openFiles(i).Dirty
                saveToFile(openFiles(i));
            end
            close(openFiles(i));
        end
    catch ME
        error('simtest:BundlePreviousTestFileCloseFailed', ...
            'Cannot close a previous bundle Test File: %s', ME.message);
    end
end
end

function rewrite_sldv_manifest(bundleRoot, workRoot, manifest)
if isempty(char(manifest.SldvManifest))
    return;
end
manifestPath = work_path( ...
    bundleRoot, workRoot, manifest.SldvManifest);
if ~isfile(manifestPath)
    return;
end
loaded = load(manifestPath, 'manifest');
if ~isfield(loaded, 'manifest')
    error('simtest:BundleSldvManifestInvalid', ...
        'SLDV manifest does not contain manifest: %s', manifestPath);
end
sldvManifest = loaded.manifest;
for i = 1:numel(manifest.Targets)
    target = manifest.Targets(i);
    for j = 1:numel(sldvManifest.Profiles)
        if profile_matches(sldvManifest.Profiles(j), target)
            effective = char(target.EffectiveSldvInput);
            source = char(target.SourceSldvInput);
            if ~isempty(effective)
                path = work_path(bundleRoot, workRoot, effective);
                sldvManifest.Profiles(j).EffectiveDataFile = path;
                sldvManifest.Profiles(j).SignalEditorDataFile = path;
            end
            if ~isempty(source) && ...
                    isfield(sldvManifest.Profiles, 'SourceDataFile')
                sldvManifest.Profiles(j).SourceDataFile = ...
                    work_path(bundleRoot, workRoot, source);
            end
        end
    end
end
manifest = sldvManifest; %#ok<NASGU>
save(manifestPath, 'manifest');
end

function tf = profile_matches(profile, target)
tf = double(profile.No) == double(target.No) && ...
    strcmp(char(profile.CUTName), char(target.CUTName)) && ...
    strcmp(char(profile.HarnessName), char(target.HarnessName)) && ...
    strcmp(char(profile.TestCaseName), char(target.TestCaseName));
end

function rewrite_signal_editor_paths(bundleRoot, workRoot, manifest, modelFile)
load_system(modelFile);
cleanup = onCleanup(@() close_model_quietly(char(manifest.TopModel))); %#ok<NASGU>
loadedFile = get_param(char(manifest.TopModel), 'FileName');
if ~same_path(loadedFile, modelFile)
    error('simtest:BundleWrongModelLoaded', ...
        'A different model with the same name is loaded: %s', loadedFile);
end

for i = 1:numel(manifest.Targets)
    target = manifest.Targets(i);
    input = char(target.SignalEditorInput);
    if isempty(input)
        continue;
    end
    owner = st_normalize_cut_path( ...
        char(target.CUTPath), char(manifest.TopModel));
    harness = char(target.HarnessName);
    sltest.harness.load(owner, harness);
    try
        block = st_find_signal_editor_block(harness);
        set_param(block, 'Filename', ...
            work_path(bundleRoot, workRoot, input));
        save_system(harness);
        sltest.harness.close(owner, harness);
    catch ME
        close_harness_quietly(owner, harness);
        rethrow(ME);
    end
end
save_system(char(manifest.TopModel));
end

function path = work_path(bundleRoot, workRoot, bundlePath)
bundlePath = char(bundlePath);
prefix = ['template' filesep];
native = strrep(bundlePath, '/', filesep);
if startsWith(native, prefix)
    relative = extractAfter(string(native), strlength(prefix));
    path = fullfile(workRoot, char(relative));
else
    path = fullfile(bundleRoot, native);
end
end

function restore_environment(previousDirectory, workRoot)
cd(previousDirectory);
try
    rmpath(genpath(workRoot));
catch
end
end

function close_harness_quietly(owner, harness)
try
    sltest.harness.close(owner, harness);
catch
end
end

function close_model_quietly(model)
try
    close_system(model, 0);
catch
end
end

function value = make_execution_id()
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
uuid = char(java.util.UUID.randomUUID());
value = sprintf('%s_%s', stamp, uuid(1:8));
end

function value = timestamp_text()
value = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end

function value = file_sha256(path)
fileId = fopen(path, 'rb');
if fileId < 0
    error('simtest:BundleHashFailed', 'Cannot read file: %s', path);
end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
md = java.security.MessageDigest.getInstance('SHA-256');
while true
    data = fread(fileId, 1024 * 1024, '*uint8');
    if isempty(data)
        break;
    end
    md.update(typecast(data(:), 'int8'));
end
raw = typecast(int8(md.digest()), 'uint8');
value = lower(reshape(dec2hex(raw, 2).', 1, []));
end

function tf = same_path(left, right)
left = char(java.io.File(char(left)).getCanonicalPath());
right = char(java.io.File(char(right)).getCanonicalPath());
if ispc
    tf = strcmpi(left, right);
else
    tf = strcmp(left, right);
end
end

function tf = is_under_root(path, root)
path = char(java.io.File(char(path)).getCanonicalPath());
root = char(java.io.File(char(root)).getCanonicalPath());
if ispc
    path = lower(path);
    root = lower(root);
end
prefix = root;
if isempty(prefix) || prefix(end) ~= filesep
    prefix = [prefix filesep];
end
tf = strcmp(path, root) || startsWith(path, prefix);
end

function write_json(path, value)
fileId = fopen(path, 'w', 'n', 'UTF-8');
if fileId < 0
    error('simtest:BundleWriteFailed', 'Cannot write file: %s', path);
end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, '%s', jsonencode(value, 'PrettyPrint', true));
end
