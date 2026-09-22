function info = st_collect_per_cut_results(varargin)
%ST_COLLECT_PER_CUT_RESULTS Build the artifacts of a deferred PER_CUT run.
%
% st_collect_per_cut_results
% st_collect_per_cut_results('RunId', 'LATEST')
% st_collect_per_cut_results('RunId', runId, 'ReportMode', 'FULL')
%
% PER_CUT runs a Test Case alone because some Test Cases only work alone.
% The coverage filter is not part of that: it shapes the coverage data of
% the artifacts built afterwards. So the run saves each ResultSet and stops,
% and this command generates the CVF, attaches it to the saved coverage
% data, and writes the per-CUT reports.
%
% A run that already built its artifacts inline (the standalone bundle) has
% nothing to collect and is reported as such.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'RunId', 'LATEST', @(x) ischar(x) || isstring(x));
addParameter(p, 'ReportMode', '', ...
    @(x) isempty(x) || ismember(upper(string(x)), ["SUMMARY","FULL"]));
parse(p, varargin{:});

cfg = st_require_runtime_target();
[runId, runDirectory, manifest] = resolve_run(cfg, p.Results.RunId);
reportMode = upper(strtrim(char(string(p.Results.ReportMode))));
if isempty(reportMode)
    reportMode = upper(char(string(manifest.ReportMode)));
end

targets = struct2table(manifest.Targets, 'AsArray', true);
config = st_load_targets(cfg.OnlyEnabled);

st_log(cfg, 'INFO', ...
    'PER_CUT collect start | RunId=%s | Targets=%d | ReportMode=%s', ...
    runId, height(targets), reportMode);

fprintf('\n============================================\n');
fprintf('Collect PER_CUT Results\n');
fprintf('Run       : %s\n', runId);
fprintf('Directory : %s\n', runDirectory);
fprintf('============================================\n');

% The standalone pipeline refuses to run while the Top Model is loaded, so
% leave the session as this command found it: close what this command
% opened, and clear the Dirty flag Simulink Coverage raises on models that
% were already loaded and clean. A handle container, because onCleanup
% captures its arguments by value and the lists only fill as the loop runs.
openedModels = containers.Map();
openedModels('names') = strings(0,1);
openedModels('clean') = strings(0,1);
modelCleanup = onCleanup(@() close_opened_models(openedModels, cfg)); %#ok<NASGU>
Collected = strings(height(targets),1);
Message = strings(height(targets),1);
totalTimer = tic;

for i = 1:height(targets)
    testCaseName = string(targets.TestCaseName(i));
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
    [opened, clean] = load_models_for_coverage(row, cfg, openedModels);
    openedModels('names') = [openedModels('names'); opened];
    openedModels('clean') = [openedModels('clean'); clean];
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
        'CoveragePath', st_coverage_object_path(row), ...
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


function [opened, clean] = load_models_for_coverage(row, cfg, openedModels)
%LOAD_MODELS_FOR_COVERAGE Open what the saved coverage data points at.
%
% A model that is already loaded is left alone, but its Dirty state is
% remembered so the cleanup can tell a flag this command raised from a
% change the operator has not saved yet.
opened = strings(0,1);
clean = strings(0,1);
if bdIsLoaded(cfg.TopModel)
    clean = [clean; clean_if_untracked(cfg.TopModel, openedModels)];
else
    load_system(cfg.ModelFile);
    opened(end+1,1) = string(cfg.TopModel);
end
harness = char(string(row.HarnessName));
if isempty(harness)
    return;
end
if bdIsLoaded(harness)
    clean = [clean; clean_if_untracked(harness, openedModels)];
    return;
end
owner = st_normalize_cut_path(row.CUTPath, cfg.TopModel);
sltest.harness.load(owner, harness);
opened(end+1,1) = string(harness);
end


function clean = clean_if_untracked(model, openedModels)
%CLEAN_IF_UNTRACKED Name the model if it is clean and not yet on either list.
clean = strings(0,1);
tracked = [openedModels('names'); openedModels('clean')];
if any(tracked == string(model))
    return;
end
if strcmp(get_param(model, 'Dirty'), 'off')
    clean = string(model);
end
end


function close_opened_models(openedModels, cfg)
%CLOSE_OPENED_MODELS Leave the session as this command found it.
%
% Harnesses close before their owner, and always without saving: collecting
% results must never write a model back. Attaching a coverage filter and
% reading coverage marks the models it touches as Dirty without changing
% what is saved. A model that was loaded and clean when this command
% started gets that flag cleared again, so the exporters that refuse
% unsaved models (test specification, final document, standalone pipeline)
% do not stop on a change nobody made. A model that was already Dirty is
% left as it was: that change belongs to the operator.
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
clean = openedModels('clean');
for i = 1:numel(clean)
    name = char(clean(i));
    try
        if bdIsLoaded(name) && strcmp(get_param(name, 'Dirty'), 'on')
            set_param(name, 'Dirty', 'off');
            st_log(cfg, 'INFO', ...
                ['Cleared the Dirty flag raised while collecting | ' ...
                 'Model=%s | nothing was saved'], name);
        end
    catch ME
        st_log(cfg, 'WARN', ...
            'Could not clear the Dirty flag of %s | %s', name, ME.message);
    end
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
