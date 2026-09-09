function info = st_export_test_bundle(varargin)
%ST_EXPORT_TEST_BUNDLE Export a self-contained, repeatable test bundle.
%
%   INFO = ST_EXPORT_TEST_BUNDLE() copies the saved model (including its
%   internal Harnesses), model dependencies, Test File, test inputs, and
%   the latest integrated report into result/exports. The source project is
%   never changed. The exported runner creates a fresh execution workspace
%   for every rerun, so the exported template is also left unchanged.
%
%   Name-value options:
%     Destination   Parent folder for the bundle.
%     RunId         'LATEST' or an existing result/runs folder name.
%     CreateArchive Create a ZIP beside the bundle folder (default true).
%     IncludeReferenceReport
%                   Include the selected integrated report (default true).
%                   Verification snapshots set this false so an existing
%                   report is not required before an isolated runtime run.
%     Profile       'REPRODUCIBLE' (default) or internal 'ASSET'. Use
%                   st_export_test_asset_bundle for asset management.

%   The source model and Test File must be saved before export. Missing
%   model dependencies stop the export instead of creating a partial
%   reproducibility bundle.

%   This is a standalone command. It is not called by st_run_workflow or
%   st_run_existing_harness_workflow.


p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'Destination', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'RunId', 'LATEST', @(x) ischar(x) || isstring(x));
addParameter(p, 'CreateArchive', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'IncludeReferenceReport', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'Profile', 'REPRODUCIBLE', ...
    @(x) ischar(x) || isstring(x));
parse(p, varargin{:});

cfg = st_require_runtime_target();
destination = strtrim(char(string(p.Results.Destination)));
if isempty(destination)
    destination = cfg.ExportRootDir;
end
runId = strtrim(char(string(p.Results.RunId)));
createArchive = p.Results.CreateArchive;
includeReferenceReport = p.Results.IncludeReferenceReport;
profile = normalize_export_profile(p.Results.Profile);
reproducible = strcmp(profile, 'REPRODUCIBLE');
if reproducible
    exportTitle = 'Reproducible Test Bundle Export';
else
    exportTitle = 'Test Asset Bundle Export';
end

totalTimer = tic;
fprintf('\n============================================\n');
fprintf('%s\n', exportTitle);
fprintf('Model       : %s\n', cfg.TopModel);
fprintf('Destination : %s\n', destination);
fprintf('Run         : %s\n', runId);
fprintf('Profile     : %s\n', profile);
fprintf('Archive     : %s\n', on_off_text(createArchive));
fprintf('Start       : %s\n', console_timestamp_text());
fprintf('============================================\n');

st_log(cfg, 'INFO', ...
    ['Export Test Bundle start | Model=%s | Destination=%s | ' ...
     'RunId=%s | Profile=%s | Archive=%d | ReferenceReport=%d'], ...
    cfg.TopModel, destination, runId, profile, ...
    logical(createArchive), logical(includeReferenceReport));

currentStage = 'Validate Export Sources';
stageTimer = start_step(currentStage);

try
requiredFiles = {cfg.ModelFile, cfg.TestFile, cfg.ManagementExcel};
requiredLabels = {'model', 'Test File', 'management Excel'};
for i = 1:numel(requiredFiles)
    if ~isfile(requiredFiles{i})
        error('simtest:ExportSourceMissing', ...
            'Required %s is missing: %s', ...
            requiredLabels{i}, requiredFiles{i});
    end
end

assert_saved_model(cfg);
assert_saved_test_file(cfg);
sourceModelSignature = struct();
sourceTestSignature = struct();
if reproducible
    sourceModelSignature = st_file_signature(cfg.ModelFile);
    sourceTestSignature = st_file_signature(cfg.TestFile);
else
    fprintf('Source SHA-256 validation: SKIP (asset profile)\n');
end
targets = st_load_targets(cfg.OnlyEnabled);
fprintf('Targets      : %d\n', height(targets));
finish_step(currentStage, stageTimer);

currentStage = 'Discover Model Dependencies';
stageTimer = start_step(currentStage);
st_log(cfg, 'DEBUG', 'Dependency analysis start | Model=%s', ...
    cfg.ModelFile);
if reproducible
    [dependencyFiles, missingDependencies] = ...
        discover_dependencies(cfg.ModelFile);
    if ~isempty(missingDependencies)
        error('simtest:ExportDependencyMissing', ...
            'Cannot create a complete bundle. Missing dependencies: %s', ...
            strjoin(missingDependencies, ', '));
    end
else
    dependencyFiles = {canonical_path(cfg.ModelFile)};
    fprintf(['Model dependency analysis: SKIP ' ...
        '(asset profile copies the Harness container model only)\n']);
end
assert_saved_dependency_models(dependencyFiles);
st_log(cfg, 'DEBUG', 'Dependency analysis done | count=%d', ...
    numel(dependencyFiles));
fprintf('Dependencies : %d\n', numel(dependencyFiles));
finish_step(currentStage, stageTimer);

currentStage = 'Resolve Reference Report';
stageTimer = start_step(currentStage);
if includeReferenceReport
    [referenceRunId, referenceRunDirectory] = ...
        resolve_reference_run(cfg, runId);
    fprintf('Reference Run : %s\n', referenceRunId);
else
    referenceRunId = 'NONE';
    referenceRunDirectory = '';
    fprintf('Reference report: SKIP\n');
end
finish_step(currentStage, stageTimer);

currentStage = 'Prepare Bundle Template';
stageTimer = start_step(currentStage);
if ~isfolder(destination)
    mkdir(destination);
end
bundleId = make_bundle_id();
stagingDirectory = tempname(destination);
mkdir(stagingDirectory);
stagingCleanup = onCleanup(@() remove_staging(stagingDirectory)); %#ok<NASGU>

templateDirectory = fullfile(stagingDirectory, 'template');
workspaceDirectory = fullfile(templateDirectory, 'workspace');
mkdir(templateDirectory);
mkdir(workspaceDirectory);

projectRoot = st_project_root();
if reproducible
    copyfile_checked(fullfile(projectRoot, 'st_setup.m'), ...
        fullfile(templateDirectory, 'st_setup.m'));
    copyfile_checked(fullfile(projectRoot, 'VERSION.txt'), ...
        fullfile(templateDirectory, 'VERSION.txt'));
    copyfile_checked(fullfile(projectRoot, 'src'), ...
        fullfile(templateDirectory, 'src'));
else
    fprintf('Automation runtime copy: SKIP (asset profile)\n');
end

copyfile_checked(cfg.ManagementExcel, ...
    fullfile(templateDirectory, 'TestManagement.xlsx'));
testFileName = [cfg.TopModel '.mldatx'];
copyfile_checked(cfg.TestFile, ...
    fullfile(templateDirectory, testFileName));

dependencyRoot = st_export_common_root(dependencyFiles);
dependencyInventory = repmat(empty_dependency(), 0, 1);
modelBundlePath = '';
for i = 1:numel(dependencyFiles)
    relativePath = st_export_relative_path( ...
        dependencyFiles{i}, dependencyRoot);
    outputPath = fullfile(workspaceDirectory, relativePath);
    copyfile_checked(dependencyFiles{i}, outputPath);
    item = empty_dependency();
    item.BundlePath = bundle_path(stagingDirectory, outputPath);
    item.Role = 'MODEL_DEPENDENCY';
    if same_path(dependencyFiles{i}, cfg.ModelFile)
        item.Role = 'MODEL';
        modelBundlePath = item.BundlePath;
    end
    dependencyInventory(end + 1, 1) = item; %#ok<AGROW>
    fprintf('[%d/%d] COPY %s\n', ...
        i, numel(dependencyFiles), item.BundlePath);
end
if isempty(modelBundlePath)
    error('simtest:ExportModelCopyMissing', ...
        'The selected model was not included in dependency analysis.');
end
finish_step(currentStage, stageTimer);

currentStage = 'Collect Target Inputs';
stageTimer = start_step(currentStage);
sldvManifestBundlePath = '';
targetInventory = collect_target_inputs( ...
    targets, cfg, stagingDirectory, templateDirectory);
if isfile(cfg.SldvManifestFile)
    sldvManifestOutput = fullfile( ...
        templateDirectory, 'result', 'sldv', 'sldv_manifest.mat');
    copyfile_checked(cfg.SldvManifestFile, sldvManifestOutput);
    sldvManifestBundlePath = ...
        bundle_path(stagingDirectory, sldvManifestOutput);
end
finish_step(currentStage, stageTimer);

currentStage = 'Copy Reference Report';
stageTimer = start_step(currentStage);
if includeReferenceReport
    referenceOutput = fullfile( ...
        stagingDirectory, 'reference-report', referenceRunId);
    copyfile_checked(referenceRunDirectory, referenceOutput);
    fprintf('Reference report copied: %s\n', referenceRunId);
else
    fprintf('Reference report: SKIP\n');
end
finish_step(currentStage, stageTimer);

currentStage = 'Build Bundle Manifest';
stageTimer = start_step(currentStage);
resourceDirectory = fullfile(projectRoot, 'resources', 'export_bundle');
if reproducible
    runnerOutput = fullfile(stagingDirectory, 'run_exported_tests.m');
    copyfile_checked(fullfile(resourceDirectory, 'run_exported_tests.m'), ...
        runnerOutput);
    products = discover_products(dependencyFiles);
    readmeResource = 'README.bundle.ko.md';
else
    products = repmat(struct('Name', '', 'Version', ''), 0, 1);
    readmeResource = 'README.assets.ko.md';
    fprintf('Toolbox dependency analysis: SKIP (asset profile)\n');
end
manifest = struct();
manifest.Version = 1;
manifest.BundleId = bundleId;
manifest.Profile = profile;
manifest.CreatedAt = timestamp_text();
manifest.MATLABRelease = version('-release');
manifest.TopModel = cfg.TopModel;
manifest.TemplateRoot = 'template';
manifest.ModelFile = modelBundlePath;
manifest.TestFile = ['template/' testFileName];
manifest.ManagementExcel = 'template/TestManagement.xlsx';
manifest.SldvManifest = sldvManifestBundlePath;
manifest.ReferenceRunId = referenceRunId;
if includeReferenceReport
    manifest.ReferenceReport = ...
        ['reference-report/' portable_path(referenceRunId)];
else
    manifest.ReferenceReport = '';
end
manifest.Dependencies = dependencyInventory;
manifest.Targets = targetInventory;
manifest.RequiredProducts = products;
manifest.Policy = struct( ...
    'Reproducible', logical(reproducible), ...
    'SourceUnchanged', true, ...
    'TemplateImmutable', logical(reproducible), ...
    'FreshWorkspacePerRun', logical(reproducible), ...
    'ExactMATLABReleaseRequiredByDefault', logical(reproducible), ...
    'PreparationWorkflowIncluded', false, ...
    'ReferenceReportIncluded', logical(includeReferenceReport));

readmeTemplate = fileread( ...
    fullfile(resourceDirectory, readmeResource));
readmeText = strrep(readmeTemplate, '{{BUNDLE_ID}}', bundleId);
readmeText = strrep(readmeText, '{{MATLAB_RELEASE}}', ...
    manifest.MATLABRelease);
readmeText = strrep(readmeText, '{{TOP_MODEL}}', cfg.TopModel);
readmeText = strrep(readmeText, '{{REFERENCE_RUN}}', referenceRunId);
write_text(fullfile(stagingDirectory, 'README.md'), readmeText);

if reproducible
    manifest.Files = inventory_files(stagingDirectory, ...
        {'manifest.json'});
else
    manifest.Files = inventory_files_light(stagingDirectory, ...
        {'manifest.json'});
    fprintf('Bundle file SHA-256 inventory: SKIP (asset profile)\n');
end
write_json(fullfile(stagingDirectory, 'manifest.json'), manifest);

if reproducible
    assert_source_unchanged(cfg.ModelFile, sourceModelSignature);
    assert_source_unchanged(cfg.TestFile, sourceTestSignature);
end
assert_saved_dependency_models(dependencyFiles);
fprintf('Inventory files : %d\n', numel(manifest.Files));
finish_step(currentStage, stageTimer);

currentStage = 'Finalize Bundle';
stageTimer = start_step(currentStage);
finalDirectory = fullfile(destination, bundleId);
if isfolder(finalDirectory) || isfile(finalDirectory)
    error('simtest:ExportDestinationExists', ...
        'Export destination already exists: %s', finalDirectory);
end
[ok, message] = movefile(stagingDirectory, finalDirectory);
if ~ok
    error('simtest:ExportMoveFailed', ...
        'Cannot finalize export bundle: %s', message);
end
finish_step(currentStage, stageTimer);

archivePath = '';
if createArchive
    currentStage = 'Create ZIP Archive';
    stageTimer = start_step(currentStage);
    archivePath = [finalDirectory '.zip'];
    zip(archivePath, bundleId, destination);
    finish_step(currentStage, stageTimer);
else
    fprintf('\nCreate ZIP Archive: SKIP (CreateArchive=false)\n');
end

info = struct( ...
    'BundleId', bundleId, ...
    'Profile', profile, ...
    'Reproducible', logical(reproducible), ...
    'BundleDirectory', finalDirectory, ...
    'Archive', archivePath, ...
    'Manifest', fullfile(finalDirectory, 'manifest.json'), ...
    'ReferenceRunId', referenceRunId, ...
    'TargetCount', height(targets), ...
    'DependencyCount', numel(dependencyFiles), ...
    'MATLABRelease', manifest.MATLABRelease);

st_log(cfg, 'INFO', ...
    'Export Test Bundle complete | Bundle=%s | elapsed=%.3f sec', ...
    bundleId, toc(totalTimer));

fprintf('\n============================================\n');
fprintf('Test Bundle Export Complete\n');
fprintf('End     : %s\n', console_timestamp_text());
fprintf('Elapsed : %s\n', elapsed_text(toc(totalTimer)));
fprintf('Folder  : %s\n', finalDirectory);
if ~isempty(archivePath)
    fprintf('ZIP     : %s\n', archivePath);
end
if reproducible
    fprintf('Run     : run_exported_tests\n');
else
    fprintf('Use     : test asset management; rerun is not supported\n');
end
fprintf('============================================\n');

catch ME
    fail_step(currentStage, stageTimer, ME);
    st_log(cfg, 'ERROR', ...
        'Export Test Bundle failed | Stage=%s | %s: %s', ...
        currentStage, ME.identifier, ME.message);
    fprintf('\n============================================\n');
    fprintf('Test Bundle Export Failed\n');
    fprintf('Stage   : %s\n', currentStage);
    fprintf('End     : %s\n', console_timestamp_text());
    fprintf('Elapsed : %s\n', elapsed_text(toc(totalTimer)));
    fprintf('============================================\n');
    rethrow(ME);
end
end

function assert_saved_model(cfg)
if bdIsLoaded(cfg.TopModel) && ...
        strcmp(get_param(cfg.TopModel, 'Dirty'), 'on')
    error('simtest:ExportUnsavedModel', ...
        ['The model has unsaved changes. Save it before export so the ' ...
         'bundle and the current project represent the same state.']);
end
end

function assert_saved_test_file(cfg)
try
    testFile = sltest.testmanager.TestFile(cfg.TestFile);
catch ME
    error('simtest:ExportTestFileOpenFailed', ...
        'Cannot open the Test File before export: %s', ME.message);
end
if isprop(testFile, 'Dirty') && logical(testFile.Dirty)
    error('simtest:ExportUnsavedTestFile', ...
        'The Test File has unsaved changes. Save it before export.');
end
end

function assert_saved_dependency_models(files)
for i = 1:numel(files)
    [~, modelName, extension] = fileparts(files{i});
    if ~ismember(lower(extension), {'.slx', '.mdl'}) || ...
            ~bdIsLoaded(modelName)
        continue;
    end
    if strcmp(get_param(modelName, 'Dirty'), 'on')
        error('simtest:ExportUnsavedDependencyModel', ...
            'A dependency model has unsaved changes: %s', files{i});
    end
end
end

function [files, missing] = discover_dependencies(modelFile)
try
    [files, missing] = dependencies.fileDependencyAnalysis( ...
        modelFile, 'AnalyzeToolboxFiles', false);
catch ME
    error('simtest:ExportDependencyAnalysisFailed', ...
        'Model dependency analysis failed: %s', ME.message);
end
files = text_list(files);
files = files(~cellfun('isempty', files));
files = cellfun(@canonical_path, files, 'UniformOutput', false);
modelFile = canonical_path(modelFile);
if ~any(cellfun(@(path) same_path(path, modelFile), files))
    files = [{modelFile}; files];
end
missing = text_list(missing);
missing = missing(~cellfun('isempty', missing));
files = unique(files, 'stable');
missing = unique(missing, 'stable');
end

function products = discover_products(files)
products = repmat(struct('Name', '', 'Version', ''), 0, 1);
try
    names = dependencies.toolboxDependencyAnalysis(files);
    names = text_list(names);
    for i = 1:numel(names)
        products(end + 1, 1) = struct( ...
            'Name', names{i}, 'Version', ''); %#ok<AGROW>
    end
catch
    % Product discovery is informative. Runtime API checks remain the
    % authoritative validation on the recipient machine.
end
end

function inventory = collect_target_inputs( ...
        targets, cfg, bundleRoot, templateRoot)
inventory = repmat(empty_target(), 0, 1);
for i = 1:height(targets)
    row = targets(i, :);
    item = empty_target();
    item.No = double(row.No);
    item.CUTName = char(row.CUTName);
    item.CUTPath = st_normalize_cut_path(row.CUTPath, cfg.TopModel);
    item.HarnessName = char(row.HarnessName);
    item.TestCaseName = char(row.TestCaseName);
    item.SldvMode = char(row.SldvMode);

    targetTimer = tic;
    fprintf('[%d/%d] START %s | Harness=%s | SLDV=%s\n', ...
        i, height(targets), item.CUTName, item.HarnessName, item.SldvMode);
    st_log(cfg, 'DEBUG', ...
        '[ExportTarget %d/%d] start | CUT=%s | Harness=%s | SLDV=%s', ...
        i, height(targets), item.CUTName, item.HarnessName, item.SldvMode);

    try
    if strcmpi(item.SldvMode, 'OFF')
        directInports = find_system( ...
            item.CUTPath, 'SearchDepth', 1, ...
            'Type', 'Block', 'BlockType', 'Inport');
        if isempty(directInports)
            inventory(end + 1, 1) = item; %#ok<AGROW>
            fprintf('[%d/%d] OK    %s | no external input | %s\n', ...
                i, height(targets), item.CUTName, ...
                elapsed_text(toc(targetTimer)));
            st_log(cfg, 'DEBUG', ...
                ['[ExportTarget %d/%d] done | CUT=%s | ' ...
                 'input=NONE | elapsed=%.3f sec'], ...
                i, height(targets), item.CUTName, toc(targetTimer));
            continue;
        end
    end

    harnessLoaded = false;
    try
        sltest.harness.load(item.CUTPath, item.HarnessName);
        harnessLoaded = true;
        block = st_find_signal_editor_block(item.HarnessName);
        signalFile = st_resolve_data_file( ...
            get_param(block, 'Filename'), cfg.TopModel);
        outputDirectory = fullfile(templateRoot, 'inputs', ...
            'signal_editor', target_folder(item));
        outputPath = fullfile(outputDirectory, file_name(signalFile));
        copyfile_checked(signalFile, outputPath);
        item.SignalEditorInput = bundle_path(bundleRoot, outputPath);
    catch ME
        if harnessLoaded
            close_harness(item.CUTPath, item.HarnessName);
        end
        error('simtest:ExportHarnessInputFailed', ...
            'Cannot export Signal Editor input for target %g (%s): %s', ...
            item.No, item.CUTName, ME.message);
    end
    close_harness(item.CUTPath, item.HarnessName);

    if ~strcmpi(item.SldvMode, 'OFF')
        profile = st_get_sldv_profile(row, cfg);
        outputDirectory = fullfile(templateRoot, 'inputs', ...
            'sldv', target_folder(item));
        item.EffectiveSldvInput = copy_optional_input( ...
            profile, 'EffectiveDataFile', outputDirectory, bundleRoot);
        item.SourceSldvInput = copy_optional_input( ...
            profile, 'SourceDataFile', outputDirectory, bundleRoot);
    end
    inventory(end + 1, 1) = item; %#ok<AGROW>
    fprintf('[%d/%d] OK    %s | %s\n', ...
        i, height(targets), item.CUTName, ...
        elapsed_text(toc(targetTimer)));
    st_log(cfg, 'DEBUG', ...
        '[ExportTarget %d/%d] done | CUT=%s | elapsed=%.3f sec', ...
        i, height(targets), item.CUTName, toc(targetTimer));
    catch ME
        st_log(cfg, 'ERROR', ...
            '[ExportTarget %d/%d] failed | CUT=%s | %s: %s', ...
            i, height(targets), item.CUTName, ME.identifier, ME.message);
        fprintf('[%d/%d] FAIL  %s | %s\n', ...
            i, height(targets), item.CUTName, ME.message);
        rethrow(ME);
    end
end
end

function output = copy_optional_input(profile, fieldName, outputDir, root)
output = '';
if ~isfield(profile, fieldName)
    return;
end
source = char(string(profile.(fieldName)));
if isempty(source) || ~isfile(source)
    return;
end
prefix = lower(regexprep(fieldName, 'DataFile$', ''));
path = fullfile(outputDir, [prefix '_' file_name(source)]);
copyfile_checked(source, path);
output = bundle_path(root, path);
end

function [runId, directory] = resolve_reference_run(cfg, requested)
if strcmpi(requested, 'LATEST')
    if ~isfile(cfg.LatestReportPointer)
        error('simtest:ExportReportMissing', ...
            ['Latest report pointer is missing. Run the tests and generate ' ...
             'the integrated report before export: %s'], ...
            cfg.LatestReportPointer);
    end
    value = jsondecode(fileread(cfg.LatestReportPointer));
    runId = char(string(value.RunId));
    directory = char(string(value.RunDirectory));
else
    runId = requested;
    directory = fullfile(cfg.TestRunRootDir, runId);
end
if isempty(runId) || ~strcmp(runId, st_export_safe_name(runId))
    error('simtest:ExportRunIdInvalid', ...
        'Report RunId must be a portable folder name: %s', runId);
end
try
    st_export_relative_path(directory, cfg.TestRunRootDir);
catch
    error('simtest:ExportReportOutsideRoot', ...
        'Reference report must be inside %s: %s', ...
        cfg.TestRunRootDir, directory);
end
if isempty(runId) || ~isfolder(directory)
    error('simtest:ExportReportMissing', ...
        'Reference report run is missing: %s', directory);
end
end

function inventory = inventory_files(root, excluded)
listing = dir(fullfile(root, '**', '*'));
inventory = repmat(struct( ...
    'BundlePath', '', 'SHA256', '', 'Bytes', 0), 0, 1);
for i = 1:numel(listing)
    if listing(i).isdir
        continue;
    end
    path = fullfile(listing(i).folder, listing(i).name);
    relative = bundle_path(root, path);
    if any(strcmp(relative, excluded))
        continue;
    end
    signature = st_file_signature(path);
    item = struct( ...
        'BundlePath', relative, ...
        'SHA256', signature.SHA256, ...
        'Bytes', signature.Bytes);
    inventory(end + 1, 1) = item; %#ok<AGROW>
end
end

function inventory = inventory_files_light(root, excluded)
listing = dir(fullfile(root, '**', '*'));
inventory = repmat(struct( ...
    'BundlePath', '', 'SHA256', '', 'Bytes', 0), 0, 1);
for i = 1:numel(listing)
    if listing(i).isdir
        continue;
    end
    path = fullfile(listing(i).folder, listing(i).name);
    relative = bundle_path(root, path);
    if any(strcmp(relative, excluded))
        continue;
    end
    item = struct( ...
        'BundlePath', relative, ...
        'SHA256', '', ...
        'Bytes', double(listing(i).bytes));
    inventory(end + 1, 1) = item; %#ok<AGROW>
end
end

function copyfile_checked(source, destination)
parent = fileparts(destination);
if ~isfolder(parent)
    mkdir(parent);
end
[ok, message] = copyfile(source, destination, 'f');
if ~ok
    error('simtest:ExportCopyFailed', ...
        'Cannot copy %s to %s: %s', source, destination, message);
end
end

function write_json(path, value)
write_text(path, jsonencode(value, 'PrettyPrint', true));
end

function write_text(path, value)
fileId = fopen(path, 'w', 'n', 'UTF-8');
if fileId < 0
    error('simtest:ExportWriteFailed', 'Cannot write file: %s', path);
end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, '%s', value);
end

function assert_source_unchanged(path, original)
current = st_file_signature(path);
if ~strcmp(current.SHA256, original.SHA256)
    error('simtest:ExportChangedSource', ...
        'Export unexpectedly changed a source file: %s', path);
end
end

function close_harness(owner, harness)
try
    sltest.harness.close(owner, harness);
catch
end
end

function remove_staging(path)
if isfolder(path)
    try
        rmdir(path, 's');
    catch
    end
end
end

function value = make_bundle_id()
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
uuid = char(java.util.UUID.randomUUID());
value = sprintf('%s_%s', stamp, uuid(1:8));
end

function value = timestamp_text()
value = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end

function timerValue = start_step(label)
fprintf('\n============================================\n');
fprintf('%s\n', label);
fprintf('START : %s\n', console_timestamp_text());
fprintf('============================================\n');
timerValue = tic;
end

function finish_step(label, timerValue)
fprintf('DONE    : %s\n', label);
fprintf('ELAPSED : %s\n', elapsed_text(toc(timerValue)));
end

function fail_step(label, timerValue, exception)
fprintf('FAILED  : %s\n', label);
fprintf('ERROR   : %s\n', exception.message);
fprintf('ELAPSED : %s\n', elapsed_text(toc(timerValue)));
end

function value = console_timestamp_text()
value = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function value = elapsed_text(secondsValue)
hoursValue = floor(secondsValue / 3600);
minutesValue = floor(mod(secondsValue, 3600) / 60);
secondsPart = mod(secondsValue, 60);
value = sprintf('%02d:%02d:%06.3f', ...
    hoursValue, minutesValue, secondsPart);
end

function value = on_off_text(enabled)
if enabled
    value = 'ON';
else
    value = 'OFF';
end
end

function value = normalize_export_profile(value)
text = string(value);
allowed = {'REPRODUCIBLE', 'ASSET'};
if ~isscalar(text)
    error('simtest:InvalidExportProfile', ...
        'Export Profile must be a scalar text value.');
end
value = upper(strtrim(char(text)));
if isempty(value) || ~ismember(value, allowed)
    error('simtest:InvalidExportProfile', ...
        'Invalid export Profile: %s. Allowed: %s.', ...
        value, strjoin(allowed, ', '));
end
end

function value = target_folder(item)
value = sprintf('%04d_%s', round(item.No), ...
    st_export_safe_name(item.CUTName));
end

function value = file_name(path)
[namePath, name, extension] = fileparts(path);
if isempty(namePath) && isempty(name)
    value = 'input.mat';
else
    value = [name extension];
end
end

function value = bundle_path(root, path)
value = portable_path(st_export_relative_path(path, root));
end

function value = portable_path(path)
value = strrep(char(path), '\', '/');
end

function value = canonical_path(path)
value = char(java.io.File(char(path)).getCanonicalPath());
end

function tf = same_path(left, right)
left = canonical_path(left);
right = canonical_path(right);
if ispc
    tf = strcmpi(left, right);
else
    tf = strcmp(left, right);
end
end

function values = text_list(value)
if isempty(value)
    values = {};
elseif ischar(value)
    values = {value};
else
    values = cellstr(string(value(:)));
end
end

function value = empty_dependency()
value = struct('BundlePath', '', 'Role', '');
end

function value = empty_target()
value = struct( ...
    'No', 0, ...
    'CUTName', '', ...
    'CUTPath', '', ...
    'HarnessName', '', ...
    'TestCaseName', '', ...
    'SldvMode', '', ...
    'SignalEditorInput', '', ...
    'EffectiveSldvInput', '', ...
    'SourceSldvInput', '');
end
