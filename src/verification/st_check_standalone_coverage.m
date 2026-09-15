function [code, summary, details] = st_check_standalone_coverage(varargin)
%ST_CHECK_STANDALONE_COVERAGE Read-only one-screen pipeline verification.
%
%   [code, summary, details] = st_check_standalone_coverage()
%   returns 1111111111 only when every completed contract check passes.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'OutputRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'PipelineId', 'LATEST', ...
    @(x) ischar(x) || isstring(x));
parse(p, varargin{:});

outputRoot = strtrim(char(string(p.Results.OutputRoot)));
if isempty(outputRoot)
    cfg = st_require_runtime_target('LoadModel', false);
    outputRoot = cfg.StandaloneCoverageRootDir;
else
    cfg = st_config();
end
% Keep the checker itself within its one-screen contract. WARN/ERROR still
% use the project logger; routine INFO checkpoints remain non-printing.
logCfg = cfg;
logCfg.VerboseLogging = false;
timerValue = tic;
st_log(logCfg, 'INFO', ...
    'Standalone coverage checker start | Root=%s | PipelineId=%s', ...
    outputRoot, char(string(p.Results.PipelineId)));
try
    [manifest, manifestPath] = st_load_standalone_pipeline_manifest( ...
        outputRoot, p.Results.PipelineId);
catch ME
    code = '0000000000';
    summary = struct('Status', 'FAIL', 'PipelineId', '', ...
        'OutputRoot', outputRoot, 'Message', ME.message);
    details = empty_details();
    lines = ["STANDALONE-CHECK-v1 BEGIN"; ...
        "PIPE status=FAIL targets=0"; ...
        "CODE 0000000000 FAIL"; ...
        "ERROR " + string(ME.identifier) + " " + compact(ME.message, 120); ...
        "ROOT " + string(outputRoot); ...
        "STANDALONE-CHECK-v1 END"];
    fprintf('%s\n', char(strjoin(lines, newline)));
    st_log(logCfg, 'ERROR', ...
        'Standalone coverage checker failed | %s: %s', ...
        ME.identifier, ME.message);
    return;
end

pipelineRoot = fileparts(manifestPath);
if isfield(manifest, 'Targets') && isstruct(manifest.Targets)
    targets = manifest.Targets;
else
    targets = struct([]);
end
n = numel(targets);
events = read_events(field_text(manifest, 'ExecutionLog'));
packageReady = safe_contract(@() action_complete(manifest, 'PACKAGE'));
summaryReady = safe_contract(@() action_complete(manifest, 'SUMMARY'));

checks = repmat("1", n, 10);
messages = strings(n,1);
globalPass = true(1,10);
% Every target directory lives under pipelineRoot, and the unzipped Coverage
% report puts hundreds of companion assets in each one. Walking that tree
% once per forbidden pattern per target dominated the check; walk it once.
forbiddenPaths = forbidden_paths(pipelineRoot);

globalPass(1) = safe_contract(@() ...
    manifest_contract(manifest) && unique_functions());
checks(:,1) = bit(globalPass(1));
globalPass(9) = safe_contract(@() source_contract(manifest));
checks(:,9) = bit(globalPass(9));
for i = 1:n
    item = targets(i);
    checks(i,2) = bit(safe_contract(@() name_contract(item)));
    checks(i,3) = bit(safe_contract(@() readback_contract(item)));
    checks(i,4) = bit(safe_contract(@() ...
        lifecycle_contract(item, events, 'RUN')));
    % Result filtering and coverage metrics both happen after a Test Case
    % produces a result. An excepted target never got there, so these are
    % not applicable rather than failed; the exception is already reported
    % through its EXCEPT status and PackageFailure message.
    if target_excepted(item)
        checks(i,5) = "-";
    else
        checks(i,5) = bit(safe_contract(@() filter_contract(item, events)));
    end
    if packageReady
        checks(i,6) = bit(safe_contract(@() ...
            package_contract(item, forbiddenPaths)));
        if target_excepted(item)
            checks(i,7) = "-";
        else
            checks(i,7) = bit(safe_contract(@() metric_contract(item)));
        end
    else
        checks(i,6:7) = "-";
    end
    checks(i,10) = bit(safe_contract(@() ...
        cleanup_contract(item, events, targets)));
end
if packageReady && (~isfile(field_text(manifest, 'TestManagerFile')) || ...
        ~signature_matches(field_text(manifest, 'TestManagerFile'), ...
        field_text(manifest, 'TestManagerSHA256')) || ...
        ~isfile(field_text(manifest, 'TestManagerLauncher')) || ...
        ~signature_matches(field_text(manifest, 'TestManagerLauncher'), ...
        field_text(manifest, 'TestManagerLauncherSHA256')) || ...
        ~isempty(forbiddenPaths))
    checks(:,6) = "0";
end
countsOK = true;
try
    counts = artifact_counts(pipelineRoot, manifest, forbiddenPaths);
catch
    counts = empty_artifact_counts();
    countsOK = false;
end
if packageReady && (~countsOK || ...
        ~safe_contract(@() artifact_count_contract(counts, manifest)))
    checks(:,6) = "0";
end
if packageReady && isfield(manifest,'PackageInventory') && ...
        ~safe_contract(@() isequal(st_package_inventory(manifest),manifest.PackageInventory(:)))
    checks(:,6) = "0";
end
if ~safe_contract(@() pipeline_cleanup_contract(manifest))
    checks(:,10) = "0";
end

for b = [2:7 9:10]
    applicable = checks(:,b) ~= "-";
    if any(applicable)
        globalPass(b) = all(checks(applicable,b) == "1");
    end
end
summaryInfo = summary_info(manifest, n, summaryReady);
if summaryReady
    globalPass(8) = strcmp(summaryInfo.Status, 'OK');
    checks(:,8) = bit(globalPass(8));
else
    checks(:,8) = "-";
end
for i = 1:n
    failed = find(checks(i,:) == "0");
    if ~isempty(failed)
        messages(i) = "Failed bits: " + strjoin(bit_labels(failed), ',');
        packageFailure = package_failure_text(targets(i));
        if strlength(packageFailure) > 0
            messages(i) = messages(i) + " | " + packageFailure;
        end
    end
end

if n == 0
    bitValue = repmat("0", 1, 10);
else
    for b = 1:10
        if all(checks(:,b) == "-")
            bitValue(b) = "-"; %#ok<AGROW>
        else
            bitValue(b) = bit(globalPass(b)); %#ok<AGROW>
        end
    end
end
code = char(join(bitValue, ''));
exceptedCount = excepted_count(manifest);
if strcmp(code, '1111111111') && exceptedCount == 0
    overall = 'PASS';
elseif strcmp(code, '1111111111')
    % Every contract holds, but a CUT produced no coverage. Saying PASS
    % here would hide that gap behind a green code.
    overall = 'PARTIAL';
elseif any(bitValue == "0")
    overall = 'FAIL';
else
    overall = 'PARTIAL';
end

No = zeros(n,1);
CUTName = strings(n,1);
Bits = strings(n,1);
Status = strings(n,1);
for i = 1:n
    No(i) = field_number(targets(i), 'No', i);
    CUTName(i) = string(field_text(targets(i), 'CUTName'));
    Bits(i) = join(checks(i,:), '');
    if any(checks(i,:) == "0")
        Status(i) = "FAIL";
    elseif target_excepted(targets(i))
        Status(i) = "EXCEPT";
    elseif any(checks(i,:) == "-")
        Status(i) = "PARTIAL";
    else
        Status(i) = "PASS";
    end
end
B1 = checks(:,1); B2 = checks(:,2); B3 = checks(:,3);
B4 = checks(:,4); B5 = checks(:,5); B6 = checks(:,6);
B7 = checks(:,7); B8 = checks(:,8); B9 = checks(:,9);
B10 = checks(:,10);
details = table(No, CUTName, Bits, B1, B2, B3, B4, B5, B6, B7, ...
    B8, B9, B10, Status, messages, 'VariableNames', ...
    {'No','CUTName','Bits','B1','B2','B3','B4','B5','B6','B7', ...
    'B8','B9','B10','Status','Message'});

summary = struct( ...
    'Status', overall, 'Code', code, ...
    'PipelineId', field_text(manifest, 'PipelineId'), ...
    'Action', field_text(manifest, 'Action'), ...
    'TargetCount', n, 'PassedTargetCount', sum(Status == "PASS"), ...
    'FailedTargetCount', sum(Status == "FAIL"), ...
    'PartialTargetCount', sum(Status == "PARTIAL"), ...
    'ExceptedTargetCount', sum(Status == "EXCEPT"), ...
    'Bits', {cellstr(bitValue)}, 'Files', counts, ...
    'Checks', check_summary(checks, bitValue), ...
    'CoverageSummary', summaryInfo, 'PipelineRoot', pipelineRoot);

lines = render_lines(manifest, code, overall, bitValue, counts, ...
    summaryInfo, details, pipelineRoot);
fprintf('%s\n', char(strjoin(lines, newline)));
if strcmp(overall, 'FAIL')
    st_log(logCfg, 'WARN', ...
        'Standalone coverage checker complete | Code=%s | elapsed=%.3f sec', ...
        code, toc(timerValue));
else
    st_log(logCfg, 'INFO', ...
        'Standalone coverage checker complete | Code=%s | elapsed=%.3f sec', ...
        code, toc(timerValue));
end
end

function tf = manifest_contract(manifest)
tf = ismember(double(manifest.Version), [2 3]) && isfield(manifest, 'Actions') && ...
    isfield(manifest.Actions, 'EXECUTE') && ...
    action_complete(manifest, 'EXECUTE') && ...
    isfield(manifest, 'SaveTestResult') && ...
    isfield(manifest, 'ResultExportCount') && ...
    isfield(manifest, 'ResultImportCount') && ...
    isfield(manifest, 'ResultFile') && ...
    isfield(manifest, 'ResultSHA256') && ...
    isfield(manifest, 'CanResumePackage') && ...
    isfield(manifest, 'Action') && ...
    ismember(upper(string(manifest.Action)), ...
        ["EXECUTE","PACKAGE","SUMMARY","ALL"]) && ...
    ~isempty(manifest.Targets) && action_status_contract(manifest);
if ~tf, return; end
if isfield(manifest,'SourcePipelineId')
    tf = st_regeneration_contract(manifest);
    return;
end
if logical(manifest.SaveTestResult)
    tf = isfile(field_text(manifest, 'ResultFile')) && ...
        signature_matches(manifest.ResultFile, manifest.ResultSHA256) && ...
        double(manifest.ResultExportCount) == 1 && ...
        logical(manifest.CanResumePackage);
else
    tf = isempty_path(manifest, 'ResultFile') && ...
        isempty_path(manifest, 'ResultSHA256') && ...
        double(manifest.ResultExportCount) == 0 && ...
        ~logical(manifest.CanResumePackage);
end
if strcmpi(field_text(manifest, 'Action'), 'ALL')
    tf = tf && double(manifest.ResultImportCount) == 0;
elseif action_complete(manifest, 'PACKAGE')
    if ~isfield(manifest, 'PackageResultSource')
        tf = false;
    elseif strcmpi(field_text(manifest, 'PackageResultSource'), 'LIVE')
        tf = tf && double(manifest.ResultImportCount) == 0;
    elseif strcmpi(field_text(manifest, 'PackageResultSource'), 'IMPORTED')
        tf = tf && logical(manifest.SaveTestResult) && ...
            double(manifest.ResultImportCount) == 1;
    else
        tf = false;
    end
end
end

function tf = action_status_contract(manifest)
action = upper(string(manifest.Action));
status = upper(string(field_text(manifest, 'Status')));
switch action
    case "EXECUTE"
        tf = action_complete(manifest, 'EXECUTE') && status == "PARTIAL";
    case "PACKAGE"
        tf = action_complete(manifest, 'EXECUTE') && ...
            action_complete(manifest, 'PACKAGE') && status == "PARTIAL";
    case {"SUMMARY","ALL"}
        tf = action_ok_or_excepted(manifest, 'EXECUTE') && ...
            action_ok_or_excepted(manifest, 'PACKAGE') && ...
            action_ok_or_excepted(manifest, 'SUMMARY') && ...
            (status == "OK" || ...
                (status == "PARTIAL" && excepted_only(manifest)));
    otherwise
        tf = false;
end
end

function tf = action_ok(manifest, name)
tf = isfield(manifest, 'Actions') && isfield(manifest.Actions, name) && ...
    strcmpi(field_text(manifest.Actions.(name), 'Status'), 'OK');
end

function tf = unique_functions()
names = {'st_run_standalone_coverage_pipeline', ...
    'st_package_standalone_coverage_artifacts', ...
    'st_collect_final_cut_coverage_metrics', ...
    'st_check_standalone_coverage'};
tf = true;
for i = 1:numel(names)
    tf = tf && which_count(names{i}) == 1;
end
end

function count = which_count(name)
paths = which(name, '-all');
if isempty(paths)
    count = 0;
elseif iscell(paths) || isstring(paths)
    count = numel(paths);
else
    count = size(paths,1);
end
end

function tf = name_contract(item)
[~, stem] = fileparts(field_text(item, 'StandaloneModelFile'));
tf = same_text(item.HarnessName, item.StandaloneModel) && ...
    same_text(item.HarnessName, stem) && ...
    ~startsWith(string(item.StandaloneModel), "st_h_");
end

function tf = readback_contract(item)
tf = status_ok(item, 'SUTReadbackStatus') && ...
    status_ok(item, 'IterationIntegrityStatus') && ...
    status_ok_or_not_required(item, 'InputReadbackStatus') && ...
    status_ok(item, 'AssessmentReadbackStatus') && ...
    strcmp(field_text(item, 'ExpectedUpdateMode'), 'OFF');
end

function tf = lifecycle_contract(item, events, kind)
tf = double(item.RunCount) == 1 && ~logical(item.RerunPerformed);
if strcmp(kind, 'RUN')
    tf = tf && event_count(events, item.Order, 'RUN_START') == 1 && ...
        event_count(events, item.Order, 'RUN_DONE') == 1 && ...
        event_position(events, item.Order, 'RUN_START') < ...
        event_position(events, item.Order, 'RUN_DONE');
end
end

function tf = filter_contract(item, events)
tf = status_ok(item, 'CVFGenerationStatus') && ...
    double(item.CVFRuleCount) > 0 && ...
    isfile(field_text(item, 'ExecutionCVFPath')) && ...
    signature_matches(item.ExecutionCVFPath, item.CVFSHA256) && ...
    double(item.ResultFilterAttachCount) == 1 && ...
    status_ok(item, 'ResultFilterStatus') && ...
    event_count(events, item.Order, 'CVF_GENERATE') == 1 && ...
    event_count(events, item.Order, 'RESULT_FILTER_ATTACH') == 1 && ...
    event_position(events, item.Order, 'RUN_DONE') < ...
        event_position(events, item.Order, 'CVF_GENERATE') && ...
    event_position(events, item.Order, 'CVF_GENERATE') < ...
        event_position(events, item.Order, 'RESULT_FILTER_ATTACH');
end

function tf = package_contract(item, forbiddenPaths)
% A target whose Test Case execution raised an exception keeps only the
% standalone Harness and its input so the failure stays reproducible. It
% never produced coverage, so demanding a CVT or HTML here would report a
% defect that does not exist.
if target_excepted(item)
    tf = excepted_package_contract(item, forbiddenPaths);
    return;
end
[~, packagedStem] = fileparts(field_text(item, ...
    'PackagedStandaloneModel'));
[~, cvfName, cvfExtension] = fileparts(field_text(item, 'PackagedCVF'));
[~, cvtName, cvtExtension] = fileparts(field_text(item, 'CoverageResult'));
[reportDirectory, reportName, reportExtension] = fileparts( ...
    field_text(item, 'ReportHTML'));
artifactStem = st_artifact_stem(field_text(item, 'TestCaseName'));
if isempty(field_text(item, 'SignalEditorInput'))
    inputOK = isempty(field_text(item, 'PackagedInput')) && ...
        status_ok_or_not_required(item, 'PackagedInputReadbackStatus');
else
    inputOK = isfile(field_text(item, 'PackagedInput')) && ...
        signature_matches(item.PackagedInput, item.PackagedInputSHA256) && ...
        status_ok(item, 'PackagedInputReadbackStatus');
end
tf = status_ok(item, 'PackageStatus') && ...
    isfile(field_text(item, 'PackagedStandaloneModel')) && ...
    same_text(item.HarnessName, packagedStem) && ...
    inputOK && ...
    isfile(field_text(item, 'PackagedCVF')) && ...
    isfile(field_text(item, 'CoverageResult')) && ...
    isfile(field_text(item, 'ReportHTML')) && ...
    signature_matches(item.PackagedStandaloneModel, ...
        item.PackagedStandaloneModelSHA256) && ...
    signature_matches(item.PackagedCVF, item.PackagedCVFSHA256) && ...
    signature_matches(item.CoverageResult, item.CoverageResultSHA256) && ...
    strcmpi([cvfName cvfExtension], [artifactStem '.cvf']) && ...
    strcmpi([cvtName cvtExtension], [artifactStem '.cvt']) && ...
    strcmpi([reportName reportExtension], [artifactStem '.html']) && ...
    same_text(canonical(reportDirectory), ...
        canonical(field_text(item, 'TestReport'))) && ...
    forbidden_under(forbiddenPaths, item.OutputDirectory) == 0;
end

function tf = metric_contract(item)
tf = status_ok(item, 'PackageStatus') && ...
    isfield(item, 'MetricSource') && ~isempty(item.MetricSource) && ...
    strcmp(field_text(item, 'MetricSourceStatus'), 'PROVISIONAL') && ...
    metric_scalar_contract(item, 'Decision') && ...
    metric_scalar_contract(item, 'Execution');
end

function tf = metric_scalar_contract(item, name)
coveredName = [name 'Covered'];
totalName = [name 'Total'];
percentageName = [name 'Percentage'];
textName = [name 'PercentageText'];
statusName = [name 'MetricStatus'];
required = {coveredName,totalName,percentageName,textName,statusName};
tf = all(isfield(item, required)) && status_ok(item, statusName);
if ~tf, return; end
covered = double(item.(coveredName));
total = double(item.(totalName));
percentage = double(item.(percentageName));
text = string(item.(textName));
tf = isscalar(covered) && isscalar(total) && ...
    isfinite(covered) && isfinite(total) && ...
    covered >= 0 && total >= 0 && covered <= total;
if ~tf, return; end
if total == 0
    tf = (isempty(percentage) || ...
        (isscalar(percentage) && isnan(percentage))) && text == "N/A";
else
    expected = 100 * covered / total;
    tf = isscalar(percentage) && isfinite(percentage) && ...
        percentage >= 0 && percentage <= 100 && ...
        abs(percentage - expected) <= 1e-9 && ...
        strlength(text) > 0 && text ~= "N/A";
end
end

function tf = safe_contract(callback)
try
    tf = callback();
    tf = islogical(tf) && isscalar(tf) && tf;
catch
    tf = false;
end
end

function tf = source_contract(manifest)
if ~isfield(manifest, 'SourceBefore') || ...
        ~isfield(manifest, 'SourceAfter') || ...
        ~isstruct(manifest.SourceBefore) || ...
        ~isstruct(manifest.SourceAfter)
    tf = false;
    return;
end
before = manifest.SourceBefore;
after = manifest.SourceAfter;
names = {'Model','TestFile','ManagementExcel'};
required = [names {'ModelDirty','TestFileDirty','HarnessInventory', ...
    'Harnesses','Inputs'}];
if ~all(isfield(before, required)) || ~all(isfield(after, required))
    tf = false;
    return;
end
tf = true;
for i = 1:numel(names)
    name = names{i};
    tf = tf && strcmpi(before.(name).SHA256, after.(name).SHA256) && ...
        isfield(after.(name), 'Path') && ...
        signature_matches(after.(name).Path, after.(name).SHA256);
end
tf = tf && before.ModelDirty == after.ModelDirty && ...
    before.TestFileDirty == after.TestFileDirty && ...
    isequal(string(before.HarnessInventory), ...
        string(after.HarnessInventory)) && ...
    isequal(harness_keys(before.Harnesses), ...
        harness_keys(after.Harnesses)) && ...
    harness_files_match(after.Harnesses) && ...
    isequal(input_keys(before.Inputs), input_keys(after.Inputs)) && ...
    input_files_match(after.Inputs);
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

function tf = harness_files_match(items)
tf = true;
for i = 1:numel(items)
    tf = tf && signature_matches(items(i).Path, items(i).SHA256);
end
end

function values = input_keys(items)
values = strings(numel(items),1);
for i = 1:numel(items)
    values(i) = string(items(i).No) + "|" + ...
        string(items(i).Path) + "|" + string(items(i).SHA256);
end
values = sort(values);
end

function tf = input_files_match(items)
tf = true;
for i = 1:numel(items)
    tf = tf && signature_matches(items(i).Path, items(i).SHA256);
end
end

function tf = cleanup_contract(item, events, targets)
directories = string({targets.OutputDirectory});
nonempty = directories(strlength(directories) > 0);
if ispc, nonempty = lower(nonempty); end
% Session hygiene must hold however the target ended: the execution model
% is closed and the MATLAB path restored on the exception path too. Only
% the filter ordering depends on a run that reached a result.
tf = status_ok(item, 'ModelCleanupStatus') && ...
    status_ok(item, 'PathCleanupStatus') && ...
    event_count(events, item.Order, 'MODEL_CLEANUP') == 1 && ...
    event_count(events, item.Order, 'PATH_CLEANUP') == 1 && ...
    event_position(events, item.Order, 'MODEL_CLEANUP') < ...
        event_position(events, item.Order, 'PATH_CLEANUP') && ...
    numel(unique(nonempty)) == numel(nonempty) && ...
    artifact_paths_are_isolated(item);
if ~tf, return; end
if target_excepted(item)
    tf = status_ok_or_not_required(item, 'FilterRestoreStatus');
    return;
end
tf = status_ok(item, 'FilterRestoreStatus') && ...
    event_count(events, item.Order, 'FILTER_RESTORE') == 1 && ...
    event_position(events, item.Order, 'RESULT_FILTER_ATTACH') < ...
        event_position(events, item.Order, 'FILTER_RESTORE') && ...
    event_position(events, item.Order, 'FILTER_RESTORE') < ...
        event_position(events, item.Order, 'MODEL_CLEANUP');
end

function tf = artifact_paths_are_isolated(item)
directory = field_text(item, 'OutputDirectory');
if isempty(directory)
    tf = true;
    return;
end
names = {'PackagedStandaloneModel','PackagedCVF', ...
    'CoverageResult','ReportHTML'};
if ~isempty(field_text(item, 'SignalEditorInput'))
    names{end+1} = 'PackagedInput'; %#ok<AGROW>
end
tf = true;
for i = 1:numel(names)
    path = field_text(item, names{i});
    if isempty(path), continue; end
    tf = tf && is_under_directory(path, directory);
end
end

function tf = is_under_directory(path, directory)
candidate = canonical(path);
root = canonical_prefix(directory);
tf = startsWith(lower(candidate), lower(root));
end

function tf = pipeline_cleanup_contract(manifest)
tf = isfield(manifest, 'BundleSessionCleanup') && ...
    isstruct(manifest.BundleSessionCleanup) && ...
    status_ok(manifest.BundleSessionCleanup, 'TestFileStatus') && ...
    status_ok(manifest.BundleSessionCleanup, 'TopModelStatus') && ...
    status_ok(manifest, 'RunnerEnvironmentCleanupStatus');
end

function events = read_events(path)
events = table(zeros(0,1), strings(0,1), ...
    'VariableNames', {'Order','Event'});
if isempty(path) || ~isfile(path), return; end
lines = splitlines(string(fileread(path)));
for i = 1:numel(lines)
    if strlength(strtrim(lines(i))) == 0, continue; end
    try
        entry = jsondecode(char(lines(i)));
        events(end+1,:) = {double(entry.Order), string(entry.Event)}; %#ok<AGROW>
    catch
        % A malformed event makes required lifecycle counts fail closed.
    end
end
end

function value = event_count(events, order, name)
value = sum(events.Order == double(order) & events.Event == string(name));
end

function value = event_position(events, order, name)
value = find(events.Order == double(order) & ...
    events.Event == string(name), 1);
if isempty(value), value = Inf; end
end

function counts = artifact_counts(root, manifest, forbiddenPaths)
counts = struct( ...
    'Model', target_root_count(manifest, '*.slx'), ...
    'Input', target_root_count(manifest, '*.mat'), ...
    'CVF', target_root_count(manifest, '*.cvf'), ...
    'CVT', target_root_count(manifest, '*.cvt'), ...
    'HTML', report_html_count(manifest), ...
    'Result', final_count(root, '*.mldatx') - ...
        double(isfile(field_text(manifest, 'TestManagerFile'))), ...
    'Forbidden', numel(forbiddenPaths));
end

function counts = empty_artifact_counts()
counts = struct('Model', 0, 'Input', 0, 'CVF', 0, 'CVT', 0, ...
    'HTML', 0, 'Result', 0, 'Forbidden', 0);
end

function count = target_root_count(manifest, pattern)
count = 0;
for i = 1:numel(manifest.Targets)
    directory = field_text(manifest.Targets(i), 'OutputDirectory');
    if ~isempty(directory) && isfolder(directory)
        items = dir(fullfile(directory, pattern));
        count = count + sum(~[items.isdir]);
    end
end
end

function tf = artifact_count_contract(counts, manifest)
targets = manifest.Targets;
expectedInputs = 0;
for i = 1:numel(targets)
    expectedInputs = expectedInputs + ...
        ~isempty(field_text(targets(i), 'SignalEditorInput'));
end
expectedResults = double(field_logical(manifest, 'SaveTestResult'));
if isfield(manifest,'SourcePipelineId'), expectedResults = 0; end
% The Harness and input are preserved for every target, but only targets
% that actually ran produce a CVF, CVT and report.
expectedCoverage = numel(targets) - excepted_count(manifest);
tf = counts.Model == numel(targets) && ...
    counts.Input == expectedInputs && ...
    counts.CVF == expectedCoverage && ...
    counts.CVT == expectedCoverage && ...
    counts.HTML == expectedCoverage && ...
    counts.Result == expectedResults && counts.Forbidden == 0;
end

function count = report_html_count(manifest)
count = 0;
for i = 1:numel(manifest.Targets)
    count = count + isfile(field_text(manifest.Targets(i), 'ReportHTML'));
end
end

function count = final_count(root, pattern)
items = dir(fullfile(root, '**', pattern));
count = 0;
work = canonical_prefix(fullfile(root, '.work'));
for i = 1:numel(items)
    path = canonical(fullfile(items(i).folder, items(i).name));
    if ~startsWith(lower(path), lower(work)), count = count + 1; end
end
end

function paths = forbidden_paths(root)
%FORBIDDEN_PATHS Collect every forbidden artifact in one recursive listing.
paths = strings(0,1);
if isempty(root) || ~isfolder(root), return; end
listing = dir(fullfile(root, '**', '*'));
if isempty(listing), return; end
names = string({listing.name}');
folders = string({listing.folder}');
named = ismember(lower(names), ...
    ["filteredresults.mldatx","coverage-metrics.mat","testsummary.xlsx"]);
suffixed = endsWith(names, ".pdf", 'IgnoreCase', true) | ...
    endsWith(names, "_coverage.html", 'IgnoreCase', true);
keep = named | suffixed;
paths = folders(keep) + string(filesep) + names(keep);
end

function count = forbidden_under(paths, root)
% A missing or unreadable directory stays 0 here, as the per-pattern walk
% did. The root-level check still zeroes the bit for every target when the
% pipeline holds any forbidden artifact.
count = 0;
root = char(string(root));
if isempty(paths) || isempty(root), return; end
try
    prefix = lower(canonical_prefix(root));
catch
    return;
end
count = sum(startsWith(lower(paths), string(prefix)));
end

function tf = excepted_package_contract(item, forbiddenPaths)
[~, packagedStem] = fileparts(field_text(item, ...
    'PackagedStandaloneModel'));
if isempty(field_text(item, 'SignalEditorInput'))
    inputOK = isempty(field_text(item, 'PackagedInput'));
else
    inputOK = isfile(field_text(item, 'PackagedInput')) && ...
        signature_matches(item.PackagedInput, item.PackagedInputSHA256);
end
tf = isfile(field_text(item, 'PackagedStandaloneModel')) && ...
    same_text(item.HarnessName, packagedStem) && ...
    signature_matches(item.PackagedStandaloneModel, ...
        item.PackagedStandaloneModelSHA256) && ...
    inputOK && ...
    ~isfile(field_text(item, 'PackagedCVF')) && ...
    ~isfile(field_text(item, 'CoverageResult')) && ...
    ~isfile(field_text(item, 'ReportHTML')) && ...
    forbidden_under(forbiddenPaths, item.OutputDirectory) == 0;
end

function tf = target_excepted(item)
tf = strcmpi(field_text(item, 'ExecutionStatus'), 'EXCEPT');
end

function count = excepted_count(manifest)
count = 0;
if ~isfield(manifest, 'Targets') || isempty(manifest.Targets), return; end
for i = 1:numel(manifest.Targets)
    count = count + target_excepted(manifest.Targets(i));
end
end

function tf = excepted_only(manifest)
% WARN is acceptable only when every target that is not PASS raised an
% execution exception. An unexplained FAIL, WARN or SKIP still breaks the
% contract, so a real packaging defect cannot hide behind this allowance.
tf = false;
if ~isfield(manifest, 'Targets') || isempty(manifest.Targets), return; end
targets = manifest.Targets;
anyExcepted = false;
for i = 1:numel(targets)
    status = upper(string(field_text(targets(i), 'ExecutionStatus')));
    if status == "EXCEPT"
        anyExcepted = true;
    elseif status ~= "PASS"
        return;
    end
end
tf = anyExcepted;
end

function tf = action_ok_or_excepted(manifest, name)
tf = action_ok(manifest, name);
if tf, return; end
tf = isfield(manifest, 'Actions') && isfield(manifest.Actions, name) && ...
    strcmpi(field_text(manifest.Actions.(name), 'Status'), 'WARN') && ...
    excepted_only(manifest);
end

function info = summary_info(manifest, count, ready)
info = struct('Rows', 0, 'Columns', 0, 'Status', 'NOT_RUN');
if ~ready, return; end
path = field_text(manifest, 'CoverageSummary');
if ~isfile(path) || ~signature_matches(path, ...
        field_text(manifest, 'CoverageSummarySHA256'))
    info.Status = 'FAIL';
    return;
end
try
    value = readtable(path, ...
        'Sheet', 'CoverageSummary', 'VariableNamingRule', 'preserve');
    info.Rows = height(value);
    info.Columns = width(value);
    expected = {'NUM','CUT_NAME','CUT_PATH','Test Case Name', ...
        'Harness Name','Decision Executed','Decision Total','Decision (%)', ...
        'Execution Executed','Execution Total','Execution (%)'};
    if info.Rows == count && ...
            isequal(value.Properties.VariableNames, expected)
        info.Status = 'OK';
    else
        info.Status = 'FAIL';
    end
catch
    info.Status = 'FAIL';
end
end

function value = check_summary(checks, bitValue)
value = struct();
for i = 1:10
    name = sprintf('B%d', i);
    value.(name) = struct( ...
        'Status', char(bitValue(i)), ...
        'PassedTargetCount', sum(checks(:,i) == "1"), ...
        'FailedTargetCount', sum(checks(:,i) == "0"), ...
        'NotApplicableTargetCount', sum(checks(:,i) == "-"));
end
end

function lines = render_lines(manifest, code, overall, bits, counts, ...
        summary, details, root)
labels = ['M','N','S','R','F','P','C','X','O','I'];
parts = strings(1,10);
for i = 1:10, parts(i) = string(labels(i)) + "=" + bits(i); end
lines = ["STANDALONE-CHECK-v1 BEGIN"; ...
    "PIPE id=" + string(field_text(manifest, 'PipelineId')) + ...
        " action=" + string(field_text(manifest, 'Action')) + ...
        " status=" + string(overall) + ...
        " targets=" + height(details) + ...
        " except=" + sum(details.Status == "EXCEPT"); ...
    "CODE " + string(code) + " " + string(overall); ...
    "BITS " + join(parts, ' '); ...
    sprintf('FILES model=%d input=%d cvf=%d cvt=%d html=%d result=%d forbidden=%d', ...
        counts.Model, counts.Input, counts.CVF, counts.CVT, ...
        counts.HTML, counts.Result, counts.Forbidden); ...
    sprintf('SUMMARY rows=%d columns=%d status=%s', ...
        summary.Rows, summary.Columns, summary.Status)];
order = [(find(details.Status == "FAIL")); ...
    (find(details.Status == "EXCEPT")); ...
    (find(details.Status == "PARTIAL")); (find(details.Status == "PASS"))];
shown = min(10, numel(order));
for j = 1:shown
    i = order(j);
    lines(end+1,1) = sprintf('T%03d %s | %s | %s', ...
        round(details.No(i)), compact(details.CUTName(i), 34), ...
        format_target_bits(details.Bits(i)), ...
        char(details.Status(i))); %#ok<AGROW>
end
if numel(order) > shown
    lines(end+1,1) = sprintf( ...
        '... %d additional targets; inspect details', numel(order)-shown); %#ok<AGROW>
end
lines(end+1,1) = "ROOT " + string(root);
lines(end+1,1) = "STANDALONE-CHECK-v1 END";
end

function value = format_target_bits(raw)
labels = ['M','N','S','R','F','P','C','X','O','I'];
chars = char(raw);
parts = strings(1,9);
for i = 2:10
    parts(i-1) = string(labels(i)) + string(chars(i));
end
value = char(join(parts, ' '));
end

function tf = action_complete(manifest, name)
tf = isfield(manifest, 'Actions') && isfield(manifest.Actions, name) && ...
    ismember(upper(string(field_text(manifest.Actions.(name), 'Status'))), ...
        ["OK","WARN"]);
end

function tf = status_ok(item, name)
tf = isfield(item, name) && strcmpi(field_text(item, name), 'OK');
end

function tf = status_ok_or_not_required(item, name)
tf = isfield(item, name) && ...
    ismember(upper(string(field_text(item, name))), ["OK","NOT_REQUIRED"]);
end

function tf = signature_matches(path, expected)
tf = ~isempty(path) && isfile(path);
if ~tf, return; end
try
    tf = strcmpi(st_file_signature(path).SHA256, char(string(expected)));
catch
    tf = false;
end
end

function tf = isempty_path(item, name)
tf = ~isfield(item, name) || isempty(char(string(item.(name))));
end

function tf = same_text(left, right)
if ispc
    tf = strcmpi(char(string(left)), char(string(right)));
else
    tf = strcmp(char(string(left)), char(string(right)));
end
end

function value = field_text(item, name)
value = '';
if isstruct(item) && isfield(item, name) && ~isempty(item.(name))
    value = char(string(item.(name)));
end
end

function value = package_failure_text(item)
value = "";
if ~isstruct(item) || ~isfield(item, 'PackageFailure') || ...
        ~isstruct(item.PackageFailure)
    return;
end
failure = item.PackageFailure;
identifier = string(field_text(failure, 'Identifier'));
message = string(field_text(failure, 'Message'));
if strlength(identifier) == 0 && strlength(message) == 0
    return;
end
value = identifier + ": " + string(compact(message, 180));
if ~isfield(failure, 'Stack') || isempty(failure.Stack) || ...
        ~isstruct(failure.Stack)
    return;
end
frame = failure.Stack(1);
file = string(field_text(frame, 'File'));
line = field_number(frame, 'Line', 0);
if strlength(file) > 0 && line > 0
    value = value + " @ " + file + ":" + string(line);
end
end

function value = field_logical(item, name)
value = false;
if isstruct(item) && isfield(item, name) && ~isempty(item.(name))
    value = logical(item.(name));
end
end

function value = field_number(item, name, defaultValue)
value = defaultValue;
if isstruct(item) && isfield(item, name) && ...
        isnumeric(item.(name)) && isscalar(item.(name))
    value = double(item.(name));
end
end

function value = bit(tf)
if tf, value = "1"; else, value = "0"; end
end

function values = bit_labels(indices)
labels = ["B1","B2","B3","B4","B5","B6","B7","B8","B9","B10"];
values = labels(indices);
end

function value = canonical(path)
value = char(java.io.File(char(path)).getCanonicalPath());
end

function value = canonical_prefix(path)
value = [canonical(path) filesep];
end

function value = compact(raw, limit)
value = char(regexprep(char(string(raw)), '\s+', ' '));
if strlength(string(value)) > limit
    value = [value(1:max(1,limit-3)) '...'];
end
end

function value = empty_details()
value = table(zeros(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'No','CUTName','Bits','B1','B2','B3','B4','B5', ...
    'B6','B7','B8','B9','B10','Status','Message'});
end
