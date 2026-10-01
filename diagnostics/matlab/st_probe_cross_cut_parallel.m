function report = st_probe_cross_cut_parallel(varargin)
%ST_PROBE_CROSS_CUT_PARALLEL Measure what running several CUTs at once needs.
%
% report = st_probe_cross_cut_parallel()
% report = st_probe_cross_cut_parallel('Workers', 3)
% report = st_probe_cross_cut_parallel('MaxTargets', 6)
% report = st_probe_cross_cut_parallel('ModelChangeCheck', false)
% report = st_probe_cross_cut_parallel('KeepPool', true)
%
% EXPERIMENTAL: exists only on branch exp/per-cut-parallel.
%
% A redesigned PER_CUT would prepare every CUT in order, run all of their
% Test Cases together with run(tf,'Parallel',true), then update expected
% values CUT by CUT and rerun the updated ones in parallel. That design
% rests on four answers:
%
%   MODEL   After the client saves a changed model, does the next parallel
%           run use the new file, or a copy the workers still hold? A stale
%           copy would rerun with the old expected values.
%   SPLIT   Can one parallel ResultSet be saved as one MLDATX per CUT, or
%           must the collect step pick each CUT out of a shared file?
%   MEMORY  How many workers fit in this PC's memory?
%   GAIN    How long one CUT takes on workers that already hold the model,
%           against running the CUTs one by one.
%
% Runs, in order:
%   SEQ   each selected Test Case with run(tc), one after another
%   PAR1  all of them in one run(tf,'Parallel',true); workers start cold
%   PAR2  the same again; workers may still hold the model from PAR1
%   PAR3  only when workers held the model after PAR2: the probe appends a
%         token to the Top Model Description, saves the model, runs again
%         and asks every worker which Description it holds. The Description
%         is put back and the model saved again right after, so the model
%         file is written twice (ModelVersion goes up by two). A model with
%         unsaved changes is never touched. ModelChangeCheck=false skips it.
%
% The Test File is never saved. Which Test Cases are enabled is changed in
% memory only and put back at the end. SPLIT writes exports into a scratch
% folder under tempdir and deletes it; the ResultSets it imports to check
% them stay listed in Test Manager. Crash dumps already kept by the cluster
% are summarized first as CRASH-OLD lines.
%
% MaxTargets caps how many enabled targets are used (default 8). Expect a
% total of roughly 2.5 times the SEQ run.
%
% Send back every line that begins with "PARALLEL-X-v1".

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'Workers', 2, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 1 && x == fix(x));
addParameter(p, 'MaxTargets', 8, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 2 && x == fix(x));
addParameter(p, 'ModelChangeCheck', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'KeepPool', false, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
workers = double(p.Results.Workers);
maxTargets = double(p.Results.MaxTargets);

cfg = st_require_runtime_target();
totalTimer = tic;
probeStart = now;
st_log(cfg, 'INFO', ...
    ['Cross-CUT parallel probe start | Workers=%d | MaxTargets=%d | ' ...
     'ModelChangeCheck=%s'], ...
    workers, maxTargets, yes_no(p.Results.ModelChangeCheck));

report = struct('Verdict', "", 'Environment', [], 'Targets', table(), ...
    'Runs', [], 'Model', "", 'Split', "", 'SuggestedWorkers', NaN, ...
    'SpeedupCold', NaN, 'SpeedupWarm', NaN, 'Differences', strings(0,1));

env = probe_environment();
report.Environment = env;
emit('ENV', ['Release=R%s | PCT=%s | License=%s | PoolBefore=%s | ' ...
    'ProfileWorkers=%d | MemTotalGB=%.1f | MemAvailGB=%.1f'], ...
    env.Release, yes_no(env.HasToolbox), yes_no(env.HasLicense), ...
    char(env.PoolBefore), env.ProfileWorkers, env.MemTotalGB, ...
    env.MemAvailGB);
if ~env.HasToolbox || ~env.HasLicense
    report = finish(cfg, report, "NO_PCT", ...
        'Parallel Computing Toolbox is not installed or not licensed', ...
        totalTimer);
    return;
end
report_crash_files(cfg, 'CRASH-OLD', scan_crash_files(-Inf));

try
    [tf, cases, targets] = select_targets(cfg, maxTargets);
catch ME
    report = finish(cfg, report, "TARGETS_NOT_FOUND", ...
        sprintf('%s: %s', ME.identifier, ME.message), totalTimer);
    return;
end
report.Targets = targets;
targetCount = height(targets);
emit('TARGETS', 'Count=%d | TestCases=%s', targetCount, ...
    char(strjoin(string(targets.TestCaseName)', ', ')));
if targetCount < workers
    st_log(cfg, 'WARN', ...
        ['Cross-CUT parallel probe | %d target(s) for %d worker(s); an idle ' ...
         'worker can look STALE in the MODEL check'], targetCount, workers);
end

runs = run_sequential(cfg, cases, targets);
emit_entry(runs(1));

memBeforePool = available_memory_gb();
try
    [pool, poolInfo, poolCleanup] = ensure_pool( ...
        cfg, workers, p.Results.KeepPool); %#ok<ASGLU>
catch ME
    report.Runs = runs;
    report = finish(cfg, report, "POOL_FAILED", ...
        sprintf('%s: %s', ME.identifier, ME.message), totalTimer);
    return;
end
memAfterPool = available_memory_gb();
emit('POOL', ['Class=%s | Started=%s | Workers=%d | StartSec=%.1f | ' ...
    'MemBeforeGB=%.1f | MemAfterGB=%.1f'], ...
    char(poolInfo.Class), yes_no(poolInfo.Started), poolInfo.Workers, ...
    poolInfo.StartSec, memBeforePool, memAfterPool);

scopeCleanup = scope_in_memory(cfg, tf, cases); %#ok<NASGU>

par1 = run_batch(cfg, tf, targets, "PAR1");
runs(end+1) = par1;
emit_entry(par1);
if par1.Status ~= "OK"
    report.Runs = runs;
    report = parallel_failed(cfg, report, par1, probeStart, totalTimer);
    return;
end
state1 = query_workers(cfg, pool, cfg.TopModel, '');
emit('WORKERS', 'After=PAR1 | Loaded=%d/%d | Status=%s', ...
    state1.Loaded, state1.Count, char(state1.Status));
mem = memory_estimate(memBeforePool, memAfterPool, par1, ...
    poolInfo.Workers, env.ProfileWorkers);
report.SuggestedWorkers = mem.Suggested;
emit('MEMORY', ['BeforePoolGB=%.1f | AfterPoolGB=%.1f | Par1MinGB=%.1f | ' ...
    'Samples=%d | IdlePerWorkerGB=%.2f | BusyPerWorkerGB=%.2f | ' ...
    'SuggestedWorkers=%d | (estimate, keeps %.0f GB free)'], ...
    memBeforePool, memAfterPool, par1.MinAvailGB, par1.MemSamples, ...
    mem.IdlePerWorker, mem.BusyPerWorker, mem.Suggested, mem.ReserveGB);

par2 = run_batch(cfg, tf, targets, "PAR2");
runs(end+1) = par2;
emit_entry(par2);
if par2.Status ~= "OK"
    report.Runs = runs;
    report = parallel_failed(cfg, report, par2, probeStart, totalTimer);
    return;
end
state2 = query_workers(cfg, pool, cfg.TopModel, '');
emit('WORKERS', 'After=PAR2 | Loaded=%d/%d | Status=%s', ...
    state2.Loaded, state2.Count, char(state2.Status));

[report.Split, splitDetail] = split_check(cfg, par2.Result, targets);
emit('SPLIT', '%s | %s', char(report.Split), char(splitDetail));

[report.Model, modelDetail, par3] = model_check(cfg, tf, targets, pool, ...
    state2, p.Results.ModelChangeCheck);
if ~isempty(par3)
    runs(end+1) = par3;
end
emit('MODEL', '%s | %s', char(report.Model), char(modelDetail));
report.Runs = runs;

report.SpeedupCold = runs(1).ElapsedSec / par1.ElapsedSec;
report.SpeedupWarm = runs(1).ElapsedSec / par2.ElapsedSec;
emit('GAIN', ['SeqSec=%.1f | Par1Sec=%.1f | Par2Sec=%.1f | ' ...
    'SpeedupCold=%.2f | SpeedupWarm=%.2f | SeqMedianSecPerCase=%.1f | ' ...
    'Par2WorkerSecPerCase=%.1f | Targets=%d | Workers=%d | PoolStartSec=%.1f'], ...
    runs(1).ElapsedSec, par1.ElapsedSec, par2.ElapsedSec, ...
    report.SpeedupCold, report.SpeedupWarm, ...
    median(runs(1).Cases.Seconds, 'omitnan'), ...
    par2.ElapsedSec * poolInfo.Workers / targetCount, targetCount, ...
    poolInfo.Workers, poolInfo.StartSec);

differences = strings(0,1);
scopeProblems = 0;
for k = 2:numel(runs)
    if runs(k).Status ~= "OK"
        continue;
    end
    found = compare_cases(runs(1).Cases, runs(k).Cases);
    for j = 1:numel(found)
        emit('DIFF', '%s | %s', char(runs(k).Label), char(found(j)));
    end
    differences = [differences; runs(k).Label + " | " + found]; %#ok<AGROW>
    scopeProblems = scopeProblems + sum(~runs(k).Cases.Present) + ...
        numel(runs(k).Extra);
end
report.Differences = differences;

if isempty(differences)
    results = "SAME";
else
    results = "MISMATCH(" + numel(differences) + ")";
end
if scopeProblems == 0
    scope = "OK";
else
    scope = "PROBLEMS(" + scopeProblems + ")";
end
verdict = "DONE";
if ~isempty(differences) || scopeProblems > 0
    verdict = "MISMATCH";
end
report = finish(cfg, report, verdict, sprintf( ...
    ['Results=%s | Scope=%s | Model=%s | Split=%s | SuggestedWorkers=%d | ' ...
     'SpeedupWarm=%.2f'], char(results), char(scope), char(report.Model), ...
    char(report.Split), report.SuggestedWorkers, report.SpeedupWarm), ...
    totalTimer);
end


function [tf, cases, targets] = select_targets(cfg, maxTargets)
targets = st_resolve_target_cut_paths(st_load_targets(cfg.OnlyEnabled), cfg);
if ~isfile(cfg.TestFile)
    error('simtest:ParallelProbeTestFileNotFound', ...
        'Test File not found: %s', cfg.TestFile);
end
tf = sltest.testmanager.TestFile(cfg.TestFile);
suite = getTestSuiteByName(tf, cfg.TestSuiteName);
if numel(suite) ~= 1
    error('simtest:ParallelProbeSuiteNotFound', ...
        'Expected one Test Suite named %s, found %d.', ...
        cfg.TestSuiteName, numel(suite));
end
suiteCases = getTestCases(suite);
caseNames = strings(numel(suiteCases), 1);
for k = 1:numel(suiteCases)
    caseNames(k) = string(suiteCases(k).Name);
end

keep = false(height(targets), 1);
picked = zeros(0, 1);
for k = 1:height(targets)
    index = find(caseNames == string(targets.TestCaseName(k)), 1);
    if isempty(index) || numel(picked) >= maxTargets
        continue;
    end
    keep(k) = true;
    picked(end+1, 1) = index; %#ok<AGROW>
end
targets = targets(keep,:);
if height(targets) < 2
    error('simtest:ParallelProbeTooFewTargets', ...
        ['Running CUTs together needs at least two enabled targets with ' ...
         'a Test Case in %s. Found %d.'], cfg.TestSuiteName, height(targets));
end
cases = suiteCases(picked);
end


function cleanup = scope_in_memory(cfg, tf, cases)
% Same rule as st_apply_run_test_case_scope, without its saveToFile: only
% the selected Test Cases of the configured suite stay enabled.
selected = strings(numel(cases), 1);
for k = 1:numel(cases)
    selected(k) = string(cases(k).Name);
end
objects = cell(0, 1);
original = false(0, 1);
suites = getTestSuites(tf);
for s = 1:numel(suites)
    suiteName = string(suites(s).Name);
    suiteCases = getTestCases(suites(s));
    for c = 1:numel(suiteCases)
        objects{end+1, 1} = suiteCases(c); %#ok<AGROW>
        original(end+1, 1) = logical(suiteCases(c).Enabled); %#ok<AGROW>
        suiteCases(c).Enabled = suiteName == string(cfg.TestSuiteName) && ...
            any(string(suiteCases(c).Name) == selected);
    end
end
cleanup = onCleanup(@() restore_scope(cfg, objects, original));
st_log(cfg, 'INFO', ...
    'Cross-CUT parallel probe run scope applied in memory | Selected=%d | All=%d', ...
    numel(selected), numel(objects));
end


function restore_scope(cfg, objects, original)
try
    for k = 1:numel(objects)
        objects{k}.Enabled = original(k);
    end
    st_log(cfg, 'INFO', 'Cross-CUT parallel probe run scope restored');
catch ME
    st_log(cfg, 'WARN', ...
        ['Cross-CUT parallel probe run scope restore failed; do not save ' ...
         'the Test File | %s: %s'], ME.identifier, ME.message);
end
end


function entry = run_sequential(cfg, cases, targets)
entry = empty_entry("SEQ");
rows = cell(numel(cases), 1);
st_log(cfg, 'INFO', ...
    'Cross-CUT parallel probe SEQ start | Targets=%d', numel(cases));
totalTimer = tic;
for k = 1:numel(cases)
    caseTimer = tic;
    st_log(cfg, 'INFO', 'Cross-CUT parallel probe SEQ case start | %d/%d | %s', ...
        k, numel(cases), char(string(targets.TestCaseName(k))));
    try
        resultObj = run(cases(k), 'Parallel', false);
        row = summarize_cases(resultObj, targets(k,:), "SEQ");
    catch ME
        if is_user_interrupt(ME)
            rethrow(ME);
        end
        st_log(cfg, 'ERROR', ...
            'Cross-CUT parallel probe SEQ case failed | %s | %s', ...
            char(string(targets.TestCaseName(k))), ...
            getReport(ME, 'extended', 'hyperlinks', 'off'));
        row = missing_row(targets(k,:), "RUN_ERROR");
    end
    row.Seconds = toc(caseTimer);
    rows{k} = row;
end
entry.ElapsedSec = toc(totalTimer);
entry.AfterAvailGB = available_memory_gb();
entry.Cases = vertcat(rows{:});
entry.Status = "OK";
st_log(cfg, 'INFO', ...
    'Cross-CUT parallel probe SEQ complete | elapsed=%.1f sec', entry.ElapsedSec);
end


function entry = run_batch(cfg, tf, targets, label)
entry = empty_entry(label);
st_log(cfg, 'INFO', ...
    'Cross-CUT parallel probe run start | Label=%s | Targets=%d', ...
    char(label), height(targets));
sampler = start_sampler();
batchTimer = tic;
try
    resultObj = run(tf, 'Parallel', true);
    entry.ElapsedSec = toc(batchTimer);
    [entry.MinAvailGB, entry.MemSamples] = stop_sampler(sampler);
catch ME
    entry.ElapsedSec = toc(batchTimer);
    [entry.MinAvailGB, entry.MemSamples] = stop_sampler(sampler);
    if is_user_interrupt(ME)
        rethrow(ME);
    end
    entry.Status = "RUN_ERROR";
    entry.Message = error_text(ME);
    entry.Stack = stack_text(ME);
    st_log(cfg, 'ERROR', ...
        'Cross-CUT parallel probe run failed | Label=%s | elapsed=%.1f sec | %s', ...
        char(label), entry.ElapsedSec, ...
        getReport(ME, 'extended', 'hyperlinks', 'off'));
    return;
end
entry.AfterAvailGB = available_memory_gb();
st_log(cfg, 'INFO', ...
    'Cross-CUT parallel probe run complete | Label=%s | elapsed=%.1f sec', ...
    char(label), entry.ElapsedSec);
try
    [entry.Cases, entry.Extra] = summarize_cases(resultObj, targets, label);
    entry.Result = resultObj;
    entry.Status = "OK";
catch ME
    if is_user_interrupt(ME)
        rethrow(ME);
    end
    entry.Status = "SUMMARY_ERROR";
    entry.Message = error_text(ME);
    entry.Stack = stack_text(ME);
    st_log(cfg, 'ERROR', ...
        'Cross-CUT parallel probe result summary failed | Label=%s | %s', ...
        char(label), getReport(ME, 'extended', 'hyperlinks', 'off'));
end
end


function [T, extra] = summarize_cases(resultObj, targets, label)
% Coverage is read per Test Case result. The ResultSet-level coverage of a
% run over several Test Cases is an aggregate and names no single CUT.
caseResults = st_collect_test_case_results(resultObj);
names = strings(numel(caseResults), 1);
for c = 1:numel(caseResults)
    names(c) = string(safe_property(caseResults{c}, 'Name', ''));
end
n = height(targets);
TestCaseName = string(targets.TestCaseName);
Present = false(n, 1);
Outcome = repmat("MISSING", n, 1);
Decision = repmat("NONE", n, 1);
Execution = repmat("NONE", n, 1);
CoverageObjects = zeros(n, 1);
for k = 1:n
    index = find(names == TestCaseName(k), 1);
    if isempty(index)
        continue;
    end
    Present(k) = true;
    caseResult = caseResults{index};
    Outcome(k) = upper(string(safe_property(caseResult, 'Outcome', 'UNKNOWN')));
    objects = case_coverage(caseResult);
    CoverageObjects(k) = numel(objects);
    if ~isempty(objects)
        rows = st_collect_coverage_summary(resultObj, targets(k,:), ...
            char(label), 'IncludeTestDetails', false, ...
            'CoverageObjects', objects);
        Decision(k) = metric_text(rows, "Decision");
        Execution(k) = metric_text(rows, "Execution");
    end
end
T = table(TestCaseName, Present, Outcome, Decision, Execution, CoverageObjects);
extra = setdiff(names(strlength(names) > 0), TestCaseName);
end


function objects = case_coverage(caseResult)
objects = cell(0, 1);
try
    objects = st_flatten_coverage_results(getCoverageResults(caseResult));
catch
end
if isempty(objects)
    iterations = safe_iterations(caseResult);
    for j = 1:numel(iterations)
        try
            objects = [objects; st_flatten_coverage_results( ...
                getCoverageResults(iterations(j)))]; %#ok<AGROW>
        catch
        end
    end
end
objects = objects(:);
end


function T = missing_row(target, status)
T = table(string(target.TestCaseName), false, string(status), "NONE", ...
    "NONE", 0, 'VariableNames', {'TestCaseName','Present','Outcome', ...
    'Decision','Execution','CoverageObjects'});
end


function text = metric_text(rows, metric)
selected = rows(rows.Level == "CUT" & rows.Metric == metric, :);
if isempty(selected)
    text = "NONE";
    return;
end
parts = strings(height(selected), 1);
for r = 1:height(selected)
    if selected.Status(r) == "OK"
        parts(r) = sprintf('%g/%g', selected.Covered(r), selected.Total(r));
    else
        parts(r) = selected.Status(r);
    end
end
text = strjoin(parts(:)', ',');
end


function found = compare_cases(base, other)
found = strings(0, 1);
for k = 1:height(base)
    name = base.TestCaseName(k);
    index = find(other.TestCaseName == name, 1);
    if isempty(index) || ~other.Present(index)
        found(end+1, 1) = name + " | missing from this run"; %#ok<AGROW>
        continue;
    end
    if base.Outcome(k) ~= other.Outcome(index) || ...
            base.Decision(k) ~= other.Decision(index) || ...
            base.Execution(k) ~= other.Execution(index)
        found(end+1, 1) = sprintf( ...
            '%s | Outcome %s->%s | Decision %s->%s | Execution %s->%s', ...
            name, base.Outcome(k), other.Outcome(index), ...
            base.Decision(k), other.Decision(index), ...
            base.Execution(k), other.Execution(index)); %#ok<AGROW>
    end
end
end


function [verdict, detail] = split_check(cfg, resultObj, targets)
st_log(cfg, 'INFO', 'Cross-CUT parallel probe split check start');
folder = tempname(tempdir);
mkdir(folder);
folderCleanup = onCleanup(@() remove_folder_quietly(folder)); %#ok<NASGU>

aggregate = "OK";
aggregateFile = fullfile(folder, 'aggregate.mldatx');
try
    sltest.testmanager.exportResults(resultObj, aggregateFile);
    if ~isfile(aggregateFile)
        aggregate = "NO_FILE";
    end
catch ME
    aggregate = "FAILED: " + string(ME.message);
end

% PER_CUT keeps one ResultSet per CUT folder; the cleanest split exports a
% single Test Case result.
caseExport = "NOT_TRIED";
caseResults = st_collect_test_case_results(resultObj);
if ~isempty(caseResults)
    caseFile = fullfile(folder, 'case.mldatx');
    expected = string(safe_property(caseResults{1}, 'Name', ''));
    try
        sltest.testmanager.exportResults(caseResults{1}, caseFile);
        imported = sltest.testmanager.importResults(caseFile);
        importedCases = st_collect_test_case_results(imported(1));
        importedNames = strings(numel(importedCases), 1);
        for c = 1:numel(importedCases)
            importedNames(c) = string(safe_property(importedCases{c}, 'Name', ''));
        end
        if isequal(importedNames, expected)
            caseExport = "OK";
        else
            caseExport = "WRONG_CONTENT(" + numel(importedNames) + " cases)";
        end
    catch ME
        caseExport = "FAILED: " + string(ME.message);
    end
end

% Fallback: the collect step reads one shared file and picks each CUT by
% name. That needs per-Test-Case coverage to survive export and import.
perCase = "NOT_TRIED";
if aggregate == "OK"
    try
        imported = sltest.testmanager.importResults(aggregateFile);
        T = summarize_cases(imported(1), targets, "SPLIT");
        perCase = string(sprintf('%d/%d', sum(T.CoverageObjects > 0), height(T)));
    catch ME
        perCase = "FAILED: " + string(ME.message);
    end
end

if caseExport == "OK"
    verdict = "CASE_EXPORT_OK";
elseif aggregate == "OK" && ...
        perCase == string(sprintf('%d/%d', height(targets), height(targets)))
    verdict = "AGGREGATE_BY_NAME";
else
    verdict = "NO_SPLIT";
end
detail = "Aggregate=" + aggregate + " | CaseExport=" + caseExport + ...
    " | AggregatePerCaseCoverage=" + perCase;
st_log(cfg, 'INFO', 'Cross-CUT parallel probe split check complete | %s', ...
    char(verdict));
end


function [verdict, detail, par3] = model_check(cfg, tf, targets, pool, state, enabled)
par3 = [];
if ~(state.Status == "OK")
    verdict = "NOT_CHECKED";
    detail = "worker query failed: " + state.Status;
    return;
end
if state.Loaded == 0
    % Nothing survives between runs, so every run loads the model from disk.
    verdict = "RELOADS_EACH_RUN";
    detail = sprintf('Loaded after PAR2=0/%d', state.Count);
    return;
end
if ~enabled
    verdict = "NOT_CHECKED";
    detail = sprintf('Loaded after PAR2=%d/%d | ModelChangeCheck=false', ...
        state.Loaded, state.Count);
    return;
end

uuid = char(java.util.UUID.randomUUID());
token = ['PARALLEL_PROBE_' uuid(1:8)];
[status, modelCleanup] = change_model(cfg, cfg.TopModel, token);
if status ~= "CHANGED"
    verdict = "NOT_CHECKED";
    detail = "model change " + status;
    return;
end
par3 = run_batch(cfg, tf, targets, "PAR3");
emit_entry(par3);
after = query_workers(cfg, pool, cfg.TopModel, token);
clear modelCleanup;

detail = sprintf('Loaded after PAR2=%d/%d | After PAR3 loaded=%d with token=%d', ...
    state.Loaded, state.Count, after.Loaded, after.WithToken);
if par3.Status ~= "OK"
    verdict = "PAR3_FAILED";
elseif after.Status ~= "OK"
    verdict = "NOT_CHECKED";
elseif after.Loaded == 0
    verdict = "RELOADS_EACH_RUN";
elseif after.WithToken == after.Loaded
    verdict = "RELOADS_CHANGED";
elseif after.WithToken == 0
    verdict = "STALE";
else
    verdict = "MIXED";
end
end


function [status, cleanup] = change_model(cfg, model, token)
cleanup = [];
if ~bdIsLoaded(model)
    status = "SKIPPED_NOT_LOADED";
    return;
end
if strcmp(get_param(model, 'Dirty'), 'on')
    status = "SKIPPED_UNSAVED_CHANGES";
    st_log(cfg, 'WARN', ...
        'Cross-CUT parallel probe model check skipped | %s has unsaved changes', ...
        model);
    return;
end
original = get_param(model, 'Description');
st_log(cfg, 'INFO', ...
    'Cross-CUT parallel probe model change start | Model=%s | Token=%s', ...
    model, token);
try
    set_param(model, 'Description', [original newline token]);
    save_system(model);
catch ME
    try
        set_param(model, 'Description', original);
    catch
    end
    status = "SAVE_FAILED(" + string(ME.message) + ")";
    st_log(cfg, 'WARN', ...
        'Cross-CUT parallel probe model change failed | %s: %s', ...
        ME.identifier, ME.message);
    return;
end
cleanup = onCleanup(@() restore_model(cfg, model, original));
status = "CHANGED";
st_log(cfg, 'INFO', 'Cross-CUT parallel probe model change complete');
end


function restore_model(cfg, model, original)
st_log(cfg, 'INFO', 'Cross-CUT parallel probe model restore start');
try
    set_param(model, 'Description', original);
    save_system(model);
    st_log(cfg, 'INFO', 'Cross-CUT parallel probe model restore complete');
catch ME
    st_log(cfg, 'ERROR', ...
        ['Cross-CUT parallel probe model restore failed; the %s Description ' ...
         'still ends with the probe token. Remove that line and save | %s: %s'], ...
        model, ME.identifier, ME.message);
end
end


function state = query_workers(cfg, pool, model, token)
% Builtins only: a worker cannot be relied on to see this file's local
% functions. find_system answers both questions without failing when the
% model is not loaded; SearchDepth 0 looks at loaded models only, not at
% their blocks.
state = struct('Count', pool.NumWorkers, 'Loaded', NaN, 'WithToken', NaN, ...
    'Status', "OK");
if isempty(token)
    token = '.*';
end
ask = @(m, tok) [double(bdIsLoaded(m)), double(~isempty(find_system( ...
    'SearchDepth', 0, 'RegExp', 'on', 'Name', ['^' m '$'], ...
    'Description', tok)))];
try
    values = fetchOutputs(parfevalOnAll(pool, ask, 1, model, token));
    state.Count = size(values, 1);
    state.Loaded = sum(values(:,1));
    state.WithToken = sum(values(:,1) & values(:,2));
catch ME
    state.Status = "ERROR(" + string(ME.message) + ")";
    st_log(cfg, 'WARN', ...
        'Cross-CUT parallel probe worker query failed | %s: %s', ...
        ME.identifier, ME.message);
end
end


function mem = memory_estimate(beforePool, afterPool, par1, workers, profileWorkers)
mem = struct('IdlePerWorker', NaN, 'BusyPerWorker', NaN, 'Suggested', NaN, ...
    'ReserveGB', 2);
low = par1.MinAvailGB;
if isnan(low)
    low = par1.AfterAvailGB;
end
mem.IdlePerWorker = (beforePool - afterPool) / workers;
mem.BusyPerWorker = (afterPool - low) / workers;
perWorker = max(mem.IdlePerWorker, 0) + max(mem.BusyPerWorker, 0);
if ~(perWorker > 0) || isnan(beforePool)
    return;
end
mem.Suggested = max(1, floor((beforePool - mem.ReserveGB) / perWorker));
if ~isnan(profileWorkers)
    mem.Suggested = min(mem.Suggested, profileWorkers);
end
end


function sampler = start_sampler()
% The client waits inside run() while workers simulate. A timer may fire
% during that wait; when it never does, Samples stays 0.
store = containers.Map({'min', 'count'}, {Inf, 0});
sampler = struct('Timer', [], 'Store', store);
try
    sampler.Timer = timer('ExecutionMode', 'fixedSpacing', 'Period', 1, ...
        'BusyMode', 'drop', 'TimerFcn', @(~, ~) sample_memory(store));
    start(sampler.Timer);
catch
end
end


function sample_memory(store)
value = available_memory_gb();
if ~isnan(value)
    store('min') = min(store('min'), value);
    store('count') = store('count') + 1;
end
end


function [minGB, count] = stop_sampler(sampler)
try
    stop(sampler.Timer);
    delete(sampler.Timer);
catch
end
minGB = sampler.Store('min');
count = sampler.Store('count');
if isinf(minGB)
    minGB = NaN;
end
end


function report = parallel_failed(cfg, report, entry, since, totalTimer)
report_crash_files(cfg, 'CRASH', scan_crash_files(since));
report = finish(cfg, report, "PARALLEL_FAILED", ...
    sprintf('%s | %s', char(entry.Label), char(entry.Message)), totalTimer);
end


function files = scan_crash_files(since)
% MATLAB writes its own dumps to tempdir. A pool writes its workers' dumps
% into the cluster job storage and keeps that job because of them.
files = strings(0, 1);
roots = unique([string(tempdir); string(pwd)]);
for f = 1:numel(roots)
    files = [files; recent_files( ...
        dir(fullfile(roots(f), 'matlab_crash_dump*')), since)]; %#ok<AGROW>
end
storage = job_storage_location();
if strlength(storage) > 0 && isfolder(storage)
    listing = dir(fullfile(storage, '**', '*'));
    listing = listing(~[listing.isdir]);
    names = lower(string({listing.name}));
    listing = listing(contains(names, "crash") | endsWith(names, ".dmp"));
    files = [files; recent_files(listing, since)];
end
files = unique(files);
end


function report_crash_files(cfg, label, files)
emit(label, 'Count=%d', numel(files));
for k = 1:numel(files)
    [reason, frames] = crash_summary(files(k));
    emit(label, 'File=%s | Reason=%s', char(files(k)), char(reason));
    % Workers that die together almost always die the same way, so one
    % stack is enough.
    if k == 1
        for j = 1:numel(frames)
            emit([label '-STACK'], '%s', char(frames(j)));
        end
    end
end
if ~isempty(files)
    st_log(cfg, 'WARN', 'Cross-CUT parallel probe %s | Count=%d', ...
        label, numel(files));
end
end


function files = recent_files(listing, since)
files = strings(0, 1);
for k = 1:numel(listing)
    if listing(k).datenum >= since
        files(end+1, 1) = string(fullfile( ...
            listing(k).folder, listing(k).name)); %#ok<AGROW>
    end
end
end


function location = job_storage_location()
location = "";
try
    cluster = parcluster('Processes');
    value = cluster.JobStorageLocation;
    if ischar(value) || isstring(value)
        location = string(value);
    end
catch
end
end


function [reason, frames] = crash_summary(dumpFile)
reason = "UNREADABLE";
frames = strings(0, 1);
try
    lines = strtrim(string(splitlines(fileread(dumpFile))));
catch
    return;
end
reason = "UNKNOWN";
keys = ["Abnormal termination", "Segmentation violation", ...
    "Access violation", "Out of memory", "bad_alloc", "Assertion"];
hit = find(contains(lines, keys, 'IgnoreCase', true), 1);
if ~isempty(hit)
    reason = lines(hit);
    if endsWith(reason, ":") && hit < numel(lines)
        reason = reason + " " + lines(hit + 1);
    end
end
% The first frames name the module that faulted: a MathWorks library, or a
% MEX/S-Function file of the model.
first = find(startsWith(lines, "Stack Trace", 'IgnoreCase', true), 1);
if ~isempty(first)
    block = lines(first + 1:min(numel(lines), first + 12));
    frames = block(strlength(block) > 0);
end
end


function env = probe_environment()
env = struct('Release', version('-release'), ...
    'HasToolbox', ~isempty(ver('parallel')), ...
    'HasLicense', license('test', 'Distrib_Computing_Toolbox') == 1, ...
    'PoolBefore', "NONE", 'ProfileWorkers', NaN, ...
    'MemTotalGB', NaN, 'MemAvailGB', NaN);
try
    [~, systemView] = memory;
    env.MemTotalGB = systemView.PhysicalMemory.Total / 2^30;
    env.MemAvailGB = systemView.PhysicalMemory.Available / 2^30;
catch
end
if ~env.HasToolbox
    return;
end
try
    % The pool size parpool picks when Workers is not given.
    cluster = parcluster('Processes');
    env.ProfileWorkers = cluster.NumWorkers;
catch
end
try
    pool = gcp('nocreate');
    if ~isempty(pool)
        env.PoolBefore = string(sprintf('%s(%d)', class(pool), ...
            pool.NumWorkers));
    end
catch
    env.PoolBefore = "UNKNOWN";
end
end


function [pool, info, cleanup] = ensure_pool(cfg, workers, keepPool)
cleanup = [];
info = struct('Class', "", 'Started', false, 'Workers', 0, 'StartSec', 0);
pool = gcp('nocreate');
if isempty(pool)
    st_log(cfg, 'INFO', ...
        'Cross-CUT parallel probe pool start | Profile=Processes | Workers=%d', ...
        workers);
    poolTimer = tic;
    pool = parpool('Processes', workers);
    info.Started = true;
    info.StartSec = toc(poolTimer);
    st_log(cfg, 'INFO', ...
        'Cross-CUT parallel probe pool start complete | Workers=%d | elapsed=%.1f sec', ...
        pool.NumWorkers, info.StartSec);
    if ~keepPool
        cleanup = onCleanup(@() delete_pool(cfg, pool));
    end
elseif pool.NumWorkers ~= workers
    st_log(cfg, 'WARN', ...
        'Cross-CUT parallel probe uses the open pool | Workers=%d | Requested=%d', ...
        pool.NumWorkers, workers);
end
info.Class = string(class(pool));
info.Workers = pool.NumWorkers;
if isa(pool, 'parallel.ThreadPool')
    st_log(cfg, 'WARN', ...
        ['Cross-CUT parallel probe | the open pool is a thread pool; Test ' ...
         'Manager needs a process pool. Run delete(gcp) and try again']);
end
end


function delete_pool(cfg, pool)
st_log(cfg, 'INFO', 'Cross-CUT parallel probe pool delete start');
try
    delete(pool);
    st_log(cfg, 'INFO', 'Cross-CUT parallel probe pool delete complete');
catch ME
    st_log(cfg, 'WARN', ...
        'Cross-CUT parallel probe pool delete failed | %s: %s', ...
        ME.identifier, ME.message);
end
end


function report = finish(cfg, report, verdict, detail, totalTimer)
report.Verdict = verdict;
emit('VERDICT', '%s | %s | TotalSec=%.1f', char(verdict), detail, ...
    toc(totalTimer));
level = 'WARN';
if verdict == "DONE"
    level = 'INFO';
end
st_log(cfg, level, ...
    'Cross-CUT parallel probe complete | Verdict=%s | %s | elapsed=%.1f sec', ...
    char(verdict), detail, toc(totalTimer));
end


function emit_entry(entry)
if entry.Status ~= "OK"
    emit('RUN', 'Label=%s | Status=%s | Sec=%.1f | MinAvailGB=%.1f | %s', ...
        char(entry.Label), char(entry.Status), entry.ElapsedSec, ...
        entry.MinAvailGB, char(entry.Message));
    emit('STACK', '%s | %s', char(entry.Label), char(entry.Stack));
    return;
end
cases = entry.Cases;
emit('RUN', ['Label=%s | Status=OK | Sec=%.1f | Present=%d/%d | Extra=%d | ' ...
    'Passed=%d | MinAvailGB=%.1f | Samples=%d | AfterAvailGB=%.1f'], ...
    char(entry.Label), entry.ElapsedSec, sum(cases.Present), height(cases), ...
    numel(entry.Extra), sum(cases.Outcome == "PASSED"), entry.MinAvailGB, ...
    entry.MemSamples, entry.AfterAvailGB);
end


function emit(section, formatText, varargin)
text = sprintf(formatText, varargin{:});
text = regexprep(text, '\s*[\r\n]+\s*', ' ');
fprintf('PARALLEL-X-v1 %s | %s\n', section, text);
end


function entry = empty_entry(label)
entry = struct('Label', string(label), 'Status', "NOT_RUN", ...
    'ElapsedSec', NaN, 'Cases', table(), 'Extra', strings(0, 1), ...
    'Message', "", 'Stack', "", 'MinAvailGB', NaN, 'MemSamples', 0, ...
    'AfterAvailGB', NaN, 'Result', []);
end


function value = available_memory_gb()
value = NaN;
try
    [~, systemView] = memory;
    value = systemView.PhysicalMemory.Available / 2^30;
catch
end
end


function text = error_text(ME)
text = string(ME.identifier) + ": " + string(ME.message);
if ~isempty(ME.cause)
    text = text + " | cause: " + string(ME.cause{1}.message);
end
end


function text = stack_text(ME)
count = min(numel(ME.stack), 4);
parts = strings(count, 1);
for k = 1:count
    parts(k) = sprintf('%s:%d', ME.stack(k).name, ME.stack(k).line);
end
text = strjoin(parts(:)', ' < ');
end


function tf = is_user_interrupt(ME)
id = lower(char(string(ME.identifier)));
msg = lower(char(string(ME.message)));
tf = contains(id, 'operationterminated') || contains(id, 'interrupted') || ...
    contains(msg, 'terminated by user') || contains(msg, 'interrupted by user');
end


function results = safe_iterations(caseResult)
try
    results = getIterationResults(caseResult);
catch
    results = [];
end
end


function value = safe_property(object, property, defaultValue)
try
    value = object.(property);
catch
    value = defaultValue;
end
end


function remove_folder_quietly(folder)
try
    if isfolder(folder)
        rmdir(folder, 's');
    end
catch
end
end


function text = yes_no(value)
if value
    text = 'YES';
else
    text = 'NO';
end
end
