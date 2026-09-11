function manifest = st_package_standalone_coverage_artifacts( ...
        outputRoot, manifest, reportMode)
%ST_PACKAGE_STANDALONE_COVERAGE_ARTIFACTS Build final per-CUT artifacts.

cfg = st_require_runtime_target();
timerValue = tic;
pipelineRoot = fullfile(outputRoot, char(string(manifest.PipelineId)));
st_log(cfg, 'INFO', ...
    'Standalone coverage STEP5 start | PipelineId=%s', ...
    char(string(manifest.PipelineId)));
require_step(manifest, 'STEP234');
manifest.Steps.STEP5 = step_state('RUNNING', ...
    'Packaging filtered result artifacts');
st_write_standalone_pipeline_manifest(outputRoot, manifest);

testManagerDirectory = fullfile(pipelineRoot, 'TestManager');
if ~isfolder(testManagerDirectory), mkdir(testManagerDirectory); end
if ~isfile(manifest.TestManagerWorkFile)
    error('simtest:StandalonePipelineTestFileMissing', ...
        'Rewired working Test File is missing: %s', ...
        char(string(manifest.TestManagerWorkFile)));
end
[~, testName, testExtension] = fileparts(manifest.TestManagerWorkFile);
testManagerPath = fullfile(testManagerDirectory, ...
    [testName testExtension]);
copy_checked(manifest.TestManagerWorkFile, testManagerPath);
manifest.TestManagerFile = testManagerPath;
manifest.TestManagerSHA256 = st_file_signature(testManagerPath).SHA256;

for i = 1:numel(manifest.Targets)
    item = manifest.Targets(i);
    folderName = sprintf('%03d_%s', i, ...
        st_export_safe_name(item.CUTName));
    targetDirectory = fullfile(pipelineRoot, folderName);
    if ~isfolder(targetDirectory), mkdir(targetDirectory); end
    item.OutputDirectory = targetDirectory;
    item.TargetManifest = fullfile(targetDirectory, ...
        'target-manifest.json');
    st_log(cfg, 'INFO', ...
        '[STEP5 %d/%d] start | CUT=%s', ...
        i, numel(manifest.Targets), item.CUTName);
    if strcmpi(item.Step234Status, 'FAIL') || ...
            ~strcmpi(item.ResultFilterStatus, 'OK')
        item.Step5Status = 'SKIP';
        item.Message = append_message(item.Message, ...
            ['STEP5 skipped because STEP234 did not produce ' ...
             'a verified filtered result']);
        write_target_manifest(item.TargetManifest, item);
        manifest.Targets(i) = item;
        continue;
    end
    try
        item = package_target(item, targetDirectory, pipelineRoot, ...
            reportMode, cfg);
        item.Step5Status = 'OK';
        write_target_manifest(item.TargetManifest, item);
        st_log(cfg, 'INFO', ...
            '[STEP5 %d/%d] complete | CUT=%s', ...
            i, numel(manifest.Targets), item.CUTName);
    catch ME
        item.Step5Status = 'FAIL';
        item.Message = sprintf('%s: %s', ME.identifier, ME.message);
        write_target_manifest(item.TargetManifest, item);
        st_log(cfg, 'ERROR', ...
            '[STEP5 %d/%d] failed | CUT=%s | %s: %s', ...
            i, numel(manifest.Targets), item.CUTName, ...
            ME.identifier, ME.message);
    end
    manifest.Targets(i) = item;
    manifest.UpdatedAt = timestamp_text();
    st_write_standalone_pipeline_manifest(outputRoot, manifest);
end

values = upper(string({manifest.Targets.Step5Status}));
if any(values == "FAIL" | values == "SKIP")
    finalStatus = 'WARN';
else
    finalStatus = 'OK';
end
manifest.Steps.STEP5 = step_state(finalStatus, ...
    'Per-CUT standalone coverage artifacts packaged');
manifest.Status = pipeline_status(manifest);
manifest.UpdatedAt = timestamp_text();
st_log(cfg, 'INFO', ...
    'Standalone coverage STEP5 complete | elapsed=%.3f sec', ...
    toc(timerValue));
end

function value = append_message(existing, added)
if isempty(existing)
    value = added;
else
    value = [existing ' | ' added];
end
end

function item = package_target(item, targetDirectory, pipelineRoot, ...
        reportMode, cfg)
pathCleanup = register_target_folder(targetDirectory); %#ok<NASGU>
if ~isfile(item.StandaloneModelFile)
    error('simtest:StandalonePipelineModelMissing', ...
        'Standalone model is missing: %s', item.StandaloneModelFile);
end
[~, modelName, modelExtension] = fileparts(item.StandaloneModelFile);
modelDestination = fullfile(targetDirectory, ...
    [modelName modelExtension]);
copy_checked(item.StandaloneModelFile, modelDestination);
item.PackagedStandaloneModel = modelDestination;
item.PackagedStandaloneModelSHA256 = ...
    st_file_signature(modelDestination).SHA256;

if ~isempty(item.SignalEditorInput)
    if ~isfile(item.SignalEditorInput)
        error('simtest:StandalonePipelineInputMissing', ...
            'Standalone input is missing: %s', item.SignalEditorInput);
    end
    inputDestination = fullfile(targetDirectory, ...
        [st_export_safe_name(item.CUTName) '_Input.mat']);
    copy_checked(item.SignalEditorInput, inputDestination);
    item.PackagedInput = inputDestination;
    item.PackagedInputSHA256 = ...
        st_file_signature(inputDestination).SHA256;
end

sourceCVF = item.CVFPath;
if isfield(item, 'ExecutionCVFPath') && ...
        ~isempty(item.ExecutionCVFPath)
    sourceCVF = item.ExecutionCVFPath;
end
if ~isfile(sourceCVF)
    error('simtest:StandalonePipelineCVFMissing', ...
        'Generated CVF is missing: %s', sourceCVF);
end
finalCVF = fullfile(targetDirectory, ...
    [st_export_safe_name(item.CUTName) '_CoverageFilter.cvf']);
if ~same_path(sourceCVF, finalCVF)
    copy_checked(sourceCVF, finalCVF);
end
item.CVFPath = finalCVF;
item.CVFSHA256 = st_file_signature(finalCVF).SHA256;

rawResult = selected_result_file(item);
roundtripDirectory = fullfile(pipelineRoot, '.work', ...
    'roundtrip', sprintf('%03d_%s', item.Order, ...
    st_export_safe_name(item.CUTName)));
if ~isfolder(roundtripDirectory), mkdir(roundtripDirectory); end
filteredResult = fullfile(roundtripDirectory, 'FilteredResults.mldatx');
delete_if_present(filteredResult);

st_log(cfg, 'DEBUG', ...
    'STEP5 result import start | CUT=%s | Result=%s', ...
    item.CUTName, rawResult);
resultObj = sltest.testmanager.importResults(rawResult);
if numel(resultObj) ~= 1
    error('simtest:StandalonePipelineResultImportAmbiguous', ...
        'Expected one imported ResultSet, found %d.', numel(resultObj));
end
st_apply_result_coverage_filters(resultObj, finalCVF, cfg, ...
    'RequireCoverage', true, ...
    'CoveragePath', item.StandaloneCUTPath, ...
    'RequireExactSet', true);
sltest.testmanager.exportResults(resultObj, filteredResult);
if ~isfile(filteredResult)
    error('simtest:StandalonePipelineResultExportMissing', ...
        'Filtered result export was not created: %s', filteredResult);
end
roundtripResult = sltest.testmanager.importResults(filteredResult);
if numel(roundtripResult) ~= 1
    error('simtest:StandalonePipelineResultRoundTripAmbiguous', ...
        'Expected one round-trip ResultSet, found %d.', ...
        numel(roundtripResult));
end
st_apply_result_coverage_filters(roundtripResult, finalCVF, cfg, ...
    'RequireCoverage', true, ...
    'CoveragePath', item.StandaloneCUTPath, ...
    'RequireExactSet', true, ...
    'ReadOnly', true);
st_log(cfg, 'DEBUG', ...
    'STEP5 result import/readback complete | CUT=%s', item.CUTName);

coverageObjects = st_flatten_coverage_results( ...
    getCoverageResults(roundtripResult));
if isempty(coverageObjects)
    error('simtest:StandalonePipelineCoverageMissing', ...
        'Round-trip result contains no coverage objects.');
end
cvtPath = fullfile(targetDirectory, ...
    [st_export_safe_name(item.CUTName) '_CoverageResult.cvt']);
delete_if_present(cvtPath);
st_log(cfg, 'DEBUG', 'STEP5 cvsave start | CUT=%s', item.CUTName);
save_cvt(cvtPath, coverageObjects);
st_log(cfg, 'DEBUG', 'STEP5 cvsave complete | CUT=%s', item.CUTName);
item.CoverageResult = cvtPath;
item.CoverageResultSHA256 = st_file_signature(cvtPath).SHA256;

reportDirectory = fullfile(targetDirectory, ...
    [st_export_safe_name(item.CUTName) '_TestReport']);
if isfolder(reportDirectory), rmdir(reportDirectory, 's'); end
mkdir(reportDirectory);
zipPath = fullfile(roundtripDirectory, 'TestReport.zip');
delete_if_present(zipPath);
st_log(cfg, 'DEBUG', ...
    'STEP5 Test Manager ZIP report start | CUT=%s', item.CUTName);
sltest.testmanager.report(roundtripResult, zipPath, ...
    'Title', [item.CUTName ' Test Report'], ...
    'IncludeMLVersion', true, ...
    'IncludeTestResults', int32(0), ...
    'IncludeCoverageResult', strcmpi(reportMode, 'FULL'), ...
    'IncludeSimulationMetadata', true, ...
    'LaunchReport', false);
unzip(zipPath, reportDirectory);
ensure_report_html(reportDirectory);
st_log(cfg, 'DEBUG', ...
    'STEP5 Test Manager ZIP report complete | CUT=%s', item.CUTName);
coverageDirectory = fullfile(reportDirectory, 'coverage');
if ~isfolder(coverageDirectory), mkdir(coverageDirectory); end
st_log(cfg, 'DEBUG', ...
    'STEP5 cvhtml start | CUT=%s | Objects=%d', ...
    item.CUTName, numel(coverageObjects));
for i = 1:numel(coverageObjects)
    path = fullfile(coverageDirectory, sprintf('%02d_coverage.html', i));
    cvhtml(path, coverageObjects{i}, '-sRT=0');
end
st_log(cfg, 'DEBUG', 'STEP5 cvhtml complete | CUT=%s', item.CUTName);
item.TestReport = reportDirectory;

targetTable = table(item.No, string(item.CUTName), ...
    string(item.CUTPath), string(item.TestCaseName), ...
    string(item.StandaloneCUTPath), ...
    'VariableNames', {'No','CUTName','CUTPath','TestCaseName', ...
    'StandaloneCUTPath'});
metrics = st_collect_coverage_summary( ...
    roundtripResult, targetTable, 'FILTERED_FINAL', ...
    'IncludeTestDetails', false, 'MatchCoverageObjects', true);
metricSnapshot = fullfile(roundtripDirectory, 'coverage-metrics.mat');
save(metricSnapshot, 'metrics');
item.MetricSnapshot = metricSnapshot;
item.MetricSnapshotSHA256 = st_file_signature(metricSnapshot).SHA256;
item = assign_metric(item, metrics, 'Decision');
item = assign_metric(item, metrics, 'Execution');
end

function cleanup = register_target_folder(folder)
cleanup = [];
entries = string(strsplit(path, pathsep));
for i = 1:numel(entries)
    if strlength(entries(i)) > 0 && same_path(entries(i), folder)
        return;
    end
end
addpath(folder, '-begin');
cleanup = onCleanup(@() remove_path_quietly(folder));
end

function remove_path_quietly(folder)
try, rmpath(folder); catch, end
end

function rawResult = selected_result_file(item)
listing = dir(fullfile(item.SelectedResultDirectory, 'raw', ...
    '*Results.mldatx'));
if numel(listing) ~= 1
    error('simtest:StandalonePipelineSelectedResultMissing', ...
        'Expected one selected result under %s.', ...
        item.SelectedResultDirectory);
end
rawResult = fullfile(listing(1).folder, listing(1).name);
end

function item = assign_metric(item, metrics, metricName)
rows = metrics.Level == "CUT" & ...
    strcmpi(metrics.Metric, metricName) & metrics.Status == "OK";
prefix = metricName;
if ~any(rows)
    item.([prefix 'Covered']) = NaN;
    item.([prefix 'Total']) = NaN;
    item.([prefix 'Percentage']) = NaN;
    item.([prefix 'PercentageText']) = 'N/A';
    return;
end
row = metrics(find(rows, 1),:);
item.([prefix 'Covered']) = double(row.Covered);
item.([prefix 'Total']) = double(row.Total);
[percentage, percentageText] = st_coverage_percentage( ...
    row.Covered, row.Total);
item.([prefix 'Percentage']) = percentage;
item.([prefix 'PercentageText']) = char(percentageText);
end

function save_cvt(path, objects)
[folder, name] = fileparts(path);
base = fullfile(folder, name);
arguments = [{base}; objects(:)];
cvsave(arguments{:});
if ~isfile(path)
    error('simtest:StandalonePipelineCVTSaveMissing', ...
        'cvsave did not create the expected file: %s', path);
end
end

function ensure_report_html(reportDirectory)
rootReport = fullfile(reportDirectory, 'report.html');
if isfile(rootReport), return; end
matches = dir(fullfile(reportDirectory, '**', 'report.html'));
if isempty(matches)
    error('simtest:StandalonePipelineHTMLReportMissing', ...
        'The official Test Manager ZIP contains no report.html.');
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
        'Cannot place report.html at the Test Report root.');
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

function tf = same_path(left, right)
left = char(java.io.File(char(left)).getCanonicalPath());
right = char(java.io.File(char(right)).getCanonicalPath());
if ispc, tf = strcmpi(left, right); else, tf = strcmp(left, right); end
end

function require_step(manifest, name)
if ~isfield(manifest, 'Steps') || ~isfield(manifest.Steps, name) || ...
        ~ismember(upper(string(manifest.Steps.(name).Status)), ["OK","WARN"])
    error('simtest:StandalonePipelineStageNotReady', ...
        '%s must complete before STEP5.', name);
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

function value = step_state(status, message)
value = struct('Status', status, 'Message', message, ...
    'UpdatedAt', timestamp_text());
end

function status = pipeline_status(manifest)
names = fieldnames(manifest.Steps);
values = strings(numel(names),1);
for i = 1:numel(names)
    values(i) = string(manifest.Steps.(names{i}).Status);
end
if any(values == "FAIL")
    status = 'FAIL';
elseif any(values == "WARN") || any(values == "NOT_RUN")
    status = 'WARN';
else
    status = 'OK';
end
end

function value = timestamp_text()
value = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end
