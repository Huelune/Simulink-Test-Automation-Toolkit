function manifest = st_package_standalone_coverage_artifacts( ...
        outputRoot, manifest, runtimeContext)
%ST_PACKAGE_STANDALONE_COVERAGE_ARTIFACTS Package each live/imported Result.

cfg = st_require_runtime_target('LoadModel', false);
timerValue = tic;
pipelineRoot = fullfile(outputRoot, char(string(manifest.PipelineId)));
st_log(cfg, 'INFO', ...
    'Standalone coverage PACKAGE start | PipelineId=%s', ...
    char(string(manifest.PipelineId)));
require_action(manifest, 'EXECUTE');
require_not_started(manifest, 'PACKAGE');
manifest.Actions.PACKAGE = action_state('RUNNING', ...
    'Packaging live or persisted Result objects');
st_write_standalone_pipeline_manifest(outputRoot, manifest);

[resultRoots, importCount, resultSource] = ...
    resolve_results(manifest, runtimeContext, cfg);
manifest.ResultImportCount = importCount;
manifest.PackageResultSource = resultSource;
manifest = package_test_file(manifest, pipelineRoot, cfg);

for i = 1:numel(manifest.Targets)
    item = manifest.Targets(i);
    folderName = sprintf('%03d_%s', round(double(item.No)), ...
        st_artifact_stem(item.TestCaseName));
    targetDirectory = fullfile(pipelineRoot, folderName);
    if ~isfolder(targetDirectory), mkdir(targetDirectory); end
    item.OutputDirectory = targetDirectory;
    item.TargetManifest = fullfile(targetDirectory, ...
        'target-manifest.json');
    st_log(cfg, 'INFO', ...
        '[PACKAGE %d/%d] start | CUT=%s', ...
        i, numel(manifest.Targets), item.CUTName);
    try
        % Preserve the standalone harness and its local input even when
        % this target's Test Manager execution ended in an exception.
        item = package_execution_inputs(item, targetDirectory, cfg);
        st_log(cfg, 'INFO', ...
            '[PACKAGE %d/%d] standalone inputs preserved | CUT=%s', ...
            i, numel(manifest.Targets), item.CUTName);
        executionStatus = upper(string(item.ExecutionStatus));
        if executionStatus == "EXCEPT"
            error('simtest:StandalonePipelineExecuteTargetException', ...
                'EXECUTE ended with an exception; coverage artifacts are unavailable.');
        elseif executionStatus == "FAIL"
            error('simtest:StandalonePipelineExecuteTargetFailed', ...
                'EXECUTE did not satisfy the target lifecycle contract.');
        end
        resultObj = resolve_target_result(resultRoots, item);
        item = package_target(item, resultObj, targetDirectory, cfg);
        item.PackageStatus = 'OK';
        st_log(cfg, 'INFO', ...
            '[PACKAGE %d/%d] complete | CUT=%s', ...
            i, numel(manifest.Targets), item.CUTName);
    catch ME
        item.PackageStatus = 'FAIL';
        item.PackageFailure = package_failure_detail(ME);
        item.Message = append_message(item.Message, ...
            sprintf('%s: %s', ME.identifier, ME.message));
        st_log(cfg, 'ERROR', ...
            '[PACKAGE %d/%d] failed | CUT=%s | %s: %s', ...
            i, numel(manifest.Targets), item.CUTName, ...
            ME.identifier, ME.message);
    end
    write_target_manifest(item.TargetManifest, item);
    manifest.Targets(i) = item;
    manifest.UpdatedAt = timestamp_text();
    st_write_standalone_pipeline_manifest(outputRoot, manifest);
end

status = target_action_status(manifest.Targets, 'PackageStatus');
manifest.PackageInventory = st_package_inventory(manifest);
manifest.Actions.PACKAGE = action_state(status, ...
    'Model, Input, CVF, CVT, and one HTML report packaged per target');
manifest.Status = pipeline_status(manifest);
manifest.UpdatedAt = timestamp_text();
st_log(cfg, 'INFO', ...
    'Standalone coverage PACKAGE complete | Status=%s | elapsed=%.3f sec', ...
    status, toc(timerValue));
end

function [roots, importCount, source] = resolve_results(manifest, context, cfg)
importCount = 0;
source = '';
if isstruct(context) && isfield(context, 'Results') && ...
        ~isempty(context.Results)
    raw = context.Results;
    roots = cell(numel(raw),1);
    for i = 1:numel(raw)
        roots{i} = raw(i).FinalResult;
    end
    st_log(cfg, 'DEBUG', ...
        'PACKAGE is using live Result objects | Targets=%d', numel(roots));
    source = 'LIVE';
    return;
end
if ~isfield(manifest, 'CanResumePackage') || ...
        ~logical(manifest.CanResumePackage) || ...
        ~isfield(manifest, 'ResultFile') || ...
        ~isfile(char(string(manifest.ResultFile)))
    error('simtest:StandalonePipelineResultUnavailable', ...
        ['PACKAGE requires live Result objects from ALL or an EXECUTE run ' ...
         'created with SaveTestResult=true.']);
end
signature = st_file_signature(manifest.ResultFile);
if ~strcmpi(signature.SHA256, char(string(manifest.ResultSHA256)))
    error('simtest:StandalonePipelineResultChecksumMismatch', ...
        'Saved aggregate Result checksum changed: %s', manifest.ResultFile);
end
st_log(cfg, 'INFO', ...
    'PACKAGE aggregate Result import start | File=%s', manifest.ResultFile);
imported = sltest.testmanager.importResults(manifest.ResultFile);
importCount = 1;
source = 'IMPORTED';
roots = cell(numel(imported),1);
for i = 1:numel(imported), roots{i} = imported(i); end
st_log(cfg, 'INFO', ...
    'PACKAGE aggregate Result import complete | Roots=%d', numel(roots));
end

function resultObj = resolve_target_result(roots, item)
matches = false(numel(roots),1);
for i = 1:numel(roots)
    cases = st_collect_test_case_results(roots{i});
    names = strings(numel(cases),1);
    for j = 1:numel(cases)
        try, names(j) = string(cases{j}.Name); catch, end
    end
    matches(i) = any(names == string(item.TestCaseName));
end
indices = find(matches);
if numel(indices) ~= 1
    error('simtest:StandalonePipelineResultMappingAmbiguous', ...
        'Expected one Result root for Test Case %s, found %d.', ...
        item.TestCaseName, numel(indices));
end
resultObj = roots{indices};
end

function manifest = package_test_file(manifest, pipelineRoot, cfg)
testManagerDirectory = fullfile(pipelineRoot, 'TestManager');
if ~isfolder(testManagerDirectory), mkdir(testManagerDirectory); end
if ~isfile(manifest.TestManagerWorkFile)
    error('simtest:StandalonePipelineTestFileMissing', ...
        'Rewired working Test File is missing: %s', ...
        char(string(manifest.TestManagerWorkFile)));
end
[~, name, extension] = fileparts(manifest.TestManagerWorkFile);
destination = fullfile(testManagerDirectory, [name extension]);
copy_checked(manifest.TestManagerWorkFile, destination);
manifest.TestManagerFile = destination;
manifest.TestManagerSHA256 = st_file_signature(destination).SHA256;
launcherSource = fullfile(st_project_root(), 'resources', ...
    'standalone_coverage', 'open_standalone_coverage_test_manager.m');
if ~isfile(launcherSource)
    error('simtest:StandalonePipelineTestManagerLauncherMissing', ...
        'Packaged Test Manager launcher template is missing: %s', ...
        launcherSource);
end
launcher = fullfile(testManagerDirectory, ...
    'open_standalone_coverage_test_manager.m');
copy_checked(launcherSource, launcher);
manifest.TestManagerLauncher = launcher;
manifest.TestManagerLauncherSHA256 = st_file_signature(launcher).SHA256;
st_log(cfg, 'INFO', ...
    ['PACKAGE Test Manager launcher complete | TestFile=%s | ' ...
     'Launcher=%s'], destination, launcher);
end

function item = package_target(item, resultObj, targetDirectory, cfg) %#ok<INUSD>
sourceCVF = item.ExecutionCVFPath;
if ~isfile(sourceCVF)
    error('simtest:StandalonePipelineCVFMissing', ...
        'Generated CVF is missing: %s', sourceCVF);
end
finalCVF = fullfile(targetDirectory, ...
    [st_artifact_stem(item.TestCaseName) '.cvf']);
copy_checked(sourceCVF, finalCVF);
item.PackagedCVF = finalCVF;
item.PackagedCVFSHA256 = st_file_signature(finalCVF).SHA256;

item = package_captured_report_and_metrics(item, targetDirectory, cfg);
end

function item = package_captured_report_and_metrics( ...
        item, targetDirectory, cfg)
st_log(cfg, 'INFO', ...
    'PACKAGE captured report promotion start | CUT=%s', item.CUTName);
try
    if ~isfield(item, 'PackageEvidenceStatus') || ...
            ~strcmpi(char(string(item.PackageEvidenceStatus)), 'OK')
        evidenceStatus = 'MISSING';
        if isfield(item, 'PackageEvidenceStatus')
            evidenceStatus = char(string(item.PackageEvidenceStatus));
        end
        error('simtest:StandalonePipelinePackageEvidenceNotReady', ...
            'Package evidence is not ready for %s: %s', ...
            item.CUTName, evidenceStatus);
    end
    evidencePath = char(string(item.PackageEvidence));
    require_signature(evidencePath, item.PackageEvidenceSHA256, ...
        'simtest:StandalonePipelinePackageEvidenceInvalid');
    evidence = decode_package_evidence(evidencePath, item);
    reportZip = char(string(evidence.CoverageReportZip));
    require_signature(reportZip, evidence.CoverageReportZipSHA256, ...
        'simtest:StandalonePipelinePackageReportInvalid');
    sourceCVT = char(string(evidence.CoverageResult));
    require_signature(sourceCVT, evidence.CoverageResultSHA256, ...
        'simtest:StandalonePipelinePackageCoverageInvalid');

    cvtPath = fullfile(targetDirectory, ...
        [st_artifact_stem(item.TestCaseName) '.cvt']);
    delete_if_present(cvtPath);
    st_log(cfg, 'INFO', ...
        'PACKAGE captured coverage data promotion start | CUT=%s', item.CUTName);
    copy_checked(sourceCVT, cvtPath);
    item.CoverageResult = cvtPath;
    item.CoverageResultSHA256 = st_file_signature(cvtPath).SHA256;
    st_log(cfg, 'INFO', ...
        'PACKAGE captured coverage data promotion complete | CUT=%s', item.CUTName);

    % Keep report.html at the target root. cvhtml's companion assets must
    % remain beside it, otherwise the official report cannot be rendered.
    reportDirectory = targetDirectory;
    unzip(reportZip, reportDirectory);
    ensure_report_html(reportDirectory);
    reportHTML = fullfile(reportDirectory, ...
        [st_artifact_stem(item.TestCaseName) '.html']);
    rootReport = fullfile(reportDirectory, 'report.html');
    if ~strcmpi(rootReport, reportHTML)
        [moved, moveMessage] = movefile(rootReport, reportHTML, 'f');
        if ~moved
            error('simtest:StandalonePipelinePackageReportRenameFailed', ...
                'Cannot rename report %s to %s: %s', ...
                rootReport, reportHTML, moveMessage);
        end
    end
    item.TestReport = reportDirectory;
    item.ReportHTML = reportHTML;

    item = assign_metric(item, evidence.Decision, 'Decision');
    item = assign_metric(item, evidence.Execution, 'Execution');
    item.MetricSource = char(string(evidence.MetricSource));
    item.MetricSourceStatus = char(string(evidence.MetricSourceStatus));
    if strcmp(item.MetricSourceStatus, 'AMBIGUOUS')
        error('simtest:StandalonePipelineMetricAmbiguous', ...
            'Coverage metric source is ambiguous for %s.', item.CUTName);
    end
    st_log(cfg, 'INFO', ...
        'PACKAGE captured report promotion complete | CUT=%s', ...
        item.CUTName);
catch ME
    st_log(cfg, 'ERROR', ...
        'PACKAGE captured report promotion failed | CUT=%s | %s: %s', ...
        item.CUTName, ME.identifier, ME.message);
    rethrow(ME);
end
end

function evidence = decode_package_evidence(path, item)
try
    evidence = jsondecode(fileread(path));
catch ME
    error('simtest:StandalonePipelinePackageEvidenceInvalid', ...
        'Cannot read package evidence %s: %s', path, ME.message);
end
required = {'Version','No','CUTName','TestCaseName','StandaloneModel', ...
    'CoverageResult','CoverageResultSHA256', ...
    'CoverageReportZip','CoverageReportZipSHA256', ...
    'Decision','Execution', ...
    'MetricSource','MetricSourceStatus'};
if ~isstruct(evidence) || ~all(isfield(evidence, required)) || ...
        double(evidence.Version) ~= 2 || ...
        double(evidence.No) ~= double(item.No) || ...
        ~strcmp(char(string(evidence.CUTName)), item.CUTName) || ...
        ~strcmp(char(string(evidence.TestCaseName)), item.TestCaseName) || ...
        ~strcmp(char(string(evidence.StandaloneModel)), ...
            item.StandaloneModel)
    error('simtest:StandalonePipelinePackageEvidenceInvalid', ...
        'Package evidence identity is invalid for %s: %s', ...
        item.CUTName, path);
end
end

function require_signature(path, expected, identifier)
path = char(string(path));
expected = char(string(expected));
if isempty(path) || isempty(expected) || ~isfile(path)
    error(identifier, 'Required package evidence is missing: %s', path);
end
actual = st_file_signature(path).SHA256;
if ~strcmpi(actual, expected)
    error(identifier, 'Package evidence checksum changed: %s', path);
end
end

function item = package_execution_inputs(item, targetDirectory, cfg)
st_log(cfg, 'DEBUG', ...
    'PACKAGE standalone inputs start | CUT=%s', item.CUTName);
if ~isfile(item.StandaloneModelFile)
    error('simtest:StandalonePipelineModelMissing', ...
        'Standalone model is missing: %s', item.StandaloneModelFile);
end
[~, modelName, extension] = fileparts(item.StandaloneModelFile);
if ~strcmp(modelName, item.HarnessName) || ...
        ~strcmp(modelName, item.StandaloneModel)
    error('simtest:StandalonePipelineModelNameMismatch', ...
        'Harness, standalone model, and file stem must match for %s.', ...
        item.CUTName);
end
modelDestination = fullfile(targetDirectory, [modelName extension]);
copy_checked(item.StandaloneModelFile, modelDestination);
item.PackagedStandaloneModel = modelDestination;

if isempty(item.SignalEditorInput)
    item.PackagedInputReadbackStatus = 'NOT_REQUIRED';
else
    if ~isfile(item.SignalEditorInput)
        error('simtest:StandalonePipelineInputMissing', ...
            'Standalone input is missing: %s', item.SignalEditorInput);
    end
    [~, inputName, inputExtension] = fileparts(item.SignalEditorInput);
    inputDestination = fullfile(targetDirectory, ...
        [inputName inputExtension]);
    copy_checked(item.SignalEditorInput, inputDestination);
    item.PackagedInput = inputDestination;
    item.PackagedInputSHA256 = st_file_signature(inputDestination).SHA256;
    item = rewire_packaged_input(item, [inputName inputExtension], cfg);
end
item.PackagedStandaloneModelSHA256 = ...
    st_file_signature(modelDestination).SHA256;
st_log(cfg, 'DEBUG', ...
    'PACKAGE standalone inputs complete | CUT=%s', item.CUTName);
end

function item = rewire_packaged_input(item, relativeInput, cfg)
modelFile = item.PackagedStandaloneModel;
modelName = item.StandaloneModel;
folder = fileparts(modelFile);
if bdIsLoaded(modelName)
    loadedFile = char(string(get_param(modelName, 'FileName')));
    st_log(cfg, 'ERROR', ...
        ['PACKAGE input readback model isolation failed | CUT=%s | ' ...
         'Model=%s | LoadedFile=%s'], ...
        item.CUTName, modelName, loadedFile);
    error('simtest:StandalonePipelineModelIsolationFailed', ...
        ['Model %s is already loaded before PACKAGE readback. ' ...
         'The loaded model was not closed or replaced: %s'], ...
        modelName, loadedFile);
end
previousDirectory = pwd;
cleanup = onCleanup(@() restore_model_context( ...
    modelName, previousDirectory)); %#ok<NASGU>
cd(folder);
load_system(modelFile);
block = st_find_signal_editor_block(modelName);
set_param(block, 'Filename', relativeInput);
save_system(modelName);
actual = char(string(get_param(block, 'Filename')));
if ~strcmp(actual, relativeInput)
    error('simtest:StandalonePipelineInputReadbackFailed', ...
        'Packaged Input path readback failed for %s.', item.CUTName);
end
close_system(modelName, 0);
item.PackagedInputReadbackStatus = 'OK';
st_log(cfg, 'DEBUG', ...
    'PACKAGE relative Input readback complete | CUT=%s | Input=%s', ...
    item.CUTName, relativeInput);
end

function restore_model_context(modelName, directory)
try
    if bdIsLoaded(modelName), close_system(modelName, 0); end
catch
end
cd(directory);
end

function item = assign_metric(item, metric, name)
item.([name 'Covered']) = double(metric.Covered);
item.([name 'Total']) = double(metric.Total);
item.([name 'Percentage']) = double(metric.Percentage);
item.([name 'PercentageText']) = char(string(metric.PercentageText));
item.([name 'MetricStatus']) = char(string(metric.Status));
end

function ensure_report_html(reportDirectory)
rootReport = fullfile(reportDirectory, 'report.html');
if isfile(rootReport), return; end
matches = dir(fullfile(reportDirectory, '**', 'report.html'));
if isempty(matches)
    error('simtest:StandalonePipelineHTMLReportMissing', ...
        'The original Coverage report ZIP contains no report.html.');
end
sourceFolder = matches(1).folder;
entries = dir(sourceFolder);
entries = entries(~ismember({entries.name}, {'.','..'}));
for i = 1:numel(entries)
    source = fullfile(entries(i).folder, entries(i).name);
    destination = fullfile(reportDirectory, entries(i).name);
    if entries(i).isdir
        [ok, message] = copyfile(source, destination, 'f');
        if ~ok
            error('simtest:StandalonePipelineReportCopyFailed', ...
                'Cannot copy report resource %s: %s', source, message);
        end
    else
        copy_checked(source, destination);
    end
end
if ~isfile(rootReport)
    error('simtest:StandalonePipelineHTMLReportMissing', ...
        'Cannot place report.html at the Coverage Report root.');
end
end

function require_action(manifest, name)
if ~ismember(double(manifest.Version), [2 3]) || ~isfield(manifest, 'Actions') || ...
        ~isfield(manifest.Actions, name) || ...
        ~ismember(upper(string(manifest.Actions.(name).Status)), ["OK","WARN"])
    error('simtest:StandalonePipelineActionNotReady', ...
        '%s must complete before PACKAGE.', name);
end
end

function require_not_started(manifest, name)
if ~isfield(manifest, 'Actions') || ~isfield(manifest.Actions, name) || ...
        ~strcmpi(char(string(manifest.Actions.(name).Status)), 'NOT_RUN')
    error('simtest:StandalonePipelineActionAlreadyStarted', ...
        ['%s can run only once per pipeline. Start a new EXECUTE action ' ...
         'instead of regenerating lifecycle artifacts.'], name);
end
end

function copy_checked(source, destination)
parent = fileparts(destination);
if ~isfolder(parent), mkdir(parent); end
[ok, message] = copyfile(source, destination, 'f');
if ~ok || ~isfile(destination)
    error('simtest:StandalonePipelineCopyFailed', ...
        'Cannot copy %s to %s: %s', source, destination, message);
end
end

function write_target_manifest(path, item)
temporary = [tempname(fileparts(path)) '.json'];
cleanup = onCleanup(@() delete_if_present(temporary)); %#ok<NASGU>
fileId = fopen(temporary, 'w', 'n', 'UTF-8');
if fileId < 0
    error('simtest:StandaloneTargetManifestWriteFailed', ...
        'Cannot write target manifest: %s', path);
end
fileCleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', jsonencode(item, 'PrettyPrint', true));
clear fileCleanup;
[ok, message] = movefile(temporary, path, 'f');
if ~ok
    error('simtest:StandaloneTargetManifestWriteFailed', ...
        'Cannot replace target manifest: %s', message);
end
end

function delete_if_present(path)
if isfile(path), delete(path); end
end

function value = append_message(existing, added)
if isempty(existing), value = added; else, value = [existing ' | ' added]; end
end

function value = package_failure_detail(exception)
frames = repmat(struct('Name', '', 'File', '', 'Line', 0), 0, 1);
for i = 1:numel(exception.stack)
    frame = exception.stack(i);
    frames(end+1,1) = struct( ...
        'Name', char(string(frame.name)), ...
        'File', char(string(frame.file)), ...
        'Line', double(frame.line)); %#ok<AGROW>
end
value = struct( ...
    'Identifier', char(string(exception.identifier)), ...
    'Message', char(string(exception.message)), ...
    'Stack', frames);
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

function value = timestamp_text()
value = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end
