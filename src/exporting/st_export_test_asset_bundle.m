function info = st_export_test_asset_bundle(varargin)
%ST_EXPORT_TEST_ASSET_BUNDLE Collect selected results and matching assets.
%
%   st_export_test_asset_bundle('ResultSet', resultSet)
%   st_export_test_asset_bundle('RunId', 'LATEST')
%   st_export_test_asset_bundle('SelectResult', true)
%   st_export_test_asset_bundle('SelectResult', true, ...
%       'CoverageReportMode', 'FULL')
%
% SelectResult opens a single-selection dialog containing current Test
% Manager ResultSets and saved toolkit runs. It is mutually exclusive with
% ResultSet and an explicitly supplied RunId.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'Destination', '', @is_text_scalar);
addParameter(p, 'RunId', 'LATEST', @is_text_scalar);
addParameter(p, 'ResultSet', []);
addParameter(p, 'SelectResult', false, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'CreateArchive', false, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'CoverageReportMode', 'SUMMARY', ...
    @(x) is_text_scalar(x) && ismember( ...
        upper(string(x)), ["SUMMARY","FULL"]));
parse(p, varargin{:});

resultObj = p.Results.ResultSet;
selectResult = p.Results.SelectResult;
runIdExplicit = ~any(strcmp(p.UsingDefaults, 'RunId'));
if (~isempty(resultObj) && runIdExplicit) || ...
        (selectResult && (~isempty(resultObj) || runIdExplicit))
    error('simtest:AssetResultSelectionConflict', ...
        ['SelectResult, ResultSet, and an explicitly supplied RunId ' ...
         'are mutually exclusive.']);
end
validate_result_set(resultObj);

cfg = st_require_runtime_target();
requestedRun = char(string(p.Results.RunId));
if selectResult
    [resultObj, requestedRun] = select_result_interactively(cfg);
    validate_result_set(resultObj);
end
destination = strtrim(char(string(p.Results.Destination)));
if isempty(destination)
    destination = fullfile(cfg.ExportRootDir, 'assets');
end

required = {cfg.ModelFile, cfg.TestFile, cfg.ManagementExcel};
labels = {'model','Test Manager file','management Excel'};
for i = 1:numel(required)
    if ~isfile(required{i})
        error('simtest:AssetSourceMissing', ...
            'Required %s is missing: %s', labels{i}, required{i});
    end
end
assert_saved_sources(cfg);

totalTimer = tic;
fprintf('\n============================================\n');
fprintf('Selected Test Asset Bundle Export\n');
fprintf('Model       : %s\n', cfg.TopModel);
fprintf('Destination : %s\n', destination);
fprintf('Start       : %s\n', timestamp_text());
fprintf('============================================\n');

currentStage = 'Resolve Selected Result';
stageTimer = start_step(cfg, currentStage);
try
    allTargets = st_load_targets(false);
    selection = resolve_result_selection( ...
        resultObj, requestedRun, cfg, allTargets);
    selectedTargets = st_select_asset_targets( ...
        allTargets, selection.TestCaseNames);
    fprintf('Result Source : %s\n', selection.Type);
    fprintf('Result Name   : %s\n', selection.DisplayName);
    fprintf('Test Cases    : %d\n', height(selectedTargets));
    finish_step(cfg, currentStage, stageTimer);

    currentStage = 'Validate Source Harnesses';
    stageTimer = start_step(cfg, currentStage);
    openedModelHere = false;
    if ~bdIsLoaded(cfg.TopModel)
        load_system(cfg.ModelFile);
        openedModelHere = true;
    end
    modelCleanup = onCleanup(@() close_source_model( ...
        cfg.TopModel, openedModelHere)); %#ok<NASGU>
    sourceModelSignature = st_file_signature(cfg.ModelFile);
    sourceTestSignature = st_file_signature(cfg.TestFile);
    validate_selected_harnesses(selectedTargets, cfg);
    sourceHarnesses = all_harness_inventory(cfg.TopModel);
    sourceDirtyState = get_param(cfg.TopModel, 'Dirty');
    finish_step(cfg, currentStage, stageTimer);

    currentStage = 'Prepare Asset Workspace';
    stageTimer = start_step(cfg, currentStage);
    if ~isfolder(destination), mkdir(destination); end
    bundleId = make_bundle_id();
    stagingDirectory = tempname(destination);
    mkdir(stagingDirectory);
    stagingCleanup = onCleanup(@() remove_staging(stagingDirectory)); %#ok<NASGU>

    copy_checked(cfg.ManagementExcel, ...
        fullfile(stagingDirectory, 'TestManagement.xlsx'));
    modelDirectory = fullfile(stagingDirectory, 'models');
    testManagerDirectory = fullfile(stagingDirectory, 'test-manager');
    mkdir(modelDirectory);
    mkdir(testManagerDirectory);
    [~, ~, modelExtension] = fileparts(cfg.ModelFile);
    modelOutput = fullfile(modelDirectory, ...
        [cfg.TopModel modelExtension]);
    testFileOutput = fullfile(testManagerDirectory, ...
        [cfg.TopModel '.mldatx']);
    copy_checked(cfg.ModelFile, modelOutput);
    copy_checked(cfg.TestFile, testFileOutput);
    finish_step(cfg, currentStage, stageTimer);

    currentStage = 'Collect Harness Inputs';
    stageTimer = start_step(cfg, currentStage);
    targetInventory = st_collect_asset_inputs( ...
        selectedTargets, cfg, ...
        fullfile(stagingDirectory, 'inputs'), stagingDirectory);
    finish_step(cfg, currentStage, stageTimer);

    currentStage = 'Export Standalone Harnesses';
    stageTimer = start_step(cfg, currentStage);
    standalonePaths = st_export_standalone_harnesses( ...
        cfg.ModelFile, cfg.TopModel, selectedTargets, ...
        fullfile(stagingDirectory, 'harnesses'), stagingDirectory);
    for i = 1:numel(targetInventory)
        targetInventory(i).StandaloneHarness = char(standalonePaths(i));
    end
    harnessCount = numel(unique(standalonePaths));
    fprintf('Standalone Harnesses : %d\n', harnessCount);
    finish_step(cfg, currentStage, stageTimer);

    currentStage = 'Collect Selected Result Report';
    stageTimer = start_step(cfg, currentStage);
    resultFolderName = st_export_safe_name(selection.Name);
    resultOutput = fullfile(stagingDirectory, 'results', resultFolderName);
    if strcmp(selection.Type, 'ResultSet')
        resultInfo = st_export_result_set_report( ...
            resultObj, selectedTargets, resultOutput, ...
            selection.DisplayName, 'CoverageReportMode', ...
            p.Results.CoverageReportMode, 'LogConfig', cfg);
    else
        copy_checked(selection.Directory, resultOutput);
        resultInfo = existing_report_info(selection, resultOutput);
    end
    resultBundlePath = bundle_path(stagingDirectory, resultOutput);
    for i = 1:numel(targetInventory)
        targetInventory(i).ResultPath = resultBundlePath;
    end
    fprintf('Result Status : %s\n', resultInfo.Status);
    finish_step(cfg, currentStage, stageTimer);

    currentStage = 'Verify Source Unchanged';
    stageTimer = start_step(cfg, currentStage);
    assert_signature_unchanged(cfg.ModelFile, sourceModelSignature);
    assert_signature_unchanged(cfg.TestFile, sourceTestSignature);
    assert_signature_unchanged(modelOutput, sourceModelSignature);
    assert_signature_unchanged(testFileOutput, sourceTestSignature);
    assert_saved_sources(cfg);
    if ~strcmp(sourceDirtyState, get_param(cfg.TopModel, 'Dirty'))
        error('simtest:AssetSourceDirtyStateChanged', ...
            'Source model Dirty state changed during asset export.');
    end
    currentHarnesses = all_harness_inventory(cfg.TopModel);
    if ~isequal(sourceHarnesses, currentHarnesses)
        error('simtest:AssetSourceHarnessChanged', ...
            'Source Harness inventory changed during asset export.');
    end
    finish_step(cfg, currentStage, stageTimer);

    currentStage = 'Build Asset Manifest';
    stageTimer = start_step(cfg, currentStage);
    readme = fileread(fullfile(st_project_root(), 'resources', ...
        'export_bundle', 'README.assets.ko.md'));
    readme = strrep(readme, '{{BUNDLE_ID}}', bundleId);
    readme = strrep(readme, '{{TOP_MODEL}}', cfg.TopModel);
    readme = strrep(readme, '{{MATLAB_RELEASE}}', version('-release'));
    readme = strrep(readme, '{{RESULT_NAME}}', selection.DisplayName);
    write_text(fullfile(stagingDirectory, 'README.md'), readme);

    artifactFailures = double(resultInfo.ArtifactFailures);
    status = char(string(resultInfo.Status));
    manifest = struct( ...
        'Version', 2, ...
        'BundleId', bundleId, ...
        'Profile', 'ASSET', ...
        'Status', status, ...
        'CreatedAt', iso_timestamp_text(), ...
        'MATLABRelease', version('-release'), ...
        'TopModel', cfg.TopModel, ...
        'ResultSource', selection.Type, ...
        'ResultName', selection.DisplayName, ...
        'CoverageDetail', char(string(resultInfo.CoverageDetail)), ...
        'CoverageReportMode', char(string( ...
            resultInfo.CoverageReportMode)), ...
        'ModelFile', bundle_path(stagingDirectory, modelOutput), ...
        'TestManagerFile', bundle_path(stagingDirectory, testFileOutput), ...
        'ManagementExcel', 'TestManagement.xlsx', ...
        'ResultSelection', result_selection_manifest( ...
            selection, stagingDirectory, resultOutput), ...
        'HarnessCount', harnessCount, ...
        'ArtifactFailures', artifactFailures, ...
        'Targets', targetInventory, ...
        'ResultArtifacts', manifest_artifacts( ...
            resultInfo.Artifacts, stagingDirectory), ...
        'Files', inventory_files_light(stagingDirectory, {'manifest.json'}), ...
        'Policy', struct( ...
            'Reproducible', false, ...
            'ResultMatchedHarnessScope', true, ...
            'SourceUnchangedVerified', true, ...
            'WholeModelDependenciesIncluded', false, ...
            'FileChecksumsIncluded', false));
    write_json(fullfile(stagingDirectory, 'manifest.json'), manifest);
    finish_step(cfg, currentStage, stageTimer);

    currentStage = 'Finalize Asset Bundle';
    stageTimer = start_step(cfg, currentStage);
    finalDirectory = fullfile(destination, bundleId);
    if isfolder(finalDirectory) || isfile(finalDirectory)
        error('simtest:AssetDestinationExists', ...
            'Asset destination already exists: %s', finalDirectory);
    end
    [ok, message] = movefile(stagingDirectory, finalDirectory);
    if ~ok
        error('simtest:AssetFinalizeFailed', ...
            'Cannot finalize asset bundle: %s', message);
    end
    finish_step(cfg, currentStage, stageTimer);

    archivePath = '';
    if p.Results.CreateArchive
        currentStage = 'Create ZIP Archive';
        stageTimer = start_step(cfg, currentStage);
        archivePath = [finalDirectory '.zip'];
        zip(archivePath, bundleId, destination);
        finish_step(cfg, currentStage, stageTimer);
    else
        fprintf('\nCreate ZIP Archive: SKIP (CreateArchive=false)\n');
    end

    info = struct( ...
        'BundleId', bundleId, ...
        'BundleDirectory', finalDirectory, ...
        'Archive', archivePath, ...
        'Manifest', fullfile(finalDirectory, 'manifest.json'), ...
        'ResultSource', selection.Type, ...
        'ResultName', selection.DisplayName, ...
        'Status', status, ...
        'CoverageDetail', char(string(resultInfo.CoverageDetail)), ...
        'CoverageReportMode', char(string( ...
            resultInfo.CoverageReportMode)), ...
        'HarnessCount', harnessCount, ...
        'ArtifactFailures', artifactFailures);

    fprintf('\n============================================\n');
    fprintf('Test Asset Bundle Export Complete\n');
    fprintf('Status  : %s\n', status);
    fprintf('Folder  : %s\n', finalDirectory);
    fprintf('Elapsed : %s\n', elapsed_text(toc(totalTimer)));
    fprintf('============================================\n');
    st_log(cfg, 'INFO', ...
        '[AssetExport] complete | status=%s | folder=%s | elapsed=%.3f sec', ...
        status, finalDirectory, toc(totalTimer));
catch ME
    fail_step(cfg, currentStage, stageTimer, ME);
    fprintf('\n============================================\n');
    fprintf('Test Asset Bundle Export Failed\n');
    fprintf('Stage   : %s\n', currentStage);
    fprintf('Elapsed : %s\n', elapsed_text(toc(totalTimer)));
    fprintf('============================================\n');
    rethrow(ME);
end
end

function validate_result_set(resultObj)
if isempty(resultObj), return; end
if numel(resultObj) ~= 1 || ...
        ~isa(resultObj, 'sltest.testmanager.ResultSet') || ...
        ~isvalid(resultObj)
    error('simtest:InvalidAssetResultSet', ...
        'ResultSet must be one valid sltest.testmanager.ResultSet object.');
end
end

function [resultObj, runId] = select_result_interactively(cfg)
if ~usejava('desktop')
    error('simtest:AssetResultSelectionUiUnavailable', ...
        ['SelectResult requires MATLAB Desktop. Use ResultSet or RunId ' ...
         'for noninteractive execution.']);
end

labels = cell(0,1);
kinds = strings(0,1);
values = cell(0,1);
resultSetFailure = '';
try
    resultSets = sltest.testmanager.getResultSets;
catch ME
    resultSets = [];
    resultSetFailure = ME.message;
end

for i = 1:numel(resultSets)
    labels{end+1,1} = result_set_choice_label(resultSets(i), i); %#ok<AGROW>
    kinds(end+1,1) = "ResultSet"; %#ok<AGROW>
    values{end+1,1} = resultSets(i); %#ok<AGROW>
end

runs = list_toolkit_run_choices(cfg);
for i = 1:numel(runs)
    labels{end+1,1} = runs(i).Label; %#ok<AGROW>
    kinds(end+1,1) = "RunId"; %#ok<AGROW>
    values{end+1,1} = runs(i).RunId; %#ok<AGROW>
end

if isempty(labels)
    message = ['No Test Manager ResultSets or toolkit runs with ' ...
        'TestSummary.xlsx are available.'];
    if ~isempty(resultSetFailure)
        message = sprintf('%s Test Manager query failed: %s', ...
            message, resultSetFailure);
    end
    error('simtest:AssetResultChoicesMissing', '%s', message);
end

[selected, accepted] = listdlg( ...
    'Name', 'Select Test Result', ...
    'PromptString', '내보낼 테스트 결과를 선택하세요.', ...
    'ListString', labels, ...
    'SelectionMode', 'single', ...
    'InitialValue', 1, ...
    'ListSize', [760 360]);
if ~accepted || isempty(selected)
    error('simtest:AssetResultSelectionCancelled', ...
        'Test result selection was cancelled.');
end

if kinds(selected) == "ResultSet"
    resultObj = values{selected};
    runId = 'LATEST';
else
    resultObj = [];
    runId = char(values{selected});
end
end

function label = result_set_choice_label(resultObj, index)
name = choice_text(safe_property(resultObj, 'Name', ''));
if isempty(name), name = sprintf('ResultSet %d', index); end
outcome = choice_text(safe_property(resultObj, 'Outcome', ''));
created = first_choice_property(resultObj, ...
    {'StartTime','DateCreated','CreationTime'});
testCount = choice_text(safe_property(resultObj, 'NumTotal', ''));
if ~isempty(testCount), testCount = [testCount ' tests']; end
details = nonempty_details({outcome, testCount, created});
label = sprintf('[Test Manager] %02d | %s%s', ...
    index, name, details);
end

function runs = list_toolkit_run_choices(cfg)
runs = repmat(struct('RunId', '', 'Label', ''), 0, 1);
if ~isfolder(cfg.TestRunRootDir), return; end
listing = dir(cfg.TestRunRootDir);
listing = listing([listing.isdir]);
listing = listing(~ismember({listing.name}, {'.','..'}));
if isempty(listing), return; end
[~, order] = sort([listing.datenum], 'descend');
listing = listing(order);

latestRunId = '';
try
    latest = jsondecode(fileread(cfg.LatestReportPointer));
    latestRunId = char(string(latest.RunId));
catch
end

for i = 1:numel(listing)
    runId = listing(i).name;
    runDirectory = fullfile(listing(i).folder, runId);
    if ~isfile(fullfile(runDirectory, 'TestSummary.xlsx')), continue; end
    status = run_manifest_status(runDirectory);
    modified = char(datetime(listing(i).datenum, ...
        'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    latestText = '';
    if strcmp(runId, latestRunId), latestText = ' | LATEST'; end
    label = sprintf('[Toolkit Run] %s | %s | %s%s', ...
        runId, status, modified, latestText);
    runs(end+1,1) = struct('RunId', runId, 'Label', label); %#ok<AGROW>
end
end

function status = run_manifest_status(runDirectory)
status = 'UNKNOWN';
try
    manifest = jsondecode(fileread(fullfile(runDirectory, 'manifest.json')));
    if isfield(manifest, 'Status')
        status = choice_text(manifest.Status);
    end
catch
end
if isempty(status), status = 'UNKNOWN'; end
end

function value = first_choice_property(object, properties)
value = '';
for i = 1:numel(properties)
    value = choice_text(safe_property(object, properties{i}, ''));
    if ~isempty(value), return; end
end
end

function value = choice_text(raw)
value = '';
if isempty(raw), return; end
try
    if isdatetime(raw)
        raw.Format = 'yyyy-MM-dd HH:mm:ss';
    end
    text = string(raw);
    text = text(~ismissing(text) & strlength(strtrim(text)) > 0);
    if ~isempty(text)
        value = regexprep(char(text(1)), '[\r\n]+', ' ');
    end
catch
end
end

function suffix = nonempty_details(values)
values = values(~cellfun(@isempty, values));
if isempty(values)
    suffix = '';
else
    suffix = [' | ' strjoin(values, ' | ')];
end
end

function selection = resolve_result_selection(resultObj, requestedRun, cfg, targets)
if ~isempty(resultObj)
    [summary, ~] = st_collect_test_result_summary( ...
        resultObj, targets, 'SELECTED');
    name = char(string(safe_property(resultObj, 'Name', 'manual_result')));
    if isempty(strtrim(name)), name = 'manual_result'; end
    selection = struct( ...
        'Type', 'ResultSet', ...
        'Name', ['resultset_' st_export_safe_name(name)], ...
        'DisplayName', name, ...
        'RunId', '', ...
        'Directory', '', ...
        'TestCaseNames', unique(summary.TestCaseName, 'stable'));
    return;
end

[runId, directory] = resolve_run(cfg, requestedRun);
summaryPath = fullfile(directory, 'TestSummary.xlsx');
if ~isfile(summaryPath)
    error('simtest:AssetRunSummaryMissing', ...
        'Selected run has no TestSummary.xlsx: %s', directory);
end
summary = readtable(summaryPath, 'Sheet', 'Targets', 'TextType', 'string');
required = {'Run','TestCaseName'};
if ~all(ismember(required, summary.Properties.VariableNames))
    error('simtest:AssetRunSummaryInvalid', ...
        ['Selected run Targets sheet must contain Run and ' ...
         'TestCaseName columns: %s'], summaryPath);
end
summary = summary(upper(string(summary.Run)) == "FINAL", :);
selection = struct( ...
    'Type', 'RunId', ...
    'Name', runId, ...
    'DisplayName', runId, ...
    'RunId', runId, ...
    'Directory', directory, ...
    'TestCaseNames', unique(string(summary.TestCaseName), 'stable'));
end

function [runId, directory] = resolve_run(cfg, requested)
if strcmpi(requested, 'LATEST')
    if ~isfile(cfg.LatestReportPointer)
        error('simtest:AssetRunMissing', ...
            'Latest report pointer is missing: %s', cfg.LatestReportPointer);
    end
    latest = jsondecode(fileread(cfg.LatestReportPointer));
    runId = char(string(latest.RunId));
    directory = char(string(latest.RunDirectory));
else
    runId = strtrim(char(string(requested)));
    directory = fullfile(cfg.TestRunRootDir, runId);
end
if isempty(runId) || ~strcmp(runId, st_export_safe_name(runId))
    error('simtest:AssetRunIdInvalid', ...
        'RunId must be a portable folder name: %s', runId);
end
st_export_relative_path(directory, cfg.TestRunRootDir);
if ~isfolder(directory)
    error('simtest:AssetRunMissing', ...
        'Selected run directory is missing: %s', directory);
end
end

function info = existing_report_info(selection, outputDirectory)
artifacts = empty_artifact_table();
artifacts = file_artifact(artifacts, 'EXCEL', ...
    fullfile(outputDirectory, 'TestSummary.xlsx'), ...
    'Selected toolkit summary copied');
artifacts = matching_file_artifact(artifacts, 'MLDATX', ...
    fullfile(outputDirectory, 'raw'), '*.mldatx', ...
    'Selected toolkit raw results copied');
artifacts = matching_file_artifact(artifacts, 'PDF', ...
    fullfile(outputDirectory, 'official'), '*.pdf', ...
    'Selected toolkit PDF report copied');
artifacts = matching_file_artifact(artifacts, 'HTML', ...
    fullfile(outputDirectory, 'coverage'), '*.html', ...
    'Selected toolkit coverage HTML copied');

coverageMessage = 'Selected toolkit coverage rows copied';
coverageStatus = 'OK';
try
    coverage = readtable(fullfile(outputDirectory, 'TestSummary.xlsx'), ...
        'Sheet', 'Coverage', 'TextType', 'string');
    if isempty(coverage)
        coverageStatus = 'FAIL';
        coverageMessage = 'Selected toolkit run contains no coverage rows';
    end
catch ME
    coverageStatus = 'FAIL';
    coverageMessage = ME.message;
end
artifacts = record_artifact(artifacts, 'COVERAGE_DATA', '', ...
    coverageStatus, coverageMessage);

manifestPath = fullfile(selection.Directory, 'manifest.json');
coverageDetail = 'FULL';
coverageReportMode = 'SOURCE';
if isfile(manifestPath)
    value = jsondecode(fileread(manifestPath));
    if isfield(value, 'CoverageDetail')
        coverageDetail = char(string(value.CoverageDetail));
    end
    if isfield(value, 'CoverageReportMode')
        coverageReportMode = char(string(value.CoverageReportMode));
    end
    if isfield(value, 'Status') && ...
            ~strcmpi(char(string(value.Status)), 'OK')
        artifacts = record_artifact(artifacts, 'SOURCE_REPORT', ...
            fullfile(outputDirectory, 'manifest.json'), 'FAIL', ...
            ['Selected toolkit report status: ' ...
             char(string(value.Status))]);
    end
end
status = char(st_report_status(artifacts.Status));
failures = sum(artifacts.Status == "FAIL");
info = struct( ...
    'Name', selection.Name, ...
    'Directory', outputDirectory, ...
    'Summary', fullfile(outputDirectory, 'TestSummary.xlsx'), ...
    'Status', status, ...
    'ArtifactFailures', failures, ...
    'CoverageDetail', coverageDetail, ...
    'CoverageReportMode', coverageReportMode, ...
    'Artifacts', artifacts);
end

function validate_selected_harnesses(targets, cfg)
for i = 1:height(targets)
    owner = char(st_normalize_cut_path(targets.CUTPath(i), cfg.TopModel));
    harness = char(string(targets.HarnessName(i)));
    matches = sltest.harness.find( ...
        owner, 'SearchDepth', 0, 'Name', harness);
    if numel(matches) ~= 1
        error('simtest:AssetHarnessMappingInvalid', ...
            'Expected one Harness for %s, found %d.', ...
            char(string(targets.TestCaseName(i))), numel(matches));
    end
end
end

function inventory = all_harness_inventory(topModel)
harnesses = sltest.harness.find(topModel);
inventory = strings(numel(harnesses), 1);
for i = 1:numel(harnesses)
    owner = char(string(safe_property( ...
        harnesses(i), 'ownerFullPath', '')));
    name = char(string(safe_property(harnesses(i), 'name', '')));
    inventory(i) = string(owner) + "|" + string(name);
end
inventory = sort(inventory);
end

function assert_saved_sources(cfg)
if bdIsLoaded(cfg.TopModel) && strcmp(get_param(cfg.TopModel, 'Dirty'), 'on')
    error('simtest:AssetUnsavedModel', ...
        'Save the model and internal Harnesses before asset export.');
end
testFile = sltest.testmanager.TestFile(cfg.TestFile);
if isprop(testFile, 'Dirty') && logical(testFile.Dirty)
    error('simtest:AssetUnsavedTestFile', ...
        'Save the Test Manager file before asset export.');
end
end

function assert_signature_unchanged(path, original)
current = st_file_signature(path);
if ~strcmp(current.SHA256, original.SHA256)
    error('simtest:AssetSourceChanged', ...
        'Source file changed during asset export: %s', path);
end
end

function value = result_selection_manifest(selection, root, resultOutput)
value = struct( ...
    'Type', selection.Type, ...
    'Name', selection.DisplayName, ...
    'RunId', selection.RunId, ...
    'Path', bundle_path(root, resultOutput));
end

function values = manifest_artifacts(artifacts, root)
values = table2struct(artifacts);
for i = 1:numel(values)
    path = char(string(values(i).Path));
    if ~isempty(path) && (isfile(path) || isfolder(path))
        values(i).Path = bundle_path(root, path);
    else
        values(i).Path = '';
    end
end
end

function inventory = inventory_files_light(root, excluded)
listing = dir(fullfile(root, '**', '*'));
inventory = repmat(struct( ...
    'BundlePath', '', 'SHA256', '', 'Bytes', 0), 0, 1);
for i = 1:numel(listing)
    if listing(i).isdir, continue; end
    path = fullfile(listing(i).folder, listing(i).name);
    relative = bundle_path(root, path);
    if any(strcmp(relative, excluded)), continue; end
    inventory(end+1,1) = struct( ...
        'BundlePath', relative, 'SHA256', '', ...
        'Bytes', double(listing(i).bytes)); %#ok<AGROW>
end
end

function copy_checked(source, destination)
parent = fileparts(destination);
if ~isfolder(parent), mkdir(parent); end
[ok, message] = copyfile(source, destination, 'f');
if ~ok
    error('simtest:AssetCopyFailed', ...
        'Cannot copy %s to %s: %s', source, destination, message);
end
end

function artifacts = empty_artifact_table()
artifacts = table(strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), ...
    'VariableNames', {'Type','Path','Status','Message'});
end

function artifacts = file_artifact(artifacts, type, path, message)
if isfile(path)
    status = 'OK';
else
    status = 'FAIL';
    message = ['Missing result artifact: ' path];
end
artifacts = record_artifact(artifacts, type, path, status, message);
end

function artifacts = matching_file_artifact( ...
        artifacts, type, folder, pattern, message)
matches = dir(fullfile(folder, '**', pattern));
matches = matches(~[matches.isdir]);
if isempty(matches)
    artifacts = record_artifact(artifacts, type, folder, 'FAIL', ...
        ['Missing result artifact: ' fullfile(folder, pattern)]);
else
    artifacts = record_artifact(artifacts, type, folder, 'OK', message);
end
end

function artifacts = record_artifact(artifacts, type, path, status, message)
artifacts(end+1,:) = {string(type), string(path), ...
    string(status), string(message)};
end

function write_json(path, value)
write_text(path, jsonencode(value, 'PrettyPrint', true));
end

function write_text(path, value)
fileId = fopen(path, 'w', 'n', 'UTF-8');
if fileId < 0
    error('simtest:AssetWriteFailed', 'Cannot write file: %s', path);
end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, '%s', value);
end

function value = safe_property(object, property, defaultValue)
try
    value = object.(property);
catch
    value = defaultValue;
end
end

function valid = is_text_scalar(value)
valid = (ischar(value) && (isempty(value) || isrow(value))) || ...
    (isstring(value) && isscalar(value));
end

function close_source_model(model, openedHere)
if openedHere && bdIsLoaded(model), close_system(model, 0); end
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

function timerValue = start_step(cfg, label)
fprintf('\n============================================\n');
fprintf('%s\nSTART : %s\n', label, timestamp_text());
fprintf('============================================\n');
st_log(cfg, 'INFO', '[AssetExport] stage start | %s', label);
timerValue = tic;
end

function finish_step(cfg, label, timerValue)
fprintf('DONE    : %s\nELAPSED : %s\n', ...
    label, elapsed_text(toc(timerValue)));
st_log(cfg, 'INFO', ...
    '[AssetExport] stage done | %s | elapsed=%.3f sec', ...
    label, toc(timerValue));
end

function fail_step(cfg, label, timerValue, exception)
fprintf('FAILED  : %s\nERROR   : %s\nELAPSED : %s\n', ...
    label, exception.message, elapsed_text(toc(timerValue)));
st_log(cfg, 'ERROR', ...
    '[AssetExport] stage failed | %s | %s: %s | elapsed=%.3f sec', ...
    label, exception.identifier, exception.message, toc(timerValue));
end

function value = timestamp_text()
value = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function value = iso_timestamp_text()
value = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end

function value = elapsed_text(secondsValue)
value = sprintf('%02d:%02d:%06.3f', floor(secondsValue / 3600), ...
    floor(mod(secondsValue, 3600) / 60), mod(secondsValue, 60));
end

function value = bundle_path(root, path)
value = strrep(st_export_relative_path(path, root), '\', '/');
end
