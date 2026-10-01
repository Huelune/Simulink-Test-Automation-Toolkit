function report = st_probe_per_cut_parallel(varargin)
%ST_PROBE_PER_CUT_PARALLEL Compare run(tc) with run(tc,'Parallel',true).
%
% report = st_probe_per_cut_parallel()
% report = st_probe_per_cut_parallel('TestCase', 'UT_REQ_Foo')
% report = st_probe_per_cut_parallel(..., 'Workers', 4)
% report = st_probe_per_cut_parallel(..., 'ParallelRuns', 2)
% report = st_probe_per_cut_parallel(..., 'Marker', false)
% report = st_probe_per_cut_parallel(..., 'KeepPool', true)
%
% EXPERIMENTAL: exists only on branch exp/per-cut-parallel.
%
% PER_CUT runs one Test Case at a time, and each Test Case holds one
% Iteration per scenario. This probe asks whether those Iterations can go to
% a parallel pool through run(tc,'Parallel',true) and give the same result
% faster. PER_CUT itself is not changed.
%
% The chosen Test Case runs once with run(tc), then ParallelRuns times with
% run(tc,'Parallel',true). Every parallel run is compared with the
% sequential one: Test Case and Iteration outcomes, logged output runs and
% signals, and CUT Decision/Execution coverage.
%
% Timing. Every CUT has its own Harness, so each PER_CUT target pays a first
% run on the client and on the workers alike. SEQ against PAR1 is therefore
% the per-CUT comparison, and the verdict uses it. PAR2 and later show the
% warm cost, which PER_CUT sees only when it reruns a Test Case after an
% expected-value update. The pool start is reported apart: PER_CUT would pay
% it once per run, not once per CUT.
%
% Unsaved changes. Before each run PER_CUT edits the Test File coverage
% filter lists in memory and does not save them (CoverageFilterExistingPolicy
% REPLACE). If the workers read the Test File from disk, parallel runs would
% lose that isolation. With Marker=true (default) the probe adds an empty
% CVF (no rules, so no coverage changes) to the Test Case filter list in
% memory only, and reports whether each run's coverage data carries it.
% SEQ must carry it for the check to count. The list is put back when the
% probe ends, and the Test File is never saved. Test Manager may still mark
% the file as modified; its content is unchanged. If the PAR runs fail with
% a message about unsaved changes, that is the answer to this check; run
% again with Marker=false to see whether parallel runs work at all.
%
% Worker failures. A worker that dies mid-run surfaces on the client only as
% "Simulation stopped before end time". ENV, POOL and RUN lines report free
% physical memory, and when a parallel run fails the probe prints CRASH
% lines from the crash dumps written since it started.
%
% With no TestCase, the target whose Test Case has the most Iterations is
% chosen from the enabled rows of the management workbook.
%
% Send back every line that begins with "PARALLEL-PROBE-v1".
%
% Nothing is saved: not the Test File, the model, Excel or result files.
% The PER_CUT expected-value logging preparation is not applied, so the Test
% Case logs what it already logs. A pool this probe started is deleted when
% it ends unless KeepPool=true.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'TestCase', '', ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(p, 'Workers', 0, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 0 && x == fix(x));
addParameter(p, 'ParallelRuns', 2, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 1 && x == fix(x));
addParameter(p, 'Marker', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'KeepPool', false, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
requestedName = strtrim(char(string(p.Results.TestCase)));
workers = double(p.Results.Workers);
parallelRuns = double(p.Results.ParallelRuns);
useMarker = p.Results.Marker;

cfg = st_require_runtime_target();
totalTimer = tic;
st_log(cfg, 'INFO', ...
    ['Per-CUT parallel probe start | TestCase=%s | Workers=%d | ' ...
     'ParallelRuns=%d | Marker=%s'], ...
    text_or(requestedName, 'AUTO'), workers, parallelRuns, yes_no(useMarker));

report = struct('Verdict', "", 'Environment', [], 'Target', [], ...
    'Marker', [], 'Pool', [], 'Workers', table(), 'Runs', [], ...
    'Differences', strings(0,1), 'SpeedupFirst', NaN, 'SpeedupLast', NaN);

probeStart = now;
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

try
    [tc, target, iterationCount] = select_test_case(cfg, requestedName);
catch ME
    report = finish(cfg, report, "TARGET_NOT_FOUND", ...
        sprintf('%s: %s', ME.identifier, ME.message), totalTimer);
    return;
end
report.Target = struct('No', double(target.No), ...
    'CUTName', string(target.CUTName), 'CUTPath', string(target.CUTPath), ...
    'TestCaseName', string(target.TestCaseName), ...
    'Iterations', iterationCount);
emit('TARGET', 'No=%g | CUT=%s | TestCase=%s | Iterations=%d', ...
    double(target.No), char(string(target.CUTName)), ...
    char(string(target.TestCaseName)), iterationCount);
if iterationCount < 2
    st_log(cfg, 'WARN', ...
        ['Per-CUT parallel probe | TestCase=%s has %d Iteration(s); ' ...
         'run(tc,''Parallel'',true) has nothing to split'], ...
        char(string(target.TestCaseName)), iterationCount);
end

marker = struct('Enabled', false, 'File', "", 'Status', "OFF");
markerCleanup = []; %#ok<NASGU>
if useMarker
    try
        [marker, markerCleanup] = attach_marker(cfg, tc); %#ok<ASGLU>
    catch ME
        marker.Status = "ATTACH_FAILED";
        st_log(cfg, 'WARN', ...
            ['Per-CUT parallel probe marker attach failed; unsaved-change ' ...
             'check skipped | %s: %s'], ME.identifier, ME.message);
    end
end
report.Marker = marker;
emit('MARKER', 'Status=%s | File=%s', char(marker.Status), ...
    char(text_or(marker.File, '-')));

runs = run_once(cfg, tc, target, "SEQ", false, marker);
emit_run(runs(1));
if runs(1).Status ~= "OK"
    report.Runs = runs;
    report = finish(cfg, report, "SEQUENTIAL_FAILED", ...
        char(runs(1).Message), totalTimer);
    return;
end

try
    [pool, poolInfo, poolCleanup] = ensure_pool( ...
        cfg, workers, p.Results.KeepPool); %#ok<ASGLU>
catch ME
    report.Runs = runs;
    report = finish(cfg, report, "POOL_FAILED", ...
        sprintf('%s: %s', ME.identifier, ME.message), totalTimer);
    return;
end
report.Pool = poolInfo;
emit('POOL', 'Class=%s | Started=%s | Workers=%d | StartSec=%.1f | MemAvailGB=%.1f', ...
    char(poolInfo.Class), yes_no(poolInfo.Started), poolInfo.Workers, ...
    poolInfo.StartSec, available_memory_gb());
report.Workers = probe_workers(cfg, pool, cfg.TopModel);

for k = 1:parallelRuns
    runs(end+1) = run_once(cfg, tc, target, "PAR" + k, true, marker); %#ok<AGROW>
    emit_run(runs(end));
    if runs(end).Status ~= "OK"
        break;
    end
end
report.Runs = runs;

differences = strings(0,1);
failedRun = [];
for k = 2:numel(runs)
    if runs(k).Status ~= "OK"
        failedRun = runs(k);
        continue;
    end
    found = compare_runs(runs(1), runs(k));
    for j = 1:numel(found)
        emit('DIFF', '%s | %s', char(runs(k).Label), char(found(j)));
    end
    differences = [differences; runs(k).Label + " | " + found]; %#ok<AGROW>
end
report.Differences = differences;

parallel = runs(2:end);
parallel = parallel([parallel.Status] == "OK");
if ~isempty(parallel)
    report.SpeedupFirst = runs(1).ElapsedSec / parallel(1).ElapsedSec;
    report.SpeedupLast = runs(1).ElapsedSec / parallel(end).ElapsedSec;
    emit('COMPARE', ['Differences=%d | SeqSec=%.1f | Par1Sec=%.1f | ' ...
        'ParLastSec=%.1f | SpeedupFirst=%.2f | SpeedupLast=%.2f | ' ...
        'PoolStartSec=%.1f | Unsaved=%s'], ...
        numel(differences), runs(1).ElapsedSec, parallel(1).ElapsedSec, ...
        parallel(end).ElapsedSec, report.SpeedupFirst, ...
        report.SpeedupLast, poolInfo.StartSec, ...
        char(unsaved_verdict(runs(1), parallel)));
end

% Below 1.2x the pool is not worth what it costs to start and hold.
if ~isempty(failedRun)
    report_crash_dumps(cfg, probeStart);
    report = finish(cfg, report, "PARALLEL_FAILED", ...
        sprintf('%s | %s', char(failedRun.Label), char(failedRun.Message)), ...
        totalTimer);
elseif ~isempty(differences)
    report = finish(cfg, report, "MISMATCH", ...
        sprintf('%d difference(s); see DIFF lines', numel(differences)), ...
        totalTimer);
elseif report.SpeedupFirst >= 1.2
    report = finish(cfg, report, "SAME_FASTER", ...
        sprintf('SpeedupFirst=%.2f | Iterations=%d | Workers=%d', ...
        report.SpeedupFirst, iterationCount, poolInfo.Workers), totalTimer);
else
    report = finish(cfg, report, "SAME_NOT_FASTER", ...
        sprintf('SpeedupFirst=%.2f | Iterations=%d | Workers=%d', ...
        report.SpeedupFirst, iterationCount, poolInfo.Workers), totalTimer);
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


function [tc, target, iterationCount] = select_test_case(cfg, requestedName)
targets = st_load_targets(cfg.OnlyEnabled && isempty(requestedName));
targets = st_resolve_target_cut_paths(targets, cfg);
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
cases = getTestCases(suite);
caseNames = strings(numel(cases), 1);
for k = 1:numel(cases)
    caseNames(k) = string(cases(k).Name);
end

targetNames = string(targets.TestCaseName);
if isempty(requestedName)
    candidates = (1:height(targets))';
else
    candidates = find(targetNames == string(requestedName), 1);
    if isempty(candidates)
        error('simtest:ParallelProbeTargetNotFound', ...
            'Test Case %s is not a target row in the management workbook.', ...
            requestedName);
    end
end

best = 0;
iterationCount = -1;
tc = [];
for k = candidates'
    caseIndex = find(caseNames == targetNames(k), 1);
    if isempty(caseIndex)
        continue;
    end
    count = numel(getIterations(cases(caseIndex)));
    if count > iterationCount
        best = k;
        iterationCount = count;
        tc = cases(caseIndex);
    end
end
if best == 0
    error('simtest:ParallelProbeTestCaseNotFound', ...
        'No target Test Case exists in Test Suite %s.', cfg.TestSuiteName);
end
target = targets(best,:);
end


function [marker, cleanup] = attach_marker(cfg, tc)
% The marker must hold no rules, so it changes nothing in the coverage it
% rides along with. It is only a name to look for in the Result.
st_log(cfg, 'INFO', 'Per-CUT parallel probe marker attach start');
folder = tempname(tempdir);
[created, message] = mkdir(folder);
if ~created
    error('simtest:ParallelProbeMarkerFolderFailed', ...
        'Cannot create %s: %s', folder, message);
end
% slcoverage.Filter.save checks the current folder even for an absolute
% file name, so save from inside the scratch folder.
previousFolder = pwd;
cd(folder);
base = fullfile(folder, 'parallel_probe_marker');
try
    filterObj = slcoverage.Filter;
    save(filterObj, base);
catch ME
    cd(previousFolder);
    remove_folder_quietly(folder);
    rethrow(ME);
end
cd(previousFolder);
file = [base '.cvf'];
if ~isfile(file) && isfile(base)
    file = base;
end
if ~isfile(file)
    remove_folder_quietly(folder);
    error('simtest:ParallelProbeMarkerSaveFailed', ...
        'The marker CVF was not created: %s', file);
end

settings = getCoverageSettings(tc);
original = filter_list(settings.CoverageFilterFilename);
settings.CoverageFilterFilename = [original; string(file)];
cleanup = onCleanup(@() detach_marker(cfg, settings, original, folder));
marker = struct('Enabled', true, 'File', string(file), 'Status', "ATTACHED");
st_log(cfg, 'INFO', ...
    'Per-CUT parallel probe marker attach complete | File=%s | Existing=%d', ...
    file, numel(original));
end


function detach_marker(cfg, settings, original, folder)
st_log(cfg, 'INFO', 'Per-CUT parallel probe marker detach start');
try
    if isempty(original)
        settings.CoverageFilterFilename = "";
    else
        settings.CoverageFilterFilename = original;
    end
    actual = filter_list(settings.CoverageFilterFilename);
    if ~isequal(actual, original)
        st_log(cfg, 'WARN', ...
            ['Per-CUT parallel probe marker detach readback differs | ' ...
             'Expected=%s | Actual=%s'], ...
            char(strjoin(original(:)', ', ')), char(strjoin(actual(:)', ', ')));
    end
catch ME
    st_log(cfg, 'WARN', ...
        ['Per-CUT parallel probe marker detach failed; the Test Case ' ...
         'filter list may still name the marker. Do not save the Test ' ...
         'File | %s: %s'], ME.identifier, ME.message);
end
remove_folder_quietly(folder);
st_log(cfg, 'INFO', 'Per-CUT parallel probe marker detach complete');
end


function entry = run_once(cfg, tc, target, label, parallel, marker)
entry = empty_run(label, parallel);
st_log(cfg, 'INFO', ...
    'Per-CUT parallel probe run start | Label=%s | Parallel=%s | TestCase=%s', ...
    char(label), yes_no(parallel), char(string(target.TestCaseName)));
timer = tic;
try
    % Say false outright so SEQ does not follow the Test Manager toolstrip.
    resultObj = run(tc, 'Parallel', parallel);
    entry.ElapsedSec = toc(timer);
    % Workers keep the model loaded after a run, so this shows what they
    % hold. A worker that died has already given its memory back.
    entry.MemAvailGB = available_memory_gb();
catch ME
    entry.ElapsedSec = toc(timer);
    entry.MemAvailGB = available_memory_gb();
    if is_user_interrupt(ME)
        rethrow(ME);
    end
    entry.Status = "RUN_ERROR";
    entry.Message = error_text(ME);
    entry.Stack = stack_text(ME);
    st_log(cfg, 'ERROR', ...
        'Per-CUT parallel probe run failed | Label=%s | elapsed=%.1f sec | %s', ...
        char(label), entry.ElapsedSec, ...
        getReport(ME, 'extended', 'hyperlinks', 'off'));
    return;
end
st_log(cfg, 'INFO', ...
    'Per-CUT parallel probe run complete | Label=%s | elapsed=%.1f sec', ...
    char(label), entry.ElapsedSec);
entry = summarize_result(cfg, entry, resultObj, target, marker);
end


function entry = summarize_result(cfg, entry, resultObj, target, marker)
try
    [entry.Iterations, entry.Outcome] = iteration_table(resultObj);
    entry.IterationCount = height(entry.Iterations);
    entry.PassedCount = sum(entry.Iterations.Outcome == "PASSED");
    entry.FailedCount = sum(entry.Iterations.Outcome == "FAILED");
    entry.OutputRunCount = sum(entry.Iterations.OutputRuns, 'omitnan');
    entry.SignalCount = sum(entry.Iterations.Signals, 'omitnan');

    coverageObjects = st_collect_result_coverage_objects(resultObj);
    entry.CoverageObjectCount = numel(coverageObjects);
    rows = st_collect_coverage_summary(resultObj, target, ...
        char(entry.Label), 'IncludeTestDetails', true, ...
        'CoverageObjects', coverageObjects);
    entry.Decision = metric_text(rows, "Decision");
    entry.Execution = metric_text(rows, "Execution");
    entry.IterationCoverageRows = sum(rows.Level == "ITERATION");
    if marker.Enabled
        entry.MarkerSeen = marker_seen(coverageObjects, marker.File);
    end
    entry.Status = "OK";
catch ME
    if is_user_interrupt(ME)
        rethrow(ME);
    end
    entry.Status = "SUMMARY_ERROR";
    entry.Message = error_text(ME);
    entry.Stack = stack_text(ME);
    st_log(cfg, 'ERROR', ...
        'Per-CUT parallel probe result summary failed | Label=%s | %s', ...
        char(entry.Label), getReport(ME, 'extended', 'hyperlinks', 'off'));
end
end


function [T, caseOutcome] = iteration_table(resultObj)
Name = strings(0,1);
Outcome = strings(0,1);
OutputRuns = zeros(0,1);
Signals = zeros(0,1);
caseOutcome = "UNKNOWN";
caseResults = st_collect_test_case_results(resultObj);
for c = 1:numel(caseResults)
    caseOutcome = upper(string(safe_property( ...
        caseResults{c}, 'Outcome', 'UNKNOWN')));
    iterations = safe_iterations(caseResults{c});
    for k = 1:numel(iterations)
        Name(end+1,1) = iteration_name(iterations(k), k); %#ok<AGROW>
        Outcome(end+1,1) = upper(string(safe_property( ...
            iterations(k), 'Outcome', 'UNKNOWN'))); %#ok<AGROW>
        [OutputRuns(end+1,1), Signals(end+1,1)] = ...
            output_counts(iterations(k)); %#ok<AGROW>
    end
end
T = table(Name, Outcome, OutputRuns, Signals);
end


function [runCount, signalCount] = output_counts(iterationResult)
% Expected-value update reads these runs, so a parallel run that drops them
% would break PER_CUT even when every outcome matches.
runCount = NaN;
signalCount = NaN;
try
    outputRuns = getOutputRuns(iterationResult);
    runCount = numel(outputRuns);
    signalCount = 0;
    for r = 1:numel(outputRuns)
        signalCount = signalCount + double(outputRuns(r).SignalCount);
    end
catch
end
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


function seen = marker_seen(coverageObjects, markerFile)
seen = "NO_COVERAGE";
if isempty(coverageObjects)
    return;
end
[~, markerName] = fileparts(char(markerFile));
seen = "NO";
for c = 1:numel(coverageObjects)
    try
        names = filter_list(coverageObjects{c}.filter);
    catch
        seen = "UNREADABLE";
        continue;
    end
    if any(contains(lower(names), lower(markerName)))
        seen = "YES";
        return;
    end
end
end


function verdict = unsaved_verdict(sequential, parallel)
% SEQ is the control. When it does not carry the marker, the Result does
% not expose the filter list and nothing can be said about the workers.
if strlength(sequential.MarkerSeen) == 0
    verdict = "NOT_CHECKED";
elseif sequential.MarkerSeen ~= "YES"
    verdict = "INCONCLUSIVE_SEQ_" + sequential.MarkerSeen;
elseif all([parallel.MarkerSeen] == "YES")
    verdict = "WORKERS_SEE_UNSAVED";
elseif all([parallel.MarkerSeen] == "NO")
    verdict = "WORKERS_READ_DISK";
else
    verdict = "MIXED";
end
end


function found = compare_runs(base, other)
found = strings(0,1);
if base.Outcome ~= other.Outcome
    found(end+1,1) = "CaseOutcome " + base.Outcome + "->" + other.Outcome;
end
if base.Decision ~= other.Decision
    found(end+1,1) = "Decision " + base.Decision + "->" + other.Decision;
end
if base.Execution ~= other.Execution
    found(end+1,1) = "Execution " + base.Execution + "->" + other.Execution;
end
if base.CoverageObjectCount ~= other.CoverageObjectCount
    found(end+1,1) = sprintf('CoverageObjects %d->%d', ...
        base.CoverageObjectCount, other.CoverageObjectCount);
end
if base.IterationCoverageRows ~= other.IterationCoverageRows
    found(end+1,1) = sprintf('IterationCoverageRows %d->%d', ...
        base.IterationCoverageRows, other.IterationCoverageRows);
end

a = base.Iterations;
b = other.Iterations;
missing = setxor(a.Name, b.Name);
for m = 1:numel(missing)
    found(end+1,1) = "Iteration only in one run | " + missing(m); %#ok<AGROW>
end
[~, ia, ib] = intersect(a.Name, b.Name, 'stable');
for j = 1:numel(ia)
    x = a(ia(j),:);
    y = b(ib(j),:);
    if x.Outcome ~= y.Outcome || ~isequaln(x.OutputRuns, y.OutputRuns) || ...
            ~isequaln(x.Signals, y.Signals)
        found(end+1,1) = sprintf( ...
            'Iteration %s | Outcome %s->%s | OutputRuns %g->%g | Signals %g->%g', ...
            x.Name, x.Outcome, y.Outcome, x.OutputRuns, y.OutputRuns, ...
            x.Signals, y.Signals); %#ok<AGROW>
    end
end
end


function [pool, info, cleanup] = ensure_pool(cfg, workers, keepPool)
cleanup = [];
info = struct('Class', "", 'Started', false, 'Workers', 0, 'StartSec', 0);
pool = gcp('nocreate');
if isempty(pool)
    st_log(cfg, 'INFO', ...
        'Per-CUT parallel probe pool start | Profile=Processes | Workers=%d (0=default)', ...
        workers);
    timer = tic;
    if workers > 0
        pool = parpool('Processes', workers);
    else
        pool = parpool('Processes');
    end
    info.Started = true;
    info.StartSec = toc(timer);
    st_log(cfg, 'INFO', ...
        'Per-CUT parallel probe pool start complete | Workers=%d | elapsed=%.1f sec', ...
        pool.NumWorkers, info.StartSec);
    if ~keepPool
        cleanup = onCleanup(@() delete_pool(cfg, pool));
    end
elseif workers > 0 && pool.NumWorkers ~= workers
    st_log(cfg, 'WARN', ...
        'Per-CUT parallel probe uses the open pool | Workers=%d | Requested=%d', ...
        pool.NumWorkers, workers);
end
info.Class = string(class(pool));
info.Workers = pool.NumWorkers;
if isa(pool, 'parallel.ThreadPool')
    st_log(cfg, 'WARN', ...
        ['Per-CUT parallel probe | the open pool is a thread pool; Test ' ...
         'Manager needs a process pool. Run delete(gcp) and try again']);
end
end


function delete_pool(cfg, pool)
st_log(cfg, 'INFO', 'Per-CUT parallel probe pool delete start');
try
    delete(pool);
    st_log(cfg, 'INFO', 'Per-CUT parallel probe pool delete complete');
catch ME
    st_log(cfg, 'WARN', ...
        'Per-CUT parallel probe pool delete failed | %s: %s', ...
        ME.identifier, ME.message);
end
end


function T = probe_workers(cfg, pool, modelName)
% Test Manager may still hand the workers what they need at run time, so a
% miss here explains a failure but is not one by itself.
T = table();
st_log(cfg, 'INFO', ...
    'Per-CUT parallel probe worker check start | Workers=%d', pool.NumWorkers);
try
    future = parfevalOnAll(pool, @(m) [string(which(m)), ...
        string(which('st_config')), string(pwd)], 1, modelName);
    values = fetchOutputs(future);
catch ME
    emit('WORKER', 'Status=ERROR | %s: %s', ME.identifier, ME.message);
    st_log(cfg, 'WARN', ...
        'Per-CUT parallel probe worker check failed | %s: %s', ...
        ME.identifier, ME.message);
    return;
end
clientModel = string(which(modelName));
for w = 1:size(values, 1)
    emit('WORKER', 'Index=%d | Model=%s | SameAsClient=%s | Toolkit=%s | Folder=%s', ...
        w, char(text_or(values(w,1), 'NOT_FOUND')), ...
        yes_no(strcmpi(values(w,1), clientModel)), ...
        yes_no(strlength(values(w,2)) > 0), char(values(w,3)));
end
T = array2table(values, 'VariableNames', {'Model','Toolkit','Folder'});
st_log(cfg, 'INFO', 'Per-CUT parallel probe worker check complete');
end


function report = finish(cfg, report, verdict, detail, totalTimer)
report.Verdict = verdict;
emit('VERDICT', '%s | %s | TotalSec=%.1f', char(verdict), detail, ...
    toc(totalTimer));
level = 'WARN';
if startsWith(verdict, "SAME")
    level = 'INFO';
end
st_log(cfg, level, ...
    'Per-CUT parallel probe complete | Verdict=%s | %s | elapsed=%.1f sec', ...
    char(verdict), detail, toc(totalTimer));
end


function emit_run(entry)
if entry.Status ~= "OK"
    emit('RUN', 'Label=%s | Status=%s | Sec=%.1f | MemAvailGB=%.1f | %s', ...
        char(entry.Label), char(entry.Status), entry.ElapsedSec, ...
        entry.MemAvailGB, char(entry.Message));
    emit('STACK', '%s | %s', char(entry.Label), char(entry.Stack));
    return;
end
emit('RUN', ['Label=%s | Status=OK | Sec=%.1f | Outcome=%s | ' ...
    'Iterations=%d | Passed=%d | Failed=%d | OutputRuns=%g | Signals=%g | ' ...
    'CoverageObjects=%d | Decision=%s | Execution=%s | ' ...
    'IterationCoverageRows=%d | Marker=%s | MemAvailGB=%.1f'], ...
    char(entry.Label), entry.ElapsedSec, char(entry.Outcome), ...
    entry.IterationCount, entry.PassedCount, entry.FailedCount, ...
    entry.OutputRunCount, entry.SignalCount, entry.CoverageObjectCount, ...
    char(entry.Decision), char(entry.Execution), ...
    entry.IterationCoverageRows, char(text_or(entry.MarkerSeen, 'OFF')), ...
    entry.MemAvailGB);
end


function emit(section, formatText, varargin)
text = sprintf(formatText, varargin{:});
text = regexprep(text, '\s*[\r\n]+\s*', ' ');
fprintf('PARALLEL-PROBE-v1 %s | %s\n', section, text);
end


function entry = empty_run(label, parallel)
entry = struct('Label', string(label), 'Parallel', parallel, ...
    'Status', "NOT_RUN", 'ElapsedSec', NaN, 'Outcome', "UNKNOWN", ...
    'IterationCount', 0, 'PassedCount', 0, 'FailedCount', 0, ...
    'OutputRunCount', NaN, 'SignalCount', NaN, ...
    'CoverageObjectCount', 0, 'Decision', "NONE", 'Execution', "NONE", ...
    'IterationCoverageRows', 0, 'MarkerSeen', "", 'MemAvailGB', NaN, ...
    'Iterations', table(), 'Message', "", 'Stack', "");
end


function values = filter_list(value)
% A char path must stay one element; string(charRow(:)) would split it.
if ischar(value)
    values = string(cellstr(value));
else
    values = string(value);
end
values = values(:);
values(ismissing(values)) = "";
values = values(strlength(values) > 0);
end


function value = available_memory_gb()
value = NaN;
try
    [~, systemView] = memory;
    value = systemView.PhysicalMemory.Available / 2^30;
catch
end
end


function report_crash_dumps(cfg, since)
% A worker that dies leaves only "terminated abnormally" on the client. Its
% crash dump says why: a fault in a named module, or memory. A pool writes
% its workers' dumps into the cluster job storage, not tempdir, and keeps
% that job because of them. A worker the OS killed for memory may leave no
% dump at all.
searched = unique([string(tempdir); string(pwd)]);
dumps = strings(0,1);
for f = 1:numel(searched)
    dumps = [dumps; recent_files( ...
        dir(fullfile(searched(f), 'matlab_crash_dump*')), since)]; %#ok<AGROW>
end
storage = job_storage_location();
if strlength(storage) > 0
    searched(end+1,1) = storage;
    listing = dir(fullfile(storage, '**', '*'));
    listing = listing(~[listing.isdir]);
    names = lower(string({listing.name}));
    listing = listing(contains(names, "crash") | endsWith(names, ".dmp"));
    dumps = [dumps; recent_files(listing, since)];
end
dumps = unique(dumps);
for k = 1:numel(dumps)
    [reason, frames] = crash_summary(dumps(k));
    emit('CRASH', 'File=%s | Reason=%s | Top=%s', char(dumps(k)), ...
        char(reason), char(top_frame(frames)));
    % Workers that die together almost always die the same way, so one
    % stack is enough.
    if k == 1
        for j = 1:numel(frames)
            emit('CRASH-STACK', '%s', char(frames(j)));
        end
    end
end
if isempty(dumps)
    emit('CRASH', 'Found=0 | Searched=%s', char(strjoin(searched(:)', '; ')));
end
st_log(cfg, 'WARN', ...
    'Per-CUT parallel probe crash dump scan | Found=%d | Searched=%s', ...
    numel(dumps), char(strjoin(searched(:)', '; ')));
end


function files = recent_files(listing, since)
files = strings(0,1);
for k = 1:numel(listing)
    if listing(k).datenum >= since
        files(end+1,1) = string(fullfile( ...
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



function text = top_frame(frames)
% The first frame below the crash handler, reduced to module+offset and
% symbol. Dumps that agree here died on the same code path; dumps that
% differ died wherever an allocation happened to fail.
text = "-";
if numel(frames) < 2
    return;
end
text = regexprep(frames(2), '^\[\s*\d+\]\s+0x[0-9a-fA-F]+\s+', '');
text = regexprep(text, '^.*\\', '');
end


function [reason, frames] = crash_summary(dumpFile)
reason = "UNREADABLE";
frames = strings(0,1);
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
first = find(startsWith(lines, "Stack Trace", 'IgnoreCase', true), 1);
if isempty(first)
    return;
end
stack = strings(0, 1);
for k = first + 1:min(numel(lines), first + 400)
    if startsWith(lines(k), "[")
        stack(end+1, 1) = lines(k); %#ok<AGROW>
    elseif ~isempty(stack) && strlength(lines(k)) > 0
        break;
    end
end
% On std::terminate the top frames are the crash handler and the C++
% runtime unwinding the exception. The module that threw it, a MathWorks
% library or a MEX/S-Function of the model, is the first frame below them.
handler = ["libmwfl.dll", "mcr.dll", "libmwfoundation_crash_handling.dll", ...
    "ucrtbase.dll", "VCRUNTIME140", "MSVCP140", "KERNELBASE.dll", "ntdll.dll"];
isHandler = contains(stack, handler, 'IgnoreCase', true);
firstOwn = find(~isHandler, 1);
if isempty(firstOwn)
    firstOwn = 1;
end
shown = stack(firstOwn:min(numel(stack), firstOwn + 14));
frames = [string(sprintf('frames=%d | leading handler frames skipped=%d', ...
    numel(stack), firstOwn - 1)); shown];
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


function name = iteration_name(iterationResult, index)
name = string(safe_property(iterationResult, 'Name', ''));
if strlength(name) == 0
    name = "Iteration " + string(index);
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


function text = text_or(value, fallback)
text = string(value);
if isempty(text) || strlength(text) == 0
    text = string(fallback);
end
end


function text = yes_no(value)
if value
    text = 'YES';
else
    text = 'NO';
end
end
