function info = st_collect_per_cut_results(varargin)
%ST_COLLECT_PER_CUT_RESULTS Build the artifacts of a deferred PER_CUT run.
%
% st_collect_per_cut_results
% st_collect_per_cut_results('RunId', 'LATEST')
% st_collect_per_cut_results('RunId', runId, 'ReportMode', 'FULL')
% st_collect_per_cut_results('OnlyPassed', true)
%
% PER_CUT runs a Test Case alone because some Test Cases only work alone.
% The coverage filter is not part of that: it shapes the coverage data of
% the artifacts built afterwards. So the run saves each ResultSet and stops,
% and this command generates the CVF, attaches it to the saved coverage
% data, and writes the per-CUT reports.
%
% A run that already built its artifacts inline (the standalone bundle) has
% nothing to collect and is reported as such.
%
% OnlyPassed skips every target whose FinalOutcome is not PASSED. A CUT that
% failed is going to be fixed and run again, and the artifacts of the failed
% run would only be replaced, so building them is wasted time. The default
% collects everything, because a failure report is evidence in its own
% right when nobody intends to rerun.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'RunId', 'LATEST', @(x) ischar(x) || isstring(x));
addParameter(p, 'ReportMode', '', ...
    @(x) isempty(x) || ismember(upper(string(x)), ["SUMMARY","FULL"]));
addParameter(p, 'OnlyPassed', false, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
onlyPassed = logical(p.Results.OnlyPassed);

cfg = st_require_runtime_target();
[runId, runDirectory, manifest] = resolve_run(cfg, p.Results.RunId);
reportMode = upper(strtrim(char(string(p.Results.ReportMode))));
if isempty(reportMode)
    reportMode = upper(char(string(manifest.ReportMode)));
end

targets = struct2table(manifest.Targets, 'AsArray', true);
config = st_load_targets(cfg.OnlyEnabled);

st_log(cfg, 'INFO', ...
    ['PER_CUT collect start | RunId=%s | Targets=%d | ReportMode=%s | ' ...
     'OnlyPassed=%s'], ...
    runId, height(targets), reportMode, string(onlyPassed));

fprintf('\n============================================\n');
fprintf('Collect PER_CUT Results\n');
fprintf('Run       : %s\n', runId);
fprintf('Directory : %s\n', runDirectory);
if onlyPassed
    fprintf('Scope     : targets with FinalOutcome=PASSED\n');
end
fprintf('============================================\n');

% The standalone pipeline refuses to run while the Top Model is loaded, so
% leave the session as this command found it.
% A handle container, because onCleanup captures its arguments by value and
% the list only fills as the loop runs.
openedModels = containers.Map();
openedModels('names') = strings(0,1);
modelCleanup = onCleanup(@() close_opened_models(openedModels, cfg)); %#ok<NASGU>
Collected = strings(height(targets),1);
Message = strings(height(targets),1);
totalTimer = tic;

for i = 1:height(targets)
    testCaseName = string(targets.TestCaseName(i));
    % Decided from the manifest alone, before the workbook lookup: a target
    % that produces nothing does not need its workbook row.
    outcome = target_outcome(targets, i);
    if onlyPassed && outcome ~= "PASSED"
        Collected(i) = "SKIP";
        Message(i) = "FinalOutcome=" + outcome + ...
            "; not collected because OnlyPassed=true";
        fprintf('[%d/%d] %s | SKIP (FinalOutcome=%s)\n', ...
            i, height(targets), testCaseName, outcome);
        continue;
    end
    row = config(string(config.TestCaseName) == testCaseName, :);
    if height(row) ~= 1
        error('simtest:CollectTargetMissing', ...
            ['Test Case %s is not in the current workbook. Collect the ' ...
             'run against the workbook it was produced from.'], ...
            testCaseName);
    end
    targetDirectory = st_per_cut_target_directory(runDirectory, row);
    initialSaved = fullfile(targetDirectory, 'initial', 'Results.mldatx');
    if ~isfile(initialSaved)
        Collected(i) = "SKIP";
        Message(i) = "No saved ResultSet; this run built its artifacts inline";
        continue;
    end

    fprintf('[%d/%d] %s\n', i, height(targets), testCaseName);
    % A ResultSet read back from a file carries block paths, not handles.
    % Simulink Coverage rebuilds that map on first access, and with the
    % models unloaded the walk does not finish in any useful time.
    openedModels('names') = [openedModels('names'); ...
        load_models_for_coverage(row, cfg)];
    filterPath = "";
    ruleCount = 0;
    if st_coverage_filter_active(row)
        [filterPath, ruleCount] = generate_filter(row, ...
            fullfile(targetDirectory, 'filter'), cfg);
    end

    collect_one(initialSaved, row, fullfile(targetDirectory, 'initial'), ...
        'INITIAL', filterPath, reportMode, cfg);
    finalSaved = fullfile(targetDirectory, 'final', 'Results.mldatx');
    if isfile(finalSaved)
        collect_one(finalSaved, row, fullfile(targetDirectory, 'final'), ...
            'FINAL', filterPath, reportMode, cfg);
    end
    update_target_manifest(targets.TargetManifest(i), ...
        filterPath, ruleCount);
    Collected(i) = "OK";
    Message(i) = "Reports built from the saved ResultSet";
end

result = table(targets.No, string(targets.TestCaseName), ...
    Collected, Message, 'VariableNames', ...
    {'No','TestCaseName','Collected','Message'});
st_write_result('PerCutCollectResult', result);

info = struct( ...
    'RunId', runId, ...
    'RunDirectory', runDirectory, ...
    'ReportMode', reportMode, ...
    'OnlyPassed', onlyPassed, ...
    'Result', result, ...
    'CollectedCount', sum(Collected == "OK"), ...
    'SkippedCount', sum(Collected == "SKIP"));

fprintf('\nCollected : %d\n', info.CollectedCount);
fprintf('Skipped   : %d\n', info.SkippedCount);
fprintf('============================================\n');
st_log(cfg, 'INFO', ...
    'PER_CUT collect complete | RunId=%s | OK=%d | SKIP=%d | elapsed=%.3f sec', ...
    runId, info.CollectedCount, info.SkippedCount, toc(totalTimer));
end


function collect_one( ...
        savedFile, row, folder, label, filterPath, reportMode, cfg)
%COLLECT_ONE Attach the CVF to one saved ResultSet and report on it.
imported = sltest.testmanager.importResults(savedFile);
if isempty(imported)
    error('simtest:CollectResultEmpty', ...
        'Saved ResultSet imported no results: %s', savedFile);
end
resultObj = imported(1);

if strlength(filterPath) > 0
    attachInfo = st_apply_result_coverage_filters( ...
        resultObj, char(filterPath), cfg, ...
        'RequireCoverage', true, ...
        'CoveragePath', coverage_path(row), ...
        'RequireExactSet', true);
    if ~strcmp(attachInfo.Status, 'OK')
        error('simtest:CollectResultFilterFailed', ...
            'CVF registration failed for %s: %s', ...
            char(string(row.TestCaseName)), char(string(attachInfo.Message)));
    end
end

reportInfo = st_export_result_set_report( ...
    resultObj, row, folder, ...
    [char(string(row.TestCaseName)) ' ' lower(label)], ...
    'CoverageReportMode', reportMode, ...
    'IncludeOfficialReport', strcmp(reportMode, 'FULL'), ...
    'IncludePortableCoverageDetail', true, ...
    'LogConfig', cfg, ...
    'ResultLabel', label);
if ~strcmp(reportInfo.Status, 'OK')
    error('simtest:CollectReportIncomplete', ...
        '%s report is incomplete: %s', label, reportInfo.Summary);
end
end


function outcome = target_outcome(targets, i)
%TARGET_OUTCOME The Test Manager verdict the run recorded for one target.
outcome = "UNKNOWN";
if ~ismember('FinalOutcome', targets.Properties.VariableNames)
    return;
end
value = upper(strtrim(string(targets.FinalOutcome(i))));
if strlength(value) > 0
    outcome = value;
end
end


function opened = load_models_for_coverage(row, cfg)
%LOAD_MODELS_FOR_COVERAGE Open what the saved coverage data points at.
opened = strings(0,1);
if ~bdIsLoaded(cfg.TopModel)
    load_system(cfg.ModelFile);
    opened(end+1,1) = string(cfg.TopModel);
end
harness = char(string(row.HarnessName));
if isempty(harness) || bdIsLoaded(harness)
    return;
end
owner = st_normalize_cut_path(row.CUTPath, cfg.TopModel);
sltest.harness.load(owner, harness);
opened(end+1,1) = string(harness);
end


function close_opened_models(openedModels, cfg)
%CLOSE_OPENED_MODELS Leave the session as this command found it.
%
% Harnesses close before their owner, and always without saving: collecting
% results must never write a model back.
names = openedModels('names');
for i = numel(names):-1:1
    name = char(names(i));
    try
        if bdIsLoaded(name)
            close_system(name, 0);
        end
    catch ME
        st_log(cfg, 'WARN', 'Could not close %s | %s', name, ME.message);
    end
end
end


function path = coverage_path(row)
%COVERAGE_PATH A standalone bundle renames the CUT; follow it when present.
path = '';
if ismember('StandaloneCUTPath', row.Properties.VariableNames)
    path = strtrim(char(string(row.StandaloneCUTPath)));
end
if isempty(path)
    path = char(string(row.CUTPath));
end
end


function [filterPath, ruleCount] = generate_filter(row, filterDirectory, cfg)
if ~isfolder(filterDirectory)
    mkdir(filterDirectory);
end
filterPath = string(st_per_cut_coverage_filter_file(filterDirectory, row));
generated = st_generate_coverage_filter_file( ...
    row, char(filterPath), cfg, 'ValidateSavedFilter', false);
if ~strcmp(string(generated.Status), "OK") || ~isfile(filterPath)
    error('simtest:CollectCoverageFilterFailed', ...
        'CVF was not generated for %s: %s', ...
        char(string(row.TestCaseName)), char(string(generated.Message)));
end
ruleCount = double(generated.RuleCount);
end


function update_target_manifest(manifestPath, filterPath, ruleCount)
%UPDATE_TARGET_MANIFEST Record the CVF the collect step produced.
%
% Apply and restore describe filtering a model during a run. A deferred run
% never filters the model, so those two stay NOT_REQUIRED rather than
% claiming a lifecycle that did not happen.
manifestPath = char(string(manifestPath));
if ~isfile(manifestPath)
    return;
end
manifest = jsondecode(fileread(manifestPath));
manifest.CoverageFilterFile = char(filterPath);
manifest.CoverageFilterRuleCount = ruleCount;
manifest.CoverageFilterSHA256 = '';
if strlength(filterPath) > 0
    manifest.CoverageFilterSHA256 = ...
        st_file_signature(char(filterPath)).SHA256;
    manifest.FilterGenerationStatus = 'OK';
    manifest.ResultFilterStatus = 'OK';
    manifest.ResultFilterAttachCount = 1;
end
manifest.FilterApplyStatus = 'NOT_REQUIRED';
manifest.FilterRestoreStatus = 'NOT_REQUIRED';
manifest.CollectedAt = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss'));
st_write_json_atomic(manifestPath, manifest);
end


function [runId, runDirectory, manifest] = resolve_run(cfg, requested)
requested = char(string(requested));
if strcmpi(requested, 'LATEST')
    if ~isfile(cfg.PerCutLatestPointer)
        error('simtest:CollectRunMissing', ...
            ['No PER_CUT run to collect. Run the tests first; the ' ...
             'pointer is written to %s.'], cfg.PerCutLatestPointer);
    end
    latest = jsondecode(fileread(cfg.PerCutLatestPointer));
    manifestPath = char(string(latest.Manifest));
else
    manifestPath = fullfile(cfg.PerCutRunRootDir, requested, 'manifest.json');
end
if ~isfile(manifestPath)
    error('simtest:CollectRunMissing', ...
        'PER_CUT run manifest is missing: %s', manifestPath);
end
manifest = jsondecode(fileread(manifestPath));
runId = char(string(manifest.RunId));
runDirectory = char(string(manifest.RunDirectory));
if ~isfolder(runDirectory)
    error('simtest:CollectRunMissing', ...
        'PER_CUT run directory is missing: %s', runDirectory);
end
end
