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
%     ExecutionModelMode
%                   'ORIGINAL' (default) or 'STANDALONE_HARNESS'. The
%                   standalone mode is available only for REPRODUCIBLE.
%     AnalyzeProducts
%                   Record the required MathWorks products in the manifest
%                   (default true). The analysis loads every dependency
%                   model and can take longer than the rest of the export.
%                   RequiredProducts is a README hint that no code reads
%                   back, so false is safe when the bundle is urgent.

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
addParameter(p, 'ExecutionModelMode', 'ORIGINAL', ...
    @(x) ischar(x) || isstring(x));
% Toolbox analysis loads every dependency model and can outlast the rest of
% the export. Nothing reads RequiredProducts back; it is a hint printed in
% the bundle README, so it must be possible to opt out.
addParameter(p, 'AnalyzeProducts', true, ...
    @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

% Export operates on saved files and manages any temporary model loads in
% its own scoped helpers. Do not let runtime-target validation load the
% source before the caller-visible entry state is captured below.
cfg = st_require_runtime_target('LoadModel', false);
% Capture the caller-visible model state before dependency analysis or any
% Harness API can load the model as an implementation side effect. Later
% cleanup must use this baseline, not the state observed midway through the
% export, because that intermediate state may already be contaminated.
topModelWasLoadedAtEntry = bdIsLoaded(cfg.TopModel);
modelSessionCleanup = onCleanup(@() restore_top_model_load_state( ...
    cfg.TopModel, topModelWasLoadedAtEntry)); %#ok<NASGU>
destination = strtrim(char(string(p.Results.Destination)));
if isempty(destination)
    destination = cfg.ExportRootDir;
end
runId = strtrim(char(string(p.Results.RunId)));
createArchive = p.Results.CreateArchive;
includeReferenceReport = p.Results.IncludeReferenceReport;
profile = normalize_export_profile(p.Results.Profile);
reproducible = strcmp(profile, 'REPRODUCIBLE');
executionModelMode = normalize_execution_model_mode( ...
    p.Results.ExecutionModelMode);
analyzeProducts = logical(p.Results.AnalyzeProducts);
if ~reproducible && ~strcmp(executionModelMode, 'ORIGINAL')
    error('simtest:StandaloneHarnessRequiresReproducibleProfile', ...
        ['ExecutionModelMode=STANDALONE_HARNESS is supported only for ' ...
         'Profile=REPRODUCIBLE.']);
end
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
fprintf('Model Mode  : %s\n', executionModelMode);
fprintf('Archive     : %s\n', on_off_text(createArchive));
fprintf('Products    : %s\n', on_off_text(analyzeProducts));
fprintf('Start       : %s\n', console_timestamp_text());
fprintf('============================================\n');

st_log(cfg, 'INFO', ...
    ['Export Test Bundle start | Model=%s | Destination=%s | ' ...
     'RunId=%s | Profile=%s | ExecutionModelMode=%s | ' ...
     'Archive=%d | ReferenceReport=%d'], ...
    cfg.TopModel, destination, runId, profile, executionModelMode, ...
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
sourceHarnessInventory = strings(0,1);
if reproducible
    sourceModelSignature = st_file_signature(cfg.ModelFile);
    sourceTestSignature = st_file_signature(cfg.TestFile);
    sourceHarnessInventory = harness_inventory(cfg);
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
    if strcmp(executionModelMode, 'STANDALONE_HARNESS')
        % The delivery runs only exported Harness models. Analysing every
        % branch of the source Top Model is both expensive and can reject
        % unrelated Function Caller names before the scoped models exist.
        % Keep the source model as a configuration artifact, then inspect
        % the generated standalone models below.
        dependencyFiles = {canonical_path(cfg.ModelFile)};
        st_log(cfg, 'INFO', ...
            'Whole-model dependency analysis deferred | Scope=STANDALONE_HARNESS');
        fprintf('Dependency scope: deferred to generated standalone Harness models\n');
    else
        [dependencyFiles, missingDependencies] = ...
            discover_dependencies(cfg.ModelFile);
        missingDependencies = drop_in_model_name_false_positives( ...
            missingDependencies, cfg.ModelFile, cfg.TopModel, cfg);
        if ~isempty(missingDependencies)
            error('simtest:ExportDependencyMissing', ...
                'Cannot create a complete bundle. Missing dependencies: %s', ...
                strjoin(missingDependencies, ', '));
        end
    end
else
    dependencyFiles = {canonical_path(cfg.ModelFile)};
    fprintf(['Model dependency analysis: SKIP ' ...
        '(asset profile copies the Harness container model only)\n']);
end
assert_saved_dependency_models(dependencyFiles);
normalize_top_model_load_state(cfg, topModelWasLoadedAtEntry, ...
    'dependency analysis');
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
% tempname() returns a long GUID-based name (~38 chars). The export tree
% nests several more fixed segments below this (template/workspace/
% standalone/{CUTName}/...), so a deep project path combined with a long
% CUT name can push the total path past the Windows 260-character limit
% (MATLAB:cd:DirectoryNameTooLong). A short random token is unique enough
% for a directory that only needs to avoid colliding with other concurrent
% exports into the same destination.
stagingDirectory = short_staging_directory(destination);
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

modelBundlePath = '';
finish_step(currentStage, stageTimer);

standaloneDetails = repmat(empty_standalone_detail(), height(targets), 1);
if strcmp(executionModelMode, 'STANDALONE_HARNESS')
    currentStage = 'Export Standalone Harness Models';
    stageTimer = start_step(currentStage);
    standaloneDirectory = fullfile(workspaceDirectory, 'standalone');
    [~, standaloneDetails] = st_export_standalone_harnesses( ...
        cfg.ModelFile, cfg.TopModel, targets, standaloneDirectory, ...
        stagingDirectory, 'LogConfig', cfg);
    finish_step(currentStage, stageTimer);

    currentStage = 'Discover Standalone Harness Dependencies';
    stageTimer = start_step(currentStage);
    standaloneDependencies = discover_standalone_harness_dependencies( ...
        standaloneDetails, stagingDirectory, workspaceDirectory, cfg);
    dependencyFiles = unique([{canonical_path(cfg.ModelFile)}; ...
        standaloneDependencies(:)], 'stable');
    assert_saved_dependency_models(dependencyFiles);
    st_log(cfg, 'INFO', ...
        'Standalone dependency analysis complete | Scope=STANDALONE_HARNESS | Files=%d', ...
        numel(dependencyFiles));
    fprintf('Standalone dependencies : %d\n', numel(dependencyFiles) - 1);
    finish_step(currentStage, stageTimer);
end

currentStage = 'Copy Bundle Model Dependencies';
stageTimer = start_step(currentStage);
[dependencyInventory, modelBundlePath] = copy_dependencies_to_workspace( ...
    dependencyFiles, cfg.ModelFile, workspaceDirectory, stagingDirectory, ...
    executionModelMode);
if isempty(modelBundlePath)
    error('simtest:ExportModelCopyMissing', ...
        'The selected model was not included in dependency analysis.');
end
finish_step(currentStage, stageTimer);

currentStage = 'Collect Target Inputs';
stageTimer = start_step(currentStage);
sldvManifestBundlePath = '';
targetInventory = collect_target_inputs( ...
    targets, cfg, stagingDirectory, templateDirectory, ...
    topModelWasLoadedAtEntry);
for i = 1:numel(targetInventory)
    targetInventory(i).StandaloneModel = ...
        standaloneDetails(i).StandaloneModel;
    targetInventory(i).StandaloneModelFile = ...
        standaloneDetails(i).StandaloneModelFile;
    targetInventory(i).StandaloneCUTPath = ...
        standaloneDetails(i).StandaloneCUTPath;
end
if isfile(cfg.SldvManifestFile)
    sldvManifestOutput = fullfile( ...
        templateDirectory, 'result', 'sldv', 'sldv_manifest.mat');
    copyfile_checked(cfg.SldvManifestFile, sldvManifestOutput);
    sldvManifestBundlePath = ...
        bundle_path(stagingDirectory, sldvManifestOutput);
end
normalize_top_model_load_state(cfg, topModelWasLoadedAtEntry, ...
    'target input collection');
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
productAnalysis = 'ANALYZED';
if reproducible
    runnerOutput = fullfile(stagingDirectory, 'run_exported_tests.m');
    copyfile_checked(fullfile(resourceDirectory, 'run_exported_tests.m'), ...
        runnerOutput);
    products = repmat(struct('Name', '', 'Version', ''), 0, 1);
    if analyzeProducts
        taskTimer = begin_task(cfg, 'Toolbox products', ...
            'models=%d', numel(dependencyFiles));
        products = discover_products(dependencyFiles);
        end_task(cfg, 'Toolbox products', taskTimer, ...
            'found=%d', numel(products));
    else
        productAnalysis = 'SKIPPED';
        fprintf('%-22s : SKIP   AnalyzeProducts=false\n', ...
            'Toolbox products');
        st_log(cfg, 'INFO', ...
            'Toolbox product analysis skipped | AnalyzeProducts=false');
    end
    readmeResource = 'README.bundle.ko.md';
else
    products = repmat(struct('Name', '', 'Version', ''), 0, 1);
    productAnalysis = 'NOT_APPLICABLE';
    readmeResource = 'README.assets.ko.md';
    fprintf('Toolbox dependency analysis: SKIP (asset profile)\n');
end
manifest = struct();
if reproducible
    manifest.Version = 2;
else
    manifest.Version = 1;
end
manifest.BundleId = bundleId;
manifest.Profile = profile;
manifest.ExecutionModelMode = executionModelMode;
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
    'SequentialStandaloneExecution', ...
        strcmp(executionModelMode, 'STANDALONE_HARNESS'), ...
    'DependencyScope', dependency_scope(executionModelMode), ...
    'ProductAnalysis', productAnalysis, ...
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
    taskTimer = begin_task(cfg, 'Bundle SHA-256', 'root=%s', ...
        stagingDirectory);
    manifest.Files = inventory_files(stagingDirectory, ...
        {'manifest.json'}, cfg);
    end_task(cfg, 'Bundle SHA-256', taskTimer, ...
        'files=%d', numel(manifest.Files));
else
    manifest.Files = inventory_files_light(stagingDirectory, ...
        {'manifest.json'});
    fprintf('Bundle file SHA-256 inventory: SKIP (asset profile)\n');
end
write_json(fullfile(stagingDirectory, 'manifest.json'), manifest);

if reproducible
    % harness_inventory reloads the source Top Model when it is closed, so
    % this check is not free on a large model.
    taskTimer = begin_task(cfg, 'Source unchanged check', ...
        'model=%s', cfg.TopModel);
    assert_source_unchanged(cfg.ModelFile, sourceModelSignature);
    assert_source_unchanged(cfg.TestFile, sourceTestSignature);
    if ~isequal(harness_inventory(cfg), sourceHarnessInventory)
        error('simtest:ExportChangedHarnessInventory', ...
            'Export unexpectedly changed the source Harness inventory.');
    end
    end_task(cfg, 'Source unchanged check', taskTimer, 'result=OK');
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
    % Compression time tracks the bundle size, which the manifest already
    % measured. Print it so a multi-minute archive is expected, not a hang.
    bundleBytes = 0;
    if ~isempty(manifest.Files)
        bundleBytes = sum([manifest.Files.Bytes]);
    end
    taskTimer = begin_task(cfg, 'ZIP archive', '%.1f MB in %d files', ...
        bundleBytes / 1e6, numel(manifest.Files));
    zip(archivePath, bundleId, destination);
    end_task(cfg, 'ZIP archive', taskTimer, 'file=%s', archivePath);
    finish_step(currentStage, stageTimer);
else
    fprintf('\nCreate ZIP Archive: SKIP (CreateArchive=false)\n');
end

info = struct( ...
    'BundleId', bundleId, ...
    'Profile', profile, ...
    'ExecutionModelMode', executionModelMode, ...
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

function files = discover_standalone_harness_dependencies( ...
        details, stagingDirectory, workspaceDirectory, cfg)
%DISCOVER_STANDALONE_HARNESS_DEPENDENCIES Analyse delivered models only.
%
% The Top Model is intentionally not analysed here: in standalone mode it
% only supplies configuration and target metadata at runtime. Each unique
% exported Harness model is the executable delivery boundary.
files = {};
seenModels = strings(0,1);
for i = 1:numel(details)
    relative = char(string(details(i).StandaloneModelFile));
    model = char(string(details(i).StandaloneModel));
    if isempty(relative) || isempty(model)
        error('simtest:ExportStandaloneDependencyModelMissing', ...
            'Standalone Harness dependency inspection lacks model metadata.');
    end
    modelFile = fullfile(stagingDirectory, strrep(relative, '/', filesep));
    key = string(lower(canonical_path(modelFile)));
    if any(seenModels == key), continue; end
    seenModels(end+1,1) = key; %#ok<AGROW>
    if ~isfile(modelFile)
        error('simtest:ExportStandaloneDependencyModelMissing', ...
            'Standalone Harness model is missing: %s', modelFile);
    end
    st_log(cfg, 'DEBUG', ...
        'Standalone dependency analysis start | Model=%s | File=%s', ...
        model, modelFile);
    [modelFiles, missing] = discover_dependencies(modelFile);
    missing = drop_in_model_name_false_positives( ...
        missing, modelFile, model, cfg);
    if ~isempty(missing)
        error('simtest:ExportStandaloneDependencyMissing', ...
            ['Cannot create a complete standalone Harness delivery. ' ...
             'Model=%s | Missing dependencies: %s'], ...
            model, strjoin(missing, ', '));
    end
    for j = 1:numel(modelFiles)
        candidate = canonical_path(modelFiles{j});
        % The exported model is already inside template/workspace. Do not
        % re-copy it or let it influence the external dependency root.
        if is_under_directory(candidate, workspaceDirectory), continue; end
        files{end+1,1} = candidate; %#ok<AGROW>
    end
    st_log(cfg, 'DEBUG', ...
        'Standalone dependency analysis complete | Model=%s | Files=%d', ...
        model, numel(modelFiles));
end
files = unique(files, 'stable');
end

function [inventory, modelBundlePath] = copy_dependencies_to_workspace( ...
        files, sourceModelFile, workspaceDirectory, stagingDirectory, mode)
%COPY_DEPENDENCIES_TO_WORKSPACE Copy the union after its scope is known.
dependencyRoot = st_export_common_root(files);
inventory = repmat(empty_dependency(), 0, 1);
modelBundlePath = '';
for i = 1:numel(files)
    relativePath = st_export_relative_path(files{i}, dependencyRoot);
    outputPath = fullfile(workspaceDirectory, relativePath);
    copyfile_checked(files{i}, outputPath);
    item = empty_dependency();
    item.BundlePath = bundle_path(stagingDirectory, outputPath);
    item.Role = 'MODEL_DEPENDENCY';
    if strcmp(mode, 'STANDALONE_HARNESS')
        item.Role = 'STANDALONE_MODEL_DEPENDENCY';
    end
    if same_path(files{i}, sourceModelFile)
        item.Role = 'MODEL';
        modelBundlePath = item.BundlePath;
    end
    inventory(end + 1, 1) = item; %#ok<AGROW>
    fprintf('[%d/%d] COPY %s\n', i, numel(files), item.BundlePath);
end
end

function missing = drop_in_model_name_false_positives( ...
        missing, modelFile, modelName, cfg)
%DROP_IN_MODEL_NAME_FALSE_POSITIVES Ignore missing entries that are really
% in-model block names.
%
% dependencies.fileDependencyAnalysis can report a Simulink Function name
% (called through a Function Caller block) as a missing external file even
% though the function is fully defined inside the model being exported.
% An entry is dropped only when a block with that exact name actually
% exists somewhere in the model, so a genuinely missing external file with
% a name that happens to collide is not silently ignored.
if isempty(missing)
    return;
end
wasLoadedBefore = bdIsLoaded(modelName);
if wasLoadedBefore && ~same_path(get_param(modelName, 'FileName'), modelFile)
    error('simtest:ExportDependencyInspectionModelConflict', ...
        'A different model named %s is loaded: %s', ...
        modelName, get_param(modelName, 'FileName'));
end
if ~wasLoadedBefore
    load_system(modelFile);
end
inspectionCleanup = onCleanup(@() restore_top_model_load_state( ...
    modelName, wasLoadedBefore)); %#ok<NASGU>
st_log(cfg, 'DEBUG', ...
    'Dependency false-positive inspection start | Candidates=%d', ...
    numel(missing));
keep = true(size(missing));
for i = 1:numel(missing)
    name = missing{i};
    try
        found = find_system(modelName, 'FindAll', 'on', 'Name', name);
    catch
        found = [];
    end
    if ~isempty(found)
        keep(i) = false;
        st_log(cfg, 'WARN', ...
            ['[Export] Ignoring dependency-analysis false positive: ' ...
             '"%s" matches an in-model block name and is already ' ...
             'included with the copied model.'], name);
    end
end
missing = missing(keep);
clear inspectionCleanup;
st_log(cfg, 'DEBUG', ...
    'Dependency false-positive inspection complete | Remaining=%d', ...
    numel(missing));
end

function value = dependency_scope(executionModelMode)
if strcmp(executionModelMode, 'STANDALONE_HARNESS')
    value = 'STANDALONE_HARNESS_MODELS';
else
    value = 'WHOLE_TOP_MODEL';
end
end

function tf = is_under_directory(path, directory)
path = canonical_path(path);
directory = canonical_path(directory);
if ispc
    path = lower(path); directory = lower(directory);
end
prefix = directory;
if prefix(end) ~= filesep, prefix = [prefix filesep]; end
tf = strcmp(path,directory) || startsWith(path,prefix);
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
        targets, cfg, bundleRoot, templateRoot, topModelWasLoadedAtEntry)
inventory = repmat(empty_target(), 0, 1);
% A subsystem owner path is not a valid Simulink object until its top model
% is loaded. Load the saved source explicitly for this scope rather than
% relying on sltest.harness.load to do so: R2025b rejects an unloaded
% subsystem path before it can resolve the Harness. Cleanup still uses the
% export-entry baseline, so a model opened only for input collection is
% closed again before the standalone bundle runner starts.
collectCleanup = onCleanup( ...
    @() restore_top_model_load_state( ...
        cfg.TopModel, topModelWasLoadedAtEntry)); %#ok<NASGU>
if ~bdIsLoaded(cfg.TopModel)
    st_log(cfg, 'DEBUG', ...
        'Target input source model load start | Model=%s', cfg.TopModel);
    load_system(cfg.ModelFile);
    st_log(cfg, 'DEBUG', ...
        'Target input source model load complete | Model=%s', cfg.TopModel);
end
for i = 1:height(targets)
    row = targets(i, :);
    item = empty_target();
    item.No = double(row.No);
    item.CUTName = char(row.CUTName);
    item.CUTPath = st_normalize_cut_path(row.CUTPath, cfg.TopModel);
    item.HarnessName = char(row.HarnessName);
    item.TestCaseName = char(row.TestCaseName);
    item.SldvMode = char(row.SldvMode);
    item.DataFileFormat = char(row.DataFileFormat);
    item.MatVariableName = char(row.MatVariableName);
    item.ExpectedUpdateMode = char(row.ExpectedUpdateMode);
    item.CoverageFilterMode = char(row.CoverageFilterMode);
    item.CoverageBoundaryMode = char(row.CoverageBoundaryMode);
    item.CoverageFilterAction = char(row.CoverageFilterAction);
    item.CoverageFilterRationale = char(row.CoverageFilterRationale);

    targetTimer = tic;
    fprintf('[%d/%d] START %s | Harness=%s | SLDV=%s\n', ...
        i, height(targets), item.CUTName, item.HarnessName, item.SldvMode);
    st_log(cfg, 'DEBUG', ...
        '[ExportTarget %d/%d] start | CUT=%s | Harness=%s | SLDV=%s', ...
        i, height(targets), item.CUTName, item.HarnessName, item.SldvMode);

    try
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
        if strcmpi(item.SldvMode, 'OFF') && ...
                strcmp(ME.identifier, 'simtest:SignalEditorBlockMissing')
            st_log(cfg, 'WARN', ...
                ['[ExportTarget %d/%d] Signal Editor input omitted | ' ...
                 'CUT=%s | Harness=%s | reason=no Signal Editor block'], ...
                i, height(targets), item.CUTName, item.HarnessName);
        else
            error('simtest:ExportHarnessInputFailed', ...
                'Cannot export Signal Editor input for target %g (%s): %s', ...
                item.No, item.CUTName, ME.message);
        end
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
clear collectCleanup;
end

function normalize_top_model_load_state(cfg, wasLoadedAtEntry, context)
%NORMALIZE_TOP_MODEL_LOAD_STATE Remove only exporter-created load state.
st_log(cfg, 'DEBUG', ...
    'Export model session normalization start | Context=%s | LoadedAtEntry=%d', ...
    context, logical(wasLoadedAtEntry));
restore_top_model_load_state(cfg.TopModel, wasLoadedAtEntry);
if ~wasLoadedAtEntry && bdIsLoaded(cfg.TopModel)
    dirtyText = '';
    if strcmp(get_param(cfg.TopModel, 'Dirty'), 'on')
        dirtyText = ' The model became dirty and was not discarded.';
    end
    st_log(cfg, 'ERROR', ...
        ['Export model session normalization failed | Context=%s | ' ...
         'Model=%s%s'], context, cfg.TopModel, dirtyText);
    error('simtest:ExportModelSessionRestoreFailed', ...
        ['%s was unloaded when export started but remains loaded after ' ...
         '%s.%s'], cfg.TopModel, context, dirtyText);
end
st_log(cfg, 'DEBUG', ...
    'Export model session normalization complete | Context=%s', context);
end

function restore_top_model_load_state(topModel, wasLoadedBefore)
if wasLoadedBefore || ~bdIsLoaded(topModel)
    return;
end
if strcmp(get_param(topModel, 'Dirty'), 'on')
    warning('simtest:ExportTopModelDirtyAfterCollect', ...
        ['%s became dirty while collecting target inputs and was left ' ...
         'open instead of being closed automatically. Review and save ' ...
         'or discard the changes before exporting again.'], topModel);
    return;
end
close_system(topModel, 0);
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

function inventory = inventory_files(root, excluded, cfg)
listing = dir(fullfile(root, '**', '*'));
inventory = repmat(struct( ...
    'BundlePath', '', 'SHA256', '', 'Bytes', 0), 0, 1);
total = sum(~[listing.isdir]);
progressTimer = tic;
for i = 1:numel(listing)
    if listing(i).isdir
        continue;
    end
    path = fullfile(listing(i).folder, listing(i).name);
    relative = bundle_path(root, path);
    if any(strcmp(relative, excluded))
        continue;
    end
    % Hashing a large model or MAT can stall for a long time on its own.
    if toc(progressTimer) >= 5
        fprintf('%-22s : %d/%d files\n', 'Bundle SHA-256', ...
            numel(inventory), total);
        st_log(cfg, 'DEBUG', ...
            'Bundle SHA-256 progress | Done=%d | Total=%d | Current=%s', ...
            numel(inventory), total, relative);
        progressTimer = tic;
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

function directory = short_staging_directory(parentDirectory)
%SHORT_STAGING_DIRECTORY Create a compact, collision-safe staging folder.
% Deeply nested content is built below this directory (template/workspace/
% standalone/{CUTName}/...), so every character here counts toward the
% Windows 260-character MAX_PATH budget. A 6-character token is unique
% enough for a directory that only needs to avoid colliding with other
% concurrent exports into the same destination.
for attempt = 1:20
    uuid = char(java.util.UUID.randomUUID());
    token = uuid(~ismember(uuid, '-'));
    candidate = fullfile(parentDirectory, ['~x' token(1:6)]);
    if ~isfolder(candidate) && ~isfile(candidate)
        mkdir(candidate);
        directory = candidate;
        return;
    end
end
error('simtest:ExportStagingDirectoryUnavailable', ...
    'Could not create a unique staging directory under: %s', ...
    parentDirectory);
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

function timerValue = begin_task(cfg, label, formatText, varargin)
% The manifest stage is a long silent wait otherwise: toolbox analysis,
% whole-bundle hashing and the source recheck each take model- or
% file-proportional time with no output of their own.
detail = sprintf(formatText, varargin{:});
fprintf('%-22s : START  %s\n', label, detail);
st_log(cfg, 'INFO', 'Manifest task start | Task=%s | %s', label, detail);
timerValue = tic;
end

function end_task(cfg, label, timerValue, formatText, varargin)
detail = sprintf(formatText, varargin{:});
elapsed = toc(timerValue);
fprintf('%-22s : DONE   %s | %s\n', label, elapsed_text(elapsed), detail);
st_log(cfg, 'INFO', ...
    'Manifest task complete | Task=%s | elapsed=%.3f sec | %s', ...
    label, elapsed, detail);
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

function inventory = harness_inventory(cfg)
loadedHere = ~bdIsLoaded(cfg.TopModel);
if loadedHere, load_system(cfg.ModelFile); end
cleanup = onCleanup(@() close_loaded_here(cfg.TopModel, loadedHere)); %#ok<NASGU>
items = sltest.harness.find(cfg.TopModel);
inventory = strings(numel(items),1);
for i = 1:numel(items)
    inventory(i) = string(items(i).ownerFullPath) + "|" + ...
        string(items(i).name);
end
inventory = sort(inventory);
end

function close_loaded_here(model, loadedHere)
if loadedHere && bdIsLoaded(model), close_system(model, 0); end
end

function value = normalize_execution_model_mode(value)
text = string(value);
allowed = {'ORIGINAL', 'STANDALONE_HARNESS'};
if ~isscalar(text)
    error('simtest:InvalidExecutionModelMode', ...
        'ExecutionModelMode must be a scalar text value.');
end
value = upper(strtrim(char(text)));
if isempty(value) || ~ismember(value, allowed)
    error('simtest:InvalidExecutionModelMode', ...
        'Invalid ExecutionModelMode: %s. Allowed: %s.', ...
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
    'DataFileFormat', 'SLDV', ...
    'MatVariableName', '', ...
    'ExpectedUpdateMode', '', ...
    'CoverageFilterMode', '', ...
    'CoverageBoundaryMode', '', ...
    'CoverageFilterAction', '', ...
    'CoverageFilterRationale', '', ...
    'SignalEditorInput', '', ...
    'EffectiveSldvInput', '', ...
    'SourceSldvInput', '', ...
    'StandaloneModel', '', ...
    'StandaloneModelFile', '', ...
    'StandaloneCUTPath', '');
end

function value = empty_standalone_detail()
value = struct('StandaloneModel', '', ...
    'StandaloneModelFile', '', 'StandaloneCUTPath', '');
end
