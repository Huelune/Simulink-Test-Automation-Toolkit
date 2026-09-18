function reportInfo = st_generate_test_report(varargin)
%ST_GENERATE_TEST_REPORT Create one local bundle for a complete test run.
%
% st_generate_test_report
% st_generate_test_report('RunRecord', 'LATEST')
% st_generate_test_report('RunRecord', recordId)
% st_generate_test_report(runContext, workflowResult, workflowPlan)
%
% The RunRecord form rebuilds the report from a saved run, so collecting
% results is a step of its own rather than something only the session that
% ran the tests can do. The three-argument form is the live path used by
% the workflow itself.

cfg = st_require_runtime_target();
[runContext, workflowResult, workflowPlan] = resolve_inputs(cfg, varargin{:});
% Every step below reads a ResultSet that may have come from a file, which is
% much slower than the live objects this used to run on. Announce each step so
% a slow one is distinguishable from a hang.
step = @(text) st_log(cfg, 'INFO', 'Report step | %s', text);
step('Loading targets');
targetConfig = st_load_targets(cfg.OnlyEnabled);
runInfo = st_report_run_context(runContext);

[runId, runDirectory] = create_run_directory(cfg.TestRunRootDir);
officialDirectory = fullfile(runDirectory, 'official');
coverageDirectory = fullfile(runDirectory, 'coverage');
rawDirectory = fullfile(runDirectory, 'raw');
mkdir(officialDirectory);
mkdir(coverageDirectory);
mkdir(rawDirectory);

artifacts = empty_artifact_table();
targets = empty_target_table();
iterations = empty_iteration_table();
coverage = empty_coverage_table();
step('Loading the models the coverage data refers to');
artifacts = load_models_for_coverage(artifacts, targetConfig, cfg);

step('Generating and attaching coverage filters');
[coverageFilters, artifacts] = resolve_coverage_filters( ...
    artifacts, runContext, targetConfig, cfg);

step('Collecting the test result hierarchy');
try
    [initialTargets, initialIterations] = ...
        st_collect_test_result_summary( ...
            runContext.InitialResult, targetConfig, 'INITIAL');
    [finalTargets, finalIterations] = ...
        st_collect_test_result_summary( ...
            runContext.FinalResult, targetConfig, 'FINAL');
    targets = [initialTargets; finalTargets];
    iterations = [initialIterations; finalIterations];
    artifacts = record_artifact(artifacts, 'SUMMARY_DATA', '', ...
        'OK', 'Test result hierarchy collected');
catch ME
    artifacts = record_artifact(artifacts, 'SUMMARY_DATA', '', ...
        'FAIL', ME.message);
end

step('Collecting coverage');
try
    % Two passes over every target, each one calling into the Simulink
    % Coverage API. With a large workbook this is minutes, not seconds, so
    % report progress instead of going silent.
    initialCoverage = st_collect_coverage_summary( ...
        runContext.InitialResult, targetConfig, 'INITIAL', ...
        'ProgressFcn', coverage_progress(cfg, 'INITIAL'));
    finalCoverage = st_collect_coverage_summary( ...
        runContext.FinalResult, targetConfig, 'FINAL', ...
        'ProgressFcn', coverage_progress(cfg, 'FINAL'));
    coverage = [initialCoverage; finalCoverage];
    extractionFailures = sum(coverage.Status == "EXTRACTION_FAILED");
    if extractionFailures > 0
        artifacts = record_artifact(artifacts, 'COVERAGE_DATA', '', ...
            'FAIL', sprintf('%d coverage extraction row(s) failed', ...
                extractionFailures));
    else
        artifacts = record_artifact(artifacts, 'COVERAGE_DATA', '', ...
            'OK', 'Decision and Execution coverage collected');
    end
catch ME
    artifacts = record_artifact(artifacts, 'COVERAGE_DATA', '', ...
        'FAIL', ME.message);
end

step('Exporting the raw ResultSets');
initialRaw = fullfile(rawDirectory, 'InitialResults.mldatx');
artifacts = export_result_artifact(artifacts, ...
    runContext.InitialResult, initialRaw);
finalRaw = fullfile(rawDirectory, 'FinalResults.mldatx');
artifacts = export_result_artifact(artifacts, ...
    runContext.FinalResult, finalRaw);

step('Writing the official PDF reports');
initialPdf = fullfile(officialDirectory, 'InitialTestResults.pdf');
artifacts = official_report_artifact(artifacts, ...
    runContext.InitialResult, initialPdf, 'Initial Test Results');
finalPdf = fullfile(officialDirectory, 'FinalTestResults.pdf');
artifacts = official_report_artifact(artifacts, ...
    runContext.FinalResult, finalPdf, 'Final Test Results');

step('Rendering the coverage HTML');
artifacts = coverage_html_artifacts(artifacts, ...
    runContext.FinalResult, coverageDirectory);

step('Writing the summary workbook');
summaryPath = fullfile(runDirectory, 'TestSummary.xlsx');
try
    write_summary_workbook(summaryPath, targets, iterations, coverage, ...
        coverageFilters, runContext.ExpectedUpdateResult, ...
        workflowResult, workflowPlan, ...
        cfg, runId, runDirectory, artifacts);
    artifacts = record_artifact(artifacts, 'EXCEL', summaryPath, ...
        'OK', 'Integrated workbook created');
catch ME
    artifacts = record_artifact(artifacts, 'EXCEL', summaryPath, ...
        'FAIL', ME.message);
end

if isfile(summaryPath)
    latestDir = fileparts(cfg.LatestSummaryFile);
    if ~isfolder(latestDir)
        mkdir(latestDir);
    end
    [ok, message] = copyfile(summaryPath, cfg.LatestSummaryFile, 'f');
    if ok
        artifacts = record_artifact(artifacts, 'LATEST_EXCEL', ...
            cfg.LatestSummaryFile, 'OK', 'Latest summary updated');
    else
        artifacts = record_artifact(artifacts, 'LATEST_EXCEL', ...
            cfg.LatestSummaryFile, 'FAIL', message);
    end
end

manifestPath = fullfile(runDirectory, 'manifest.json');
manifest = build_manifest( ...
    runId, runDirectory, runInfo, cfg, artifacts);
write_json_atomic(manifestPath, manifest);

latest = struct( ...
    'Version', 1, ...
    'RunId', runId, ...
    'RunDirectory', runDirectory, ...
    'Manifest', manifestPath, ...
    'Summary', summaryPath, ...
    'Status', manifest.Status, ...
    'UpdatedAt', timestamp_text());
write_json_atomic(cfg.LatestReportPointer, latest);

reportInfo = struct( ...
    'RunId', runId, ...
    'RunDirectory', runDirectory, ...
    'Manifest', manifestPath, ...
    'Summary', summaryPath, ...
    'Status', manifest.Status, ...
    'ArtifactCount', height(artifacts), ...
    'FailedArtifactCount', sum(artifacts.Status == "FAIL"));

if reportInfo.FailedArtifactCount > 0
    warning('simtest:PartialTestReport', ...
        ['Integrated report completed with %d failed artifact(s). ' ...
         'See %s.'], reportInfo.FailedArtifactCount, manifestPath);
end
end

function [runContext, workflowResult, workflowPlan] = ...
    resolve_inputs(cfg, varargin)
if isempty(varargin)
    % The public form: collect the results of the last finished run.
    varargin = {'RunRecord', 'LATEST'};
end
if numel(varargin) == 2 && (ischar(varargin{1}) || isstring(varargin{1})) && ...
        strcmpi(char(string(varargin{1})), 'RunRecord')
    [runContext, workflowResult, workflowPlan] = ...
        st_load_run_record(varargin{2}, cfg);
    return;
end
if numel(varargin) ~= 3
    error('simtest:InvalidReportInputs', ...
        ['Call st_generate_test_report(''RunRecord'', id) or ' ...
         'st_generate_test_report(runContext, workflowResult, plan).']);
end
[runContext, workflowResult, workflowPlan] = varargin{:};
end

function artifacts = export_result_artifact(artifacts, resultObj, path)
try
    sltest.testmanager.exportResults(resultObj, path);
    artifacts = record_artifact(artifacts, 'MLDATX', path, ...
        'OK', 'ResultSet exported');
catch ME
    artifacts = record_artifact(artifacts, 'MLDATX', path, ...
        'FAIL', ME.message);
end
end

function artifacts = official_report_artifact( ...
        artifacts, resultObj, path, titleText)
try
    sltest.testmanager.report(resultObj, path, ...
        'Title', titleText, ...
        'IncludeMLVersion', true, ...
        'IncludeTestResults', int32(0), ...
        'IncludeCoverageResult', true, ...
        'IncludeSimulationMetadata', true, ...
        'LaunchReport', false);
    artifacts = record_artifact(artifacts, 'PDF', path, ...
        'OK', 'Official Test Manager report created');
catch ME
    artifacts = record_artifact(artifacts, 'PDF', path, ...
        'FAIL', ME.message);
end
end

function artifacts = coverage_html_artifacts(artifacts, resultObj, folder)
try
    coverageObjects = getCoverageResults(resultObj);
catch ME
    artifacts = record_artifact(artifacts, 'HTML', folder, ...
        'FAIL', ME.message);
    return;
end
if isempty(coverageObjects)
    artifacts = record_artifact(artifacts, 'HTML', folder, ...
        'SKIP', 'No final coverage objects were returned');
    return;
end

for i = 1:numel(coverageObjects)
    root = coverage_root(coverageObjects(i));
    fileName = sprintf('%02d_%s.html', i, safe_file_name(root));
    path = fullfile(folder, fileName);
    try
        report = cvhtml(path, coverageObjects(i), '-sRT=0');
        if isstruct(report) && isfield(report, 'fileName') && ...
                isfield(report, 'path')
            path = fullfile(char(report(1).path), char(report(1).fileName));
        end
        artifacts = record_artifact(artifacts, 'HTML', path, ...
            'OK', ['Coverage root: ' root]);
    catch ME
        artifacts = record_artifact(artifacts, 'HTML', path, ...
            'FAIL', ME.message);
    end
end
end

function write_summary_workbook(path, targets, iterations, coverage, ...
        coverageFilters, expectedUpdates, workflowResult, workflowPlan, ...
        cfg, runId, runDirectory, artifacts)
if isfile(path)
    delete(path);
end

overview = { ...
    'Metric','Value'; ...
    'Run ID',runId; ...
    'Created At',timestamp_text(); ...
    'Initial Target Results',sum(targets.Run == "INITIAL"); ...
    'Final Target Results',sum(targets.Run == "FINAL"); ...
    'Final Passed',sum(targets.Run == "FINAL" & ...
        upper(targets.Outcome) == "PASSED"); ...
    'Final Failed',sum(targets.Run == "FINAL" & ...
        upper(targets.Outcome) == "FAILED"); ...
    'Coverage Metrics',height(coverage); ...
    'Coverage Filter Targets',height(coverageFilters); ...
    'Coverage Filter Warnings',sum(coverageFilters.Status == "WARN"); ...
    'Coverage Threshold Enforcement','REPORT_ONLY'; ...
    'Artifact Failures',sum(artifacts.Status == "FAIL")};
writecell(overview, path, 'Sheet', 'Overview');
writetable(targets, path, 'Sheet', 'Targets');
writetable(iterations, path, 'Sheet', 'Iterations');
writetable(coverage, path, 'Sheet', 'Coverage');
writetable(coverageFilters, path, 'Sheet', 'CoverageFilters');

if isempty(expectedUpdates) || width(expectedUpdates) == 0
    expectedUpdates = table("NONE", "No expected-value update rows", ...
        'VariableNames', {'Status','Message'});
end
writetable(expectedUpdates, path, 'Sheet', 'ExpectedUpdates');
writetable(workflowResult, path, 'Sheet', 'Workflow');

Key = ["RunId"; "RunDirectory"; "TopModel"; "ModelFile"; ...
    "TestFile"; "MATLABRelease"; "MATLABVersion"; ...
    "CoverageStructuralLevel"; "CoverageMetricSettings"; ...
    "CoverageIncludeReferencedModels"; ...
    "CoverageFilterApplicationMode"; "CoverageFilterDirectory"; ...
    "WorkflowPlanRows"];
Value = [string(runId); string(runDirectory); string(cfg.TopModel); ...
    string(cfg.ModelFile); string(cfg.TestFile); string(version('-release')); ...
    string(version()); string(cfg.CoverageStructuralLevel); ...
    string(cfg.CoverageMetricSettings); ...
    string(logical(cfg.CoverageIncludeReferencedModels)); ...
    "RUNTIME"; ...
    string(cfg.CoverageFilterDir); ...
    string(height(workflowPlan))];
metadata = table(Key, Value);
writetable(metadata, path, 'Sheet', 'Metadata');
end

function manifest = build_manifest( ...
        runId, runDirectory, runInfo, cfg, artifacts)
status = char(st_report_status(artifacts.Status));
manifest = struct( ...
    'Version', 1, ...
    'RunId', runId, ...
    'Status', status, ...
    'RunDirectory', runDirectory, ...
    'StartedAt', runInfo.StartedAt, ...
    'CompletedAt', runInfo.CompletedAt, ...
    'ReportCreatedAt', timestamp_text(), ...
    'RerunPerformed', runInfo.RerunPerformed, ...
    'CoverageStructuralLevel', cfg.CoverageStructuralLevel, ...
    'CoverageMetricSettings', cfg.CoverageMetricSettings, ...
    'CoverageFilterApplicationMode', 'RUNTIME', ...
    'CoverageThresholdPolicy', 'REPORT_ONLY', ...
    'Artifacts', table2struct(artifacts));
end

function fcn = coverage_progress(cfg, label)
%COVERAGE_PROGRESS Throttled progress for the two coverage passes.
fcn = @(phase, current, total) log_progress(cfg, label, phase, current, total);
end


function log_progress(cfg, label, phase, current, total)
if total <= 0, return; end
interval = max(1, ceil(total / 20));
if current ~= 1 && current ~= total && mod(current, interval) ~= 0
    return;
end
st_log(cfg, 'INFO', 'Report step | Coverage %s | %s | %d/%d', ...
    label, char(string(phase)), current, total);
end


function artifacts = load_models_for_coverage(artifacts, targetConfig, cfg)
%LOAD_MODELS_FOR_COVERAGE Coverage data needs the models it points at.
%
% A ResultSet read back from a file carries block paths, not handles. On the
% first coverage read Simulink Coverage rebuilds that handle map through
% cvi.TopModelCov.updateModelHandles, and with the models unloaded the walk
% does not finish in any useful time. It used to be free because the session
% that ran the tests still had everything open. Loading them first turns the
% walk back into a lookup.

loaded = strings(0,1);
failures = strings(0,1);
try
    if ~bdIsLoaded(cfg.TopModel)
        load_system(cfg.ModelFile);
        loaded(end+1,1) = string(cfg.TopModel);
    end
catch ME
    failures(end+1,1) = string(cfg.TopModel) + ": " + string(ME.message);
end

for i = 1:height(targetConfig)
    row = targetConfig(i,:);
    harness = char(string(row.HarnessName));
    if isempty(harness) || bdIsLoaded(harness)
        continue;
    end
    try
        owner = st_normalize_cut_path(row.CUTPath, cfg.TopModel);
        sltest.harness.load(owner, harness);
        loaded(end+1,1) = string(harness); %#ok<AGROW>
    catch ME
        % A Harness that cannot be opened only costs this CUT its coverage
        % rows, so report it and keep going.
        failures(end+1,1) = string(harness) + ": " + string(ME.message); %#ok<AGROW>
    end
end

st_log(cfg, 'INFO', ...
    'Report step | Models loaded for coverage | loaded=%d | failed=%d', ...
    numel(loaded), numel(failures));
if isempty(failures)
    artifacts = record_artifact(artifacts, 'MODEL_LOAD', '', 'OK', ...
        sprintf('%d model(s) loaded for coverage access', numel(loaded)));
else
    artifacts = record_artifact(artifacts, 'MODEL_LOAD', '', 'FAIL', ...
        char(strjoin(failures, ' | ')));
end
end

function [T, artifacts] = resolve_coverage_filters( ...
        artifacts, runContext, targetConfig, cfg)
%RESOLVE_COVERAGE_FILTERS Generate the CVFs and register them on the results.
%
% The run collects coverage unfiltered: a filter shapes the coverage data of
% the artifacts, not the execution. So the CVFs are generated here and
% attached to the ResultSets this report is built from.
T = coverage_filter_report_table(runContext);
if width(T) > 2
    % A run that still filtered itself already reported its rows.
    return;
end
active = st_coverage_filter_active(targetConfig);
if ~any(active)
    return;
end
try
    st_log(cfg, 'INFO', 'Report step | Generating coverage filter files');
    T = st_prepare_coverage_filters();
    failed = T(T.Status == "FAIL", :);
    if height(failed) > 0
        error('simtest:CoverageFilterPreparationFailed', ...
            'Coverage filter preparation failed: %s', ...
            char(strjoin(failed.Message, ' | ')));
    end
    files = T.FilterFile(strlength(T.FilterFile) > 0);
    if isempty(files)
        artifacts = record_artifact(artifacts, 'COVERAGE_FILTER', '', ...
            'OK', 'No coverage filter file to attach');
        return;
    end
    % Without a rerun both labels name the same ResultSet. Attaching twice
    % would register the same filter set on it twice.
    resultSets = {runContext.InitialResult};
    if logical(runContext.RerunPerformed)
        resultSets{end+1} = runContext.FinalResult;
    end
    for k = 1:numel(resultSets)
        st_log(cfg, 'INFO', ...
            'Report step | Attaching coverage filters to ResultSet %d/%d', ...
            k, numel(resultSets));
        attachInfo = st_apply_result_coverage_filters( ...
            resultSets{k}, cellstr(files), cfg, 'RequireCoverage', true);
        if ~strcmp(attachInfo.Status, 'OK')
            error('simtest:ReportCoverageFilterFailed', '%s', ...
                attachInfo.Message);
        end
    end
    artifacts = record_artifact(artifacts, 'COVERAGE_FILTER', ...
        char(cfg.CoverageFilterDir), 'OK', ...
        sprintf('%d coverage filter file(s) attached', numel(files)));
catch ME
    artifacts = record_artifact(artifacts, 'COVERAGE_FILTER', ...
        char(cfg.CoverageFilterDir), 'FAIL', ME.message);
end
end

function T = coverage_filter_report_table(runContext)
if isfield(runContext, 'CoverageFilterResult') && ...
        istable(runContext.CoverageFilterResult) && ...
        width(runContext.CoverageFilterResult) > 0
    T = runContext.CoverageFilterResult;
    return;
end
T = table("NONE", "No coverage filter preparation rows", ...
    'VariableNames', {'Status','Message'});
end

function artifacts = record_artifact( ...
        artifacts, type, path, status, message)
artifacts(end+1,:) = {string(type), string(path), ...
    string(status), string(message)};
end

function [runId, folder] = create_run_directory(root)
if ~isfolder(root)
    mkdir(root);
end
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
uuid = char(java.util.UUID.randomUUID());
runId = [timestamp '_' uuid(1:8)];
folder = fullfile(root, runId);
mkdir(folder);
end

function write_json_atomic(path, value)
folder = fileparts(path);
if ~isfolder(folder)
    mkdir(folder);
end
temporary = [tempname(folder) '.json'];
cleanup = onCleanup(@() delete_quiet(temporary)); %#ok<NASGU>
fileId = fopen(temporary, 'w', 'n', 'UTF-8');
if fileId < 0
    error('simtest:ReportManifestWriteFailed', ...
        'Cannot create JSON file: %s', temporary);
end
fileCleanup = onCleanup(@() fclose_quiet(fileId));
fprintf(fileId, '%s\n', jsonencode(value, 'PrettyPrint', true));
clear fileCleanup;
[ok, message] = movefile(temporary, path, 'f');
if ~ok
    error('simtest:ReportManifestWriteFailed', ...
        'Cannot replace %s: %s', path, message);
end
end

function text = coverage_root(cvd)
text = 'coverage';
try
    text = char(cvd.test.rootPath);
catch
end
end

function text = safe_file_name(value)
text = regexprep(char(string(value)), '[^A-Za-z0-9_-]+', '_');
text = regexprep(text, '^_+|_+$', '');
if isempty(text)
    text = 'coverage';
end
if numel(text) > 80
    text = text(1:80);
end
end

function delete_quiet(path)
if isfile(path)
    delete(path);
end
end

function fclose_quiet(fileId)
if fileId >= 0
    fclose(fileId);
end
end

function text = timestamp_text()
text = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
end

function T = empty_artifact_table()
T = table(strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'Type','Path','Status','Message'});
end

function T = empty_target_table()
T = table(strings(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), ...
    'VariableNames', {'Run','No','CUTName','CUTPath','TestCaseName', ...
     'Outcome','DurationSec','IterationCount'});
end

function T = empty_iteration_table()
T = table(strings(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), zeros(0,1), 'VariableNames', ...
    {'Run','No','CUTName','TestCaseName','IterationName','Outcome', ...
     'DurationSec'});
end

function T = empty_coverage_table()
T = table(strings(0,1), strings(0,1), zeros(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), ...
    zeros(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), 'VariableNames', ...
    {'Run','Level','No','CUTName','TestCaseName','IterationName', ...
     'CoverageRoot','SourceCoverageRoot','Checksum','Metric','Covered', ...
     'Total','Justified','Percentage','PercentageText','Status','Message'});
end
