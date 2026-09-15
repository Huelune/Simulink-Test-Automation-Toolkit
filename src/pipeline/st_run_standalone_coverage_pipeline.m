function info = st_run_standalone_coverage_pipeline(varargin)
%ST_RUN_STANDALONE_COVERAGE_PIPELINE Execute and package standalone coverage.
%
%   info = st_run_standalone_coverage_pipeline() runs ALL actions:
%   EXECUTE -> PACKAGE -> SUMMARY. Existing Harness/Test Case/Expected
%   preparation remains the responsibility of st_run_from_harness.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'Action', 'ALL', @(x) ischar(x) || isstring(x));
addParameter(p, 'PipelineId', 'LATEST', @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'SaveTestResult', [], ...
    @(x) isempty(x) || (islogical(x) && isscalar(x)));
addParameter(p, 'ContinueOnFailure', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'FailOnNonPass', false, ...
    @(x) islogical(x) && isscalar(x));
% Parse removed options only to return an actionable migration error.
addParameter(p, 'RunMode', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'PreparationMode', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'FromStage', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'ReportMode', '', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});

reject_removed_options(p.Results);
action = upper(strtrim(char(string(p.Results.Action))));
if ~ismember(action, {'EXECUTE','PACKAGE','SUMMARY','ALL'})
    error('simtest:StandalonePipelineActionInvalid', ...
        'Action must be EXECUTE, PACKAGE, SUMMARY, or ALL.');
end
saveTestResult = resolve_save_policy(action, p.Results.SaveTestResult);

cfg = st_require_runtime_target('LoadModel', false);
outputRoot = strtrim(char(string(p.Results.OutputRoot)));
if isempty(outputRoot), outputRoot = cfg.StandaloneCoverageRootDir; end
if ~isfolder(outputRoot), mkdir(outputRoot); end

timerValue = tic;
st_log(cfg, 'INFO', ...
    'Standalone coverage pipeline start | Action=%s | PipelineId=%s', ...
    action, char(string(p.Results.PipelineId)));
try
    switch action
        case {'EXECUTE','ALL'}
            pipelineId = resolve_new_pipeline_id( ...
                p.Results.PipelineId, outputRoot);
            [manifest, runtimeContext] = run_execute( ...
                outputRoot, pipelineId, p.Results, saveTestResult, cfg);
            if strcmp(action, 'ALL')
                manifest.Action = 'ALL';
                manifest = invoke_package_action( ...
                    outputRoot, manifest, runtimeContext, cfg);
                manifest.SourceAfter = assert_source_unchanged( ...
                    cfg, manifest.SourceBefore);
                st_write_standalone_pipeline_manifest(outputRoot, manifest);
                manifest = st_export_standalone_coverage_summary( ...
                    outputRoot, manifest);
                manifest.SourceAfter = assert_source_unchanged( ...
                    cfg, manifest.SourceBefore);
                manifest.Status = pipeline_status(manifest);
                manifest.UpdatedAt = timestamp_text();
            end
        case 'PACKAGE'
            [manifest, ~] = st_load_standalone_pipeline_manifest( ...
                outputRoot, p.Results.PipelineId);
            manifest.Action = 'PACKAGE';
            manifest = invoke_package_action( ...
                outputRoot, manifest, struct(), cfg);
            manifest.SourceAfter = assert_source_unchanged( ...
                cfg, manifest.SourceBefore);
            manifest.Status = pipeline_status(manifest);
            manifest.UpdatedAt = timestamp_text();
        case 'SUMMARY'
            [manifest, ~] = st_load_standalone_pipeline_manifest( ...
                outputRoot, p.Results.PipelineId);
            manifest.Action = 'SUMMARY';
            manifest = st_export_standalone_coverage_summary( ...
                outputRoot, manifest);
            manifest.SourceAfter = assert_source_unchanged( ...
                cfg, manifest.SourceBefore);
            manifest.Status = pipeline_status(manifest);
            manifest.UpdatedAt = timestamp_text();
    end
    manifestPath = st_write_standalone_pipeline_manifest( ...
        outputRoot, manifest);
    info = public_info(manifest, manifestPath);
    st_log(cfg, 'INFO', ...
        ['Standalone coverage pipeline complete | Action=%s | ' ...
         'PipelineId=%s | elapsed=%.3f sec'], ...
        action, manifest.PipelineId, toc(timerValue));
catch ME
    if exist('manifest', 'var') && isstruct(manifest) && ...
            isfield(manifest, 'Actions')
        manifest = record_active_action_failure(manifest, ME);
        try
            st_write_standalone_pipeline_manifest(outputRoot, manifest);
        catch manifestME
            ME = addCause(ME, manifestME);
        end
    end
    st_log(cfg, 'ERROR', ...
        'Standalone coverage pipeline failed | Action=%s | %s: %s', ...
        action, ME.identifier, ME.message);
    rethrow(ME);
end
end

function manifest = invoke_package_action( ...
        outputRoot, manifest, runtimeContext, cfg)
st_log(cfg, 'INFO', ...
    'Standalone coverage PACKAGE helper refresh start');
try
    % Long-lived MATLAB sessions can retain the previous implementation of
    % this helper after its file is updated.  Force resolution from the
    % active project before PACKAGE so EXECUTE and PACKAGE cannot mix
    % different internal contracts in one pipeline run.
    clear st_package_standalone_coverage_artifacts;
    rehash;
    resolved = which('st_package_standalone_coverage_artifacts');
    expected = fullfile(st_project_root(), 'src', 'pipeline', ...
        'st_package_standalone_coverage_artifacts.m');
    if isempty(resolved) || ~same_file_path(resolved, expected)
        error('simtest:StandalonePipelinePackageResolutionMismatch', ...
            ['PACKAGE helper did not resolve from the active project. ' ...
             'Expected=%s | Actual=%s'], expected, resolved);
    end
    implementation = fileread(resolved);
    if ~contains(implementation, ...
            'package_captured_report_and_metrics') || ...
            contains(implementation, 'PACKAGE report model open complete')
        error('simtest:StandalonePipelinePackageImplementationMismatch', ...
            'PACKAGE helper does not implement captured-evidence promotion: %s', ...
            resolved);
    end
    st_log(cfg, 'INFO', ...
        ['Standalone coverage PACKAGE helper refresh complete | ' ...
         'File=%s | Contract=CAPTURED_EVIDENCE_V1'], resolved);
    manifest = st_package_standalone_coverage_artifacts( ...
        outputRoot, manifest, runtimeContext);
catch ME
    st_log(cfg, 'ERROR', ...
        'Standalone coverage PACKAGE helper refresh failed | %s: %s', ...
        ME.identifier, ME.message);
    rethrow(ME);
end
end

function reject_removed_options(options)
if ~isempty(strtrim(char(string(options.RunMode))))
    error('simtest:StandalonePipelineRunModeRemoved', ...
        ['RunMode was removed. Use Action=EXECUTE, PACKAGE, SUMMARY, ' ...
         'or ALL. Harness preparation now belongs to st_run_from_harness.']);
end
removed = {'PreparationMode','FromStage','ReportMode'};
for i = 1:numel(removed)
    name = removed{i};
    if ~isempty(strtrim(char(string(options.(name)))))
        error('simtest:StandalonePipelineOptionRemoved', ...
            ['%s was removed from the standalone pipeline. Use ' ...
             'st_run_from_harness for preparation and the Action API here.'], ...
            name);
    end
end
end

function value = resolve_save_policy(action, requested)
if ismember(action, {'PACKAGE','SUMMARY'})
    if ~isempty(requested)
        error('simtest:StandalonePipelineSaveResultNotAllowed', ...
            'SaveTestResult is valid only for EXECUTE and ALL.');
    end
    value = false;
elseif isempty(requested)
    value = strcmp(action, 'EXECUTE');
else
    value = logical(requested);
end
end

function [manifest, runtimeContext] = run_execute( ...
        outputRoot, pipelineId, options, saveTestResult, cfg)
timerValue = tic;
pipelineRoot = fullfile(outputRoot, pipelineId);
mkdir(pipelineRoot);
mkdir(fullfile(pipelineRoot, 'logs'));
workRoot = fullfile(pipelineRoot, '.work');
mkdir(workRoot);

st_log(cfg, 'INFO', ...
    'Standalone coverage EXECUTE start | PipelineId=%s', pipelineId);
targets = st_load_targets(cfg.OnlyEnabled);
validate_pipeline_filter_policy(targets);
if ~strcmp(st_coverage_filter_existing_policy( ...
        cfg.CoverageFilterExistingPolicy), 'REPLACE')
    error('simtest:StandalonePipelineRequiresFilterReplacement', ...
        ['The pipeline must collect coverage without inherited filters. ' ...
         'Set cfg.CoverageFilterExistingPolicy to REPLACE.']);
end
assert_pipeline_source_unloaded(cfg, 'before standalone export');
source = source_snapshot(cfg);
manifest = initial_manifest( ...
    pipelineId, pipelineRoot, source, options, saveTestResult);
manifest.Actions.EXECUTE = action_state('RUNNING', ...
    'Standalone export started');
st_write_standalone_pipeline_manifest(outputRoot, manifest);

try
    % This bundle is an internal execution vehicle, not a delivery: it is
    % built under workRoot and nobody reads its README. Skip the toolbox
    % analysis for the same reason the archive is skipped.
    bundle = st_export_test_bundle( ...
        'Destination', workRoot, ...
        'Profile', 'REPRODUCIBLE', ...
        'ExecutionModelMode', 'STANDALONE_HARNESS', ...
        'CreateArchive', false, ...
        'AnalyzeProducts', false, ...
        'IncludeReferenceReport', false);
    assert_pipeline_source_unloaded(cfg, 'before bundle runner');
    manifest.BundleDirectory = bundle.BundleDirectory;
    manifest.BundleManifest = bundle.Manifest;
    manifest.Actions.EXECUTE = action_state('RUNNING', ...
        'Standalone bundle exported; executing copied Test File');
    st_write_standalone_pipeline_manifest(outputRoot, manifest);

    resultPath = '';
    if saveTestResult
        resultPath = fullfile(pipelineRoot, ...
            'StandaloneCoverageResults.mldatx');
    end
    [execution, runtimeContext] = invoke_bundle_runner( ...
        bundle.BundleDirectory, options, saveTestResult, resultPath);
    assert_pipeline_source_unloaded(cfg, 'after bundle runner');
    manifest.ExecutionDirectory = execution.ExecutionDirectory;
    manifest.Workspace = execution.Workspace;
    manifest.PerCutRunDirectory = execution.Report.RunDirectory;
    manifest.ExecutionLog = copy_execution_log( ...
        manifest.PerCutRunDirectory, pipelineRoot);
    manifest.TestManagerWorkFile = execution.TestFile;
    manifest.Targets = build_target_state(bundle.Manifest, execution);
    replayFiles = {manifest.TestManagerWorkFile};
    for i = 1:numel(manifest.Targets)
        replayFiles{end+1} = manifest.Targets(i).StandaloneModelFile; %#ok<AGROW>
        if ~isempty(manifest.Targets(i).SignalEditorInput)
            replayFiles{end+1} = manifest.Targets(i).SignalEditorInput; %#ok<AGROW>
        end
    end
    manifest.ReplayInputs = repmat(struct('Path','','SHA256',''),0,1);
    for i = 1:numel(replayFiles)
        if any(arrayfun(@(entry) st_same_path(entry.Path,replayFiles{i}),manifest.ReplayInputs)), continue; end
        signature = st_file_signature(replayFiles{i});
        manifest.ReplayInputs(end+1,1) = struct('Path',replayFiles{i},'SHA256',signature.SHA256);
    end
    manifest.BundleSessionCleanup = execution.SessionCleanup;
    manifest.RunnerEnvironmentCleanupStatus = ...
        runtimeContext.RunnerEnvironmentCleanupStatus;
    manifest.ResultFile = resultPath;
    if saveTestResult
        manifest.ResultSHA256 = st_file_signature(resultPath).SHA256;
        manifest.ResultExportCount = 1;
    end
    manifest.CanResumePackage = saveTestResult;
    manifest.SourceAfter = assert_source_unchanged(cfg, source);
    manifest.Actions.EXECUTE = action_state( ...
        target_action_status(manifest.Targets, 'ExecutionStatus'), ...
        'One run and one post-run CVF registration completed per target');
    manifest.Status = pipeline_status(manifest);
    manifest.UpdatedAt = timestamp_text();
    st_write_standalone_pipeline_manifest(outputRoot, manifest);
    st_log(cfg, 'INFO', ...
        ['Standalone coverage EXECUTE complete | PipelineId=%s | ' ...
         'Targets=%d | elapsed=%.3f sec'], ...
        pipelineId, numel(manifest.Targets), toc(timerValue));
catch ME
    manifest.Actions.EXECUTE = action_state('FAIL', ...
        sprintf('%s: %s', ME.identifier, ME.message));
    manifest.Status = 'FAIL';
    manifest.UpdatedAt = timestamp_text();
    st_write_standalone_pipeline_manifest(outputRoot, manifest);
    st_log(cfg, 'ERROR', ...
        'Standalone coverage EXECUTE failed | %s: %s', ...
        ME.identifier, ME.message);
    rethrow(ME);
end
end

function [execution, runtimeContext] = invoke_bundle_runner( ...
        bundleDirectory, options, saveTestResult, resultPath)
previousDirectory = pwd;
previousPath = path;
cleanup = onCleanup(@() restore_runner_environment( ...
    previousDirectory, previousPath)); %#ok<NASGU>
cd(bundleDirectory);
addpath(bundleDirectory, '-begin');
clear run_exported_tests;
[execution, runtimeContext] = run_exported_tests( ...
    'ContinueOnFailure', options.ContinueOnFailure, ...
    'FailOnNonPass', options.FailOnNonPass, ...
    'ResultFilterMode', 'POST_RUN_REQUIRED', ...
    'CapturePackageEvidence', true, ...
    'SaveTestResult', saveTestResult, ...
    'ResultFile', resultPath);
clear run_exported_tests;
clear cleanup;
if ~strcmp(pwd, previousDirectory) || ~strcmp(path, previousPath)
    error('simtest:StandaloneRunnerEnvironmentCleanupFailed', ...
        'Bundle runner did not restore the caller directory and MATLAB path.');
end
runtimeContext.RunnerEnvironmentCleanupStatus = 'OK';
end

function value = copy_execution_log(runDirectory, pipelineRoot)
value = '';
source = fullfile(runDirectory, 'logs', 'execution.log');
if isfile(source)
    value = fullfile(pipelineRoot, 'logs', 'execution.log');
    copyfile(source, value, 'f');
end
end

function restore_runner_environment(previousDirectory, previousPath)
cd(previousDirectory);
path(previousPath);
clear run_exported_tests st_setup st_config st_project_root;
end

function targets = build_target_state(bundleManifestPath, execution)
bundleManifest = jsondecode(fileread(bundleManifestPath));
reportTargets = execution.Report.Targets;
if ~istable(reportTargets)
    error('simtest:StandalonePipelineRunReportInvalid', ...
        'PER_CUT execution did not return its Targets table.');
end
n = numel(bundleManifest.Targets);
targets = repmat(empty_target_state(), n, 1);
for i = 1:n
    source = bundleManifest.Targets(i);
    match = find(double(reportTargets.No) == double(source.No) & ...
        string(reportTargets.TestCaseName) == string(source.TestCaseName));
    if numel(match) ~= 1
        error('simtest:StandalonePipelineTargetMappingFailed', ...
            'Cannot map execution result for No=%g, TestCase=%s.', ...
            double(source.No), char(string(source.TestCaseName)));
    end
    row = reportTargets(match,:);
    preparationMatch = find([execution.Preparation.No] == double(source.No));
    if numel(preparationMatch) ~= 1
        error('simtest:StandalonePipelinePreparationMappingFailed', ...
            'Cannot map standalone preparation readback for No=%g.', ...
            double(source.No));
    end
    preparation = execution.Preparation(preparationMatch);
    item = empty_target_state();
    item.Order = i;
    item.No = double(source.No);
    item.CUTName = char(string(source.CUTName));
    item.CUTPath = char(string(source.CUTPath));
    item.HarnessName = char(string(source.HarnessName));
    item.TestCaseName = char(string(source.TestCaseName));
    item.SourceExpectedUpdateMode = char(string(source.ExpectedUpdateMode));
    item.ExpectedUpdateMode = 'OFF';
    item.CoverageFilterMode = char(string(source.CoverageFilterMode));
    item.CoverageBoundaryMode = char(string(source.CoverageBoundaryMode));
    item.CoverageFilterAction = char(string(source.CoverageFilterAction));
    item.CoverageFilterRationale = ...
        char(string(source.CoverageFilterRationale));
    item.StandaloneModel = char(string(source.StandaloneModel));
    item.StandaloneCUTPath = char(string(source.StandaloneCUTPath));
    item.StandaloneModelFile = bundle_work_path( ...
        execution.Workspace, source.StandaloneModelFile);
    item.SignalEditorInput = bundle_work_path( ...
        execution.Workspace, source.SignalEditorInput);
    item.AssessmentBlock = char(string(preparation.AssessmentBlock));
    item.IterationSignature = char(string(preparation.IterationSignature));
    item.SUTReadbackStatus = char(string(preparation.SUTReadbackStatus));
    item.IterationIntegrityStatus = ...
        char(string(preparation.IterationIntegrityStatus));
    item.InputReadbackStatus = char(string(preparation.InputReadbackStatus));
    item.AssessmentReadbackStatus = ...
        char(string(preparation.AssessmentReadbackStatus));
    item.PerCutTargetDirectory = fileparts(char(row.TargetManifest));
    item.CVFPath = char(string(row.CVFPath));
    item.ExecutionCVFPath = item.CVFPath;
    item.CVFSHA256 = char(string(row.CVFSHA256));
    item.CVFRuleCount = double(row.CVFRuleCount);
    item.CVFGenerationStatus = char(string(row.FilterGenerationStatus));
    item.RunCount = double(row.RunCount);
    item.ResultFilterAttachCount = double(row.ResultFilterAttachCount);
    item.InitialOutcome = char(string(row.InitialOutcome));
    item.FinalOutcome = char(string(row.FinalOutcome));
    item.RerunPerformed = logical(row.RerunPerformed);
    item.ResultFilterStatus = char(string(row.ResultFilterStatus));
    item.FilterRestoreStatus = char(string(row.FilterRestoreStatus));
    item.ModelCleanupStatus = char(string(row.ModelCleanupStatus));
    item.PathCleanupStatus = char(string(row.PathCleanupStatus));
    item.PackageEvidence = char(string(row.PackageEvidence));
    item.PackageEvidenceSHA256 = ...
        char(string(row.PackageEvidenceSHA256));
    item.PackageEvidenceStatus = char(string(row.PackageEvidenceStatus));
    item.ExecutionStatus = char(string(row.Status));
    item.Message = char(string(row.Message));
    reportedExecutionStatus = upper(string(item.ExecutionStatus));
    if item.RunCount ~= 1 || item.RerunPerformed || ...
            item.ResultFilterAttachCount ~= 1 || ...
            ~strcmp(item.CVFGenerationStatus, 'OK') || ...
            ~strcmp(item.ResultFilterStatus, 'OK') || ...
            ~strcmp(item.FilterRestoreStatus, 'OK') || ...
            ~strcmp(item.ModelCleanupStatus, 'OK') || ...
            ~strcmp(item.PathCleanupStatus, 'OK') || ...
            ~strcmp(item.PackageEvidenceStatus, 'OK')
        if reportedExecutionStatus == "EXCEPT"
            item.ExecutionStatus = 'EXCEPT';
        else
            item.ExecutionStatus = 'FAIL';
        end
        item.Message = append_message(item.Message, ...
            'Standalone lifecycle contract did not pass');
    end
    targets(i) = item;
end
end

function value = bundle_work_path(workspace, bundlePath)
value = char(string(bundlePath));
if isempty(value), return; end
native = strrep(value, '/', filesep);
prefix = ['template' filesep];
if startsWith(native, prefix)
    value = fullfile(workspace, char(extractAfter( ...
        string(native), strlength(prefix))));
end
end

function validate_pipeline_filter_policy(targets)
requiredColumns = {'CoverageFilterMode','CoverageBoundaryMode', ...
    'CoverageFilterAction','CoverageFilterRationale'};
missing = setdiff(requiredColumns, targets.Properties.VariableNames);
if ~isempty(missing)
    error('simtest:StandalonePipelineFilterPolicyMissing', ...
        'Targets is missing required coverage columns: %s.', ...
        strjoin(missing, ', '));
end
invalid = upper(strtrim(string(targets.CoverageFilterMode))) ~= "ALL_CONTENT" | ...
    upper(strtrim(string(targets.CoverageBoundaryMode))) ~= "CUT_ONLY" | ...
    upper(strtrim(string(targets.CoverageFilterAction))) ~= "EXCLUDE" | ...
    strlength(strtrim(string(targets.CoverageFilterRationale))) == 0;
if any(invalid)
    rows = strjoin(string(double(targets.No(invalid))), ', ');
    error('simtest:StandalonePipelineFilterPolicyInvalid', ...
        ['Every pipeline target requires ALL_CONTENT + CUT_ONLY + ' ...
         'EXCLUDE and a non-empty rationale. Invalid target No: %s'], ...
        char(rows));
end
end

function value = source_snapshot(cfg)
assert_saved_source(cfg);
value = struct( ...
    'Model', st_file_signature(cfg.ModelFile), ...
    'TestFile', st_file_signature(cfg.TestFile), ...
    'ManagementExcel', st_file_signature(cfg.ManagementExcel), ...
    'ModelDirty', model_dirty(cfg), ...
    'TestFileDirty', test_file_dirty(cfg), ...
    'HarnessInventory', {harness_inventory(cfg)}, ...
    'Harnesses', {harness_asset_inventory(cfg)}, ...
    'Inputs', {input_inventory(cfg)});
end

function assert_saved_source(cfg)
files = {cfg.ModelFile, cfg.TestFile, cfg.ManagementExcel};
for i = 1:numel(files)
    if ~isfile(files{i})
        error('simtest:StandalonePipelineSourceMissing', ...
            'Required source file is missing: %s', files{i});
    end
end
if model_dirty(cfg)
    error('simtest:StandalonePipelineModelDirty', ...
        'Save the source model before starting the pipeline.');
end
if test_file_dirty(cfg)
    error('simtest:StandalonePipelineTestFileDirty', ...
        'Save the source Test File before starting the pipeline.');
end
end

function value = model_dirty(cfg)
value = false;
if bdIsLoaded(cfg.TopModel)
    value = strcmp(get_param(cfg.TopModel, 'Dirty'), 'on');
end
end

function value = test_file_dirty(cfg)
tf = [];
openedHere = false;
openFiles = sltest.testmanager.getTestFiles;
for i = 1:numel(openFiles)
    try
        if same_file_path(openFiles(i).FilePath, cfg.TestFile)
            tf = openFiles(i);
            break;
        end
    catch
    end
end
if isempty(tf)
    tf = sltest.testmanager.TestFile(cfg.TestFile);
    openedHere = true;
end
cleanup = onCleanup(@() close_test_file_if_opened(tf, openedHere)); %#ok<NASGU>
value = isprop(tf, 'Dirty') && logical(tf.Dirty);
end

function close_test_file_if_opened(tf, openedHere)
if ~openedHere, return; end
try
    openFiles = sltest.testmanager.getTestFiles;
    for i = 1:numel(openFiles)
        if isequal(openFiles(i), tf)
            close(openFiles(i));
            return;
        end
    end
catch
end
end

function tf = same_file_path(left, right)
left = char(java.io.File(char(left)).getCanonicalPath());
right = char(java.io.File(char(right)).getCanonicalPath());
if ispc, tf = strcmpi(left, right); else, tf = strcmp(left, right); end
end

function inventory = harness_inventory(cfg)
loadedHere = ~bdIsLoaded(cfg.TopModel);
if loadedHere, load_system(cfg.ModelFile); end
cleanup = onCleanup(@() close_loaded_model(cfg.TopModel, loadedHere)); %#ok<NASGU>
items = sltest.harness.find(cfg.TopModel);
inventory = strings(numel(items),1);
for i = 1:numel(items)
    inventory(i) = string(items(i).ownerFullPath) + "|" + ...
        string(items(i).name);
end
inventory = cellstr(sort(inventory));
end

function inventory = harness_asset_inventory(cfg)
loadedHere = ~bdIsLoaded(cfg.TopModel);
if loadedHere, load_system(cfg.ModelFile); end
cleanup = onCleanup(@() close_loaded_model(cfg.TopModel, loadedHere)); %#ok<NASGU>
items = sltest.harness.find(cfg.TopModel);
inventory = repmat(struct( ...
    'Owner', '', 'Name', '', 'Storage', '', ...
    'Path', '', 'SHA256', ''), numel(items), 1);
modelSignature = st_file_signature(cfg.ModelFile);
for i = 1:numel(items)
    inventory(i).Owner = char(string(items(i).ownerFullPath));
    inventory(i).Name = char(string(items(i).name));
    external = isfield(items, 'saveExternally') && ...
        logical_value(items(i).saveExternally);
    if external
        if ~isfield(items, 'harnessFilePath') || ...
                isempty(char(string(items(i).harnessFilePath)))
            error('simtest:StandalonePipelineHarnessFileMissing', ...
                'External Harness file path is unavailable: %s', ...
                inventory(i).Name);
        end
        path = st_resolve_data_file( ...
            items(i).harnessFilePath, cfg.TopModel);
        signature = st_file_signature(path);
        inventory(i).Storage = 'EXTERNAL';
        inventory(i).Path = signature.Path;
        inventory(i).SHA256 = signature.SHA256;
    else
        inventory(i).Storage = 'INTERNAL_MODEL';
        inventory(i).Path = modelSignature.Path;
        inventory(i).SHA256 = modelSignature.SHA256;
    end
end
[~, order] = sort(string({inventory.Owner}) + "|" + ...
    string({inventory.Name}));
inventory = inventory(order);
end

function inventory = input_inventory(cfg)
targets = st_load_targets(cfg.OnlyEnabled);
loadedHere = ~bdIsLoaded(cfg.TopModel);
if loadedHere, load_system(cfg.ModelFile); end
cleanup = onCleanup(@() close_loaded_model(cfg.TopModel, loadedHere)); %#ok<NASGU>
inventory = repmat(struct('No', 0, 'Path', '', 'SHA256', ''), 0, 1);
for i = 1:height(targets)
    row = targets(i,:);
    cutPath = st_normalize_cut_path(row.CUTPath, cfg.TopModel);
    harnessName = char(string(row.HarnessName));
    loadedHarness = false;
    try
        sltest.harness.load(cutPath, harnessName);
        loadedHarness = true;
        block = st_find_signal_editor_block(harnessName);
        path = st_resolve_data_file( ...
            get_param(block, 'Filename'), cfg.TopModel);
        signature = st_file_signature(path);
        inventory(end+1,1) = struct( ...
            'No', double(row.No), 'Path', path, ...
            'SHA256', signature.SHA256); %#ok<AGROW>
    catch ME
        if ~(strcmpi(char(string(row.SldvMode)), 'OFF') && ...
                strcmp(ME.identifier, 'simtest:SignalEditorBlockMissing'))
            if loadedHarness, close_harness(cutPath, harnessName); end
            rethrow(ME);
        end
    end
    if loadedHarness, close_harness(cutPath, harnessName); end
end
end

function close_harness(cutPath, harnessName)
try, sltest.harness.close(cutPath, harnessName); catch, end
end

function close_loaded_model(model, loadedHere)
if loadedHere && bdIsLoaded(model), close_system(model, 0); end
end

function value = logical_value(raw)
if isempty(raw)
    value = false;
    return;
end
if islogical(raw) || isnumeric(raw)
    value = logical(raw(1));
else
    value = ismember(lower(strtrim(char(string(raw)))), ...
        {'true','1','yes','on'});
end
end

function after = assert_source_unchanged(cfg, before)
after = source_snapshot(cfg);
fields = {'Model','TestFile','ManagementExcel'};
for i = 1:numel(fields)
    name = fields{i};
    if ~strcmpi(before.(name).SHA256, after.(name).SHA256)
        error('simtest:StandalonePipelineSourceChanged', ...
            'Source %s checksum changed during isolated execution.', name);
    end
end
if before.ModelDirty ~= after.ModelDirty || ...
        before.TestFileDirty ~= after.TestFileDirty || ...
        ~isequal(string(before.HarnessInventory), ...
        string(after.HarnessInventory)) || ...
        ~isequal(harness_keys(before.Harnesses), ...
        harness_keys(after.Harnesses)) || ...
        ~isequal(input_keys(before.Inputs), input_keys(after.Inputs))
    error('simtest:StandalonePipelineSourceStateChanged', ...
        'Source Dirty state, Harness inventory, or Input checksum changed.');
end
end

function values = harness_keys(items)
values = strings(numel(items),1);
for i = 1:numel(items)
    values(i) = string(items(i).Owner) + "|" + ...
        string(items(i).Name) + "|" + string(items(i).Storage) + "|" + ...
        string(items(i).Path) + "|" + string(items(i).SHA256);
end
values = sort(values);
end

function values = input_keys(items)
values = strings(numel(items),1);
for i = 1:numel(items)
    values(i) = string(items(i).No) + "|" + ...
        string(items(i).Path) + "|" + string(items(i).SHA256);
end
values = sort(values);
end

function manifest = initial_manifest(id, root, source, options, saveTestResult)
manifest = struct( ...
    'Version', 3, 'PipelineId', id, 'PipelineRoot', root, ...
    'Action', 'EXECUTE', 'Status', 'RUNNING', ...
    'CreatedAt', timestamp_text(), 'UpdatedAt', timestamp_text(), ...
    'SaveTestResult', logical(saveTestResult), ...
    'ResultFile', '', 'ResultSHA256', '', ...
    'CanResumePackage', false, 'ResultExportCount', 0, ...
    'ResultImportCount', 0, 'PackageResultSource', '', ...
    'Options', struct( ...
        'ContinueOnFailure', logical(options.ContinueOnFailure), ...
        'FailOnNonPass', logical(options.FailOnNonPass)), ...
    'SourceBefore', source, 'SourceAfter', struct(), ...
    'BundleDirectory', '', 'BundleManifest', '', ...
    'ExecutionDirectory', '', 'Workspace', '', ...
    'PerCutRunDirectory', '', 'ExecutionLog', '', ...
    'BundleSessionCleanup', struct( ...
        'TestFileStatus', 'NOT_RUN', 'TopModelStatus', 'NOT_RUN'), ...
    'RunnerEnvironmentCleanupStatus', 'NOT_RUN', ...
    'TestManagerWorkFile', '', 'TestManagerFile', '', ...
    'TestManagerSHA256', '', 'TestManagerLauncher', '', ...
    'TestManagerLauncherSHA256', '', 'CoverageSummary', '', ...
    'CoverageSummarySHA256', '', ...
    'Targets', repmat(empty_target_state(), 0, 1), ...
    'Actions', struct( ...
        'EXECUTE', action_state('NOT_RUN', ''), ...
        'PACKAGE', action_state('NOT_RUN', ''), ...
        'SUMMARY', action_state('NOT_RUN', '')));
end

function value = empty_target_state()
value = struct( ...
    'Order', 0, 'No', 0, 'CUTName', '', 'CUTPath', '', ...
    'HarnessName', '', 'TestCaseName', '', ...
    'SourceExpectedUpdateMode', '', 'ExpectedUpdateMode', 'OFF', ...
    'CoverageFilterMode', '', 'CoverageBoundaryMode', '', ...
    'CoverageFilterAction', '', 'CoverageFilterRationale', '', ...
    'StandaloneModel', '', 'StandaloneCUTPath', '', ...
    'StandaloneModelFile', '', 'AssessmentBlock', '', ...
    'IterationSignature', '', 'SignalEditorInput', '', ...
    'SUTReadbackStatus', 'FAIL', ...
    'IterationIntegrityStatus', 'FAIL', ...
    'InputReadbackStatus', 'FAIL', ...
    'AssessmentReadbackStatus', 'FAIL', ...
    'PerCutTargetDirectory', '', 'CVFPath', '', ...
    'ExecutionCVFPath', '', 'CVFSHA256', '', 'CVFRuleCount', 0, ...
    'CVFGenerationStatus', 'FAIL', 'RunCount', 0, ...
    'ResultFilterAttachCount', 0, 'InitialOutcome', '', ...
    'FinalOutcome', '', 'RerunPerformed', false, ...
    'ResultFilterStatus', '', 'FilterRestoreStatus', '', ...
    'ModelCleanupStatus', '', 'PathCleanupStatus', '', ...
    'PackageEvidence', '', 'PackageEvidenceSHA256', '', ...
    'PackageEvidenceStatus', 'NOT_RUN', ...
    'ExecutionStatus', 'NOT_RUN', ...
    'PackageStatus', 'NOT_RUN', 'SummaryStatus', 'NOT_RUN', ...
    'PackageFailure', empty_package_failure(), ...
    'Message', '', 'OutputDirectory', '', 'TargetManifest', '', ...
    'PackagedStandaloneModel', '', 'PackagedInput', '', ...
    'PackagedCVF', '', 'PackagedStandaloneModelSHA256', '', ...
    'PackagedInputSHA256', '', 'PackagedCVFSHA256', '', ...
    'PackagedInputReadbackStatus', 'NOT_RUN', ...
    'CoverageResult', '', 'CoverageResultSHA256', '', ...
    'TestReport', '', 'ReportHTML', '', ...
    'DecisionCovered', NaN, 'DecisionTotal', NaN, ...
    'DecisionPercentage', NaN, 'DecisionPercentageText', 'N/A', ...
    'DecisionMetricStatus', 'NOT_RUN', ...
    'ExecutionCovered', NaN, 'ExecutionTotal', NaN, ...
    'ExecutionPercentage', NaN, 'ExecutionPercentageText', 'N/A', ...
    'ExecutionMetricStatus', 'NOT_RUN', ...
    'MetricSource', '', 'MetricSourceStatus', 'NOT_RUN');
end

function value = empty_package_failure()
value = struct('Identifier', '', 'Message', '');
end

function manifest = record_active_action_failure(manifest, exception)
names = {'SUMMARY','PACKAGE','EXECUTE'};
for i = 1:numel(names)
    name = names{i};
    if strcmpi(manifest.Actions.(name).Status, 'RUNNING')
        manifest.Actions.(name) = action_state('FAIL', ...
            sprintf('%s: %s', exception.identifier, exception.message));
        break;
    end
end
manifest.Status = 'FAIL';
manifest.UpdatedAt = timestamp_text();
end

function value = action_state(status, message)
value = struct('Status', status, 'Message', message, ...
    'UpdatedAt', timestamp_text());
end

function status = target_action_status(targets, field)
values = upper(string({targets.(field)}));
if any(values == "FAIL" | values == "EXCEPT" | values == "SKIP")
    status = 'WARN';
else
    status = 'OK';
end
end

function status = pipeline_status(manifest)
names = fieldnames(manifest.Actions);
values = strings(numel(names),1);
for i = 1:numel(names)
    values(i) = upper(string(manifest.Actions.(names{i}).Status));
end
if any(values == "FAIL")
    status = 'FAIL';
elseif any(values == "WARN" | values == "NOT_RUN")
    status = 'PARTIAL';
else
    status = 'OK';
end
end

function id = resolve_new_pipeline_id(requested, outputRoot)
id = strtrim(char(string(requested)));
if isempty(id) || strcmpi(id, 'LATEST')
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
    uuid = char(java.util.UUID.randomUUID());
    id = [stamp '_' uuid(1:8)];
end
if ~strcmp(id, st_export_safe_name(id)) || isfolder(fullfile(outputRoot, id))
    error('simtest:StandalonePipelineIdInvalid', ...
        'PipelineId is unsafe or already exists: %s', id);
end
end

function assert_pipeline_source_unloaded(cfg, context)
if ~bdIsLoaded(cfg.TopModel), return; end
dirtyText = '';
if strcmp(get_param(cfg.TopModel, 'Dirty'), 'on')
    dirtyText = ' It has unsaved changes; save or discard them first.';
end
error('simtest:StandaloneModelStillLoadedBeforeRun', ...
    ['%s must be unloaded %s because the exported bundle loads its own ' ...
     'copy under the same model name.%s'], ...
    cfg.TopModel, context, dirtyText);
end

function value = append_message(existing, added)
if isempty(existing), value = added; else, value = [existing ' | ' added]; end
end

function info = public_info(manifest, manifestPath)
info = struct( ...
    'PipelineId', char(string(manifest.PipelineId)), ...
    'Manifest', manifestPath, ...
    'Action', char(string(manifest.Action)), ...
    'SaveTestResult', logical(manifest.SaveTestResult), ...
    'ResultFile', char(string(manifest.ResultFile)), ...
    'CanResumePackage', logical(manifest.CanResumePackage), ...
    'TestManagerFile', char(string(manifest.TestManagerFile)), ...
    'TestManagerLauncher', optional_field_text(manifest, 'TestManagerLauncher'), ...
    'Targets', manifest.Targets, ...
    'CoverageSummary', char(string(manifest.CoverageSummary)), ...
    'Status', char(string(manifest.Status)));
end

function value = timestamp_text()
value = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end

function value = optional_field_text(data, name)
value = '';
if isstruct(data) && isfield(data, name)
    value = char(string(data.(name)));
end
end
