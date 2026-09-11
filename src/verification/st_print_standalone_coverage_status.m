function report = st_print_standalone_coverage_status(varargin)
%ST_PRINT_STANDALONE_COVERAGE_STATUS Print compact screenshot diagnostics.
%
%   clc
%   st_print_standalone_coverage_status( ...
%       'OutputRoot', 'D:\stcov', 'PipelineId', 'LATEST');

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'OutputRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'PipelineId', 'LATEST', ...
    @(x) ischar(x) || isstring(x));
parse(p, varargin{:});

cfg = st_require_runtime_target('LoadModel', false);
outputRoot = strtrim(char(string(p.Results.OutputRoot)));
if isempty(outputRoot), outputRoot = cfg.StandaloneCoverageRootDir; end
timerValue = tic;
st_log(cfg, 'INFO', ...
    'Standalone coverage compact diagnosis start | Root=%s', outputRoot);

lines = strings(0, 1);
lines(end+1,1) = "STANDALONE-STATUS-v1 BEGIN";
lines(end+1,1) = "ENV Release=" + string(version('-release')) + ...
    " ST=" + license('test', 'Simulink_Test') + ...
    " CV=" + license('test', 'Simulink_Coverage') + ...
    " RootExists=" + isfolder(outputRoot);
lines(end+1,1) = function_status_line();

try
    [manifest, manifestPath] = st_load_standalone_pipeline_manifest( ...
        outputRoot, p.Results.PipelineId);
catch ME
    lines(end+1,1) = "MANIFEST ERROR=" + string(ME.identifier);
    lines(end+1,1) = "MSG " + compact_text(ME.message, 140);
    lines(end+1,1) = "ROOT " + string(outputRoot);
    lines(end+1,1) = "STANDALONE-STATUS-v1 END";
    report = char(strjoin(lines, newline));
    fprintf('%s\n', report);
    st_log(cfg, 'ERROR', ...
        'Standalone coverage compact diagnosis failed | %s: %s', ...
        ME.identifier, ME.message);
    return;
end

pipelineRoot = fileparts(manifestPath);
lines(end+1,1) = "PIPE Id=" + string(manifest.PipelineId) + ...
    " Status=" + field_text(manifest, 'Status') + ...
    " 234=" + step_status(manifest, 'STEP234') + ...
    " 5=" + step_status(manifest, 'STEP5') + ...
    " 6=" + step_status(manifest, 'STEP6');
counts = artifact_counts(pipelineRoot);
lines(end+1,1) = sprintf( ...
    'FILES work[slx=%d mat=%d result=%d cvf=%d] final[slx=%d mat=%d cvf=%d cvt=%d xlsx=%d]', ...
    counts.WorkSLX, counts.WorkMAT, counts.WorkResult, counts.WorkCVF, ...
    counts.FinalSLX, counts.FinalMAT, counts.FinalCVF, ...
    counts.FinalCVT, counts.FinalXLSX);
lines(end+1,1) = "LEGEND 234=STEP234 RF=result-filter RS=restore S5=STEP5 " + ...
    "WM/WI=work model/input PM/PI=packaged RCV/HCV=root/hierarchy coverage";
lines = [lines; step234_artifact_failure_lines(manifest)]; %#ok<AGROW>

targets = manifest.Targets;
for i = 1:numel(targets)
    item = targets(i);
    [rootCoverage, hierarchyCoverage, resultState] = ...
        inspect_target_result(item);
    lines(end+1,1) = sprintf( ...
        ['T%d %s | 234=%s RF=%s RS=%s S5=%s | ' ...
         'WM=%s WI=%s PM=%s PI=%s CVF=%s | R=%s RCV=%s HCV=%s'], ...
        i, compact_text(field_text(item, 'CUTName'), 34), ...
        short_status(field_text(item, 'Step234Status')), ...
        short_status(field_text(item, 'ResultFilterStatus')), ...
        short_status(field_text(item, 'FilterRestoreStatus')), ...
        short_status(field_text(item, 'Step5Status')), ...
        exists_code(field_text(item, 'StandaloneModelFile')), ...
        exists_code(field_text(item, 'SignalEditorInput')), ...
        exists_code(field_text(item, 'PackagedStandaloneModel')), ...
        exists_code(field_text(item, 'PackagedInput')), ...
        exists_code(active_cvf(item)), resultState, ...
        rootCoverage, hierarchyCoverage); %#ok<AGROW>
    message = field_text(item, 'Message');
    if ~isempty(message) && ~strcmp(message, '-')
        lines(end+1,1) = "  MSG " + compact_text(message, 155); %#ok<AGROW>
    end
end

lines(end+1,1) = "ROOT " + string(outputRoot);
lines(end+1,1) = "PIPE_ROOT " + string(pipelineRoot);
lines(end+1,1) = "STANDALONE-STATUS-v1 END";
report = char(strjoin(lines, newline));
fprintf('%s\n', report);
st_log(cfg, 'INFO', ...
    'Standalone coverage compact diagnosis complete | elapsed=%.3f sec', ...
    toc(timerValue));
end

function lines = step234_artifact_failure_lines(manifest)
lines = strings(0, 1);
runDirectory = field_text(manifest, 'PerCutRunDirectory');
if strcmp(runDirectory, '-')
    lines(end+1,1) = "234-DETAIL PerCutRunDirectory=<NONE>";
    return;
end
runManifest = fullfile(runDirectory, 'manifest.json');
if ~isfile(runManifest)
    lines(end+1,1) = "234-DETAIL manifest.json=MISSING";
    return;
end
try
    value = jsondecode(fileread(runManifest));
    if ~isfield(value, 'Artifacts') || isempty(value.Artifacts)
        lines(end+1,1) = "234-DETAIL artifact-records=0";
        return;
    end
    artifacts = value.Artifacts;
    failed = false(numel(artifacts), 1);
    for i = 1:numel(artifacts)
        failed(i) = strcmpi(field_text(artifacts(i), 'Status'), 'FAIL');
    end
    artifacts = artifacts(failed);
    if isempty(artifacts)
        lines(end+1,1) = "234-DETAIL artifact-failures=0";
        return;
    end
    keys = strings(numel(artifacts), 1);
    for i = 1:numel(artifacts)
        keys(i) = string(field_text(artifacts(i), 'Type')) + "|" + ...
            compact_text(field_text(artifacts(i), 'Message'), 120);
    end
    [uniqueKeys, first, groups] = unique(keys, 'stable'); %#ok<ASGLU>
    lines(end+1,1) = "234-DETAIL artifact-failures=" + numel(artifacts) + ...
        " groups=" + numel(uniqueKeys);
    maxGroups = min(6, numel(uniqueKeys));
    for g = 1:maxGroups
        members = find(groups == g);
        numbers = strings(numel(members), 1);
        for j = 1:numel(members)
            numbers(j) = string(field_text(artifacts(members(j)), 'No'));
        end
        sample = artifacts(first(g));
        lines(end+1,1) = "  AF " + field_text(sample, 'Type') + ...
            " x" + numel(members) + ...
            " T=" + strjoin(unique(numbers, 'stable'), ',') + ...
            " | " + compact_text(field_text(sample, 'Message'), 120); %#ok<AGROW>
    end
    if numel(uniqueKeys) > maxGroups
        lines(end+1,1) = "  AF ... additional-groups=" + ...
            (numel(uniqueKeys) - maxGroups);
    end
catch ME
    lines(end+1,1) = "234-DETAIL read-error=" + string(ME.identifier) + ...
        " | " + compact_text(ME.message, 120);
end
end

function line = function_status_line()
names = { ...
    'st_run_standalone_coverage_pipeline', ...
    'st_package_standalone_coverage_artifacts', ...
    'st_apply_result_coverage_filters', ...
    'st_collect_result_coverage_objects'};
counts = zeros(1, numel(names));
for i = 1:numel(names)
    value = which(names{i}, '-all');
    if isempty(value)
        counts(i) = 0;
    elseif iscell(value)
        counts(i) = numel(value);
    elseif isstring(value)
        counts(i) = numel(value);
    else
        counts(i) = size(value, 1);
    end
end
packagePath = which('st_package_standalone_coverage_artifacts');
collectorPath = which('st_collect_result_coverage_objects');
preserveFlag = source_contains(packagePath, 'standalone inputs preserved');
hierarchyFlag = source_contains(collectorPath, ...
    'st_collect_test_case_results(resultObj)');
line = sprintf( ...
    'CODE functions[pipeline=%d package=%d filter=%d collector=%d] flags[preserve=%d hierarchy=%d]', ...
    counts(1), counts(2), counts(3), counts(4), ...
    preserveFlag, hierarchyFlag);
end

function tf = source_contains(path, pattern)
tf = ~isempty(path) && isfile(path) && contains(fileread(path), pattern);
end

function counts = artifact_counts(pipelineRoot)
workRoot = fullfile(pipelineRoot, '.work');
counts = struct( ...
    'WorkSLX', file_count(workRoot, '*.slx'), ...
    'WorkMAT', file_count(workRoot, '*.mat'), ...
    'WorkResult', file_count(workRoot, '*Results.mldatx'), ...
    'WorkCVF', file_count(workRoot, '*.cvf'), ...
    'FinalSLX', final_count(pipelineRoot, '*.slx'), ...
    'FinalMAT', final_count(pipelineRoot, '*.mat'), ...
    'FinalCVF', final_count(pipelineRoot, '*.cvf'), ...
    'FinalCVT', final_count(pipelineRoot, '*.cvt'), ...
    'FinalXLSX', final_count(pipelineRoot, '*.xlsx'));
end

function count = file_count(root, pattern)
if ~isfolder(root), count = 0; return; end
count = numel(dir(fullfile(root, '**', pattern)));
end

function count = final_count(root, pattern)
if ~isfolder(root), count = 0; return; end
items = dir(fullfile(root, '**', pattern));
count = 0;
workPrefix = canonical_prefix(fullfile(root, '.work'));
for i = 1:numel(items)
    path = char(java.io.File(fullfile(items(i).folder, ...
        items(i).name)).getCanonicalPath());
    if ~startsWith(lower(path), lower(workPrefix)), count = count + 1; end
end
end

function prefix = canonical_prefix(path)
prefix = [char(java.io.File(path).getCanonicalPath()) filesep];
end

function [rootCount, hierarchyCount, resultState] = ...
        inspect_target_result(item)
rootCount = '-';
hierarchyCount = '-';
resultState = 'NONE';
directory = field_text(item, 'SelectedResultDirectory');
if isempty(directory) || strcmp(directory, '-') || ~isfolder(directory)
    return;
end
files = dir(fullfile(directory, '**', '*Results.mldatx'));
if isempty(files), return; end
resultState = 'OK';
try
    imported = sltest.testmanager.importResults( ...
        fullfile(files(1).folder, files(1).name));
    directCount = 0;
    allCount = 0;
    for i = 1:numel(imported)
        directCount = directCount + numel(st_flatten_coverage_results( ...
            getCoverageResults(imported(i))));
        allCount = allCount + numel( ...
            st_collect_result_coverage_objects(imported(i)));
    end
    rootCount = char(string(directCount));
    hierarchyCount = char(string(allCount));
catch
    resultState = 'ERR';
    rootCount = 'E';
    hierarchyCount = 'E';
end
end

function value = active_cvf(item)
value = field_text(item, 'ExecutionCVFPath');
if strcmp(value, '-'), value = field_text(item, 'CVFPath'); end
end

function value = step_status(manifest, name)
value = '-';
if isfield(manifest, 'Steps') && isfield(manifest.Steps, name)
    value = short_status(field_text(manifest.Steps.(name), 'Status'));
end
end

function value = short_status(raw)
raw = upper(char(string(raw)));
switch raw
    case 'OK', value = 'OK';
    case 'WARN', value = 'WRN';
    case 'FAIL', value = 'FAIL';
    case 'SKIP', value = 'SKIP';
    case 'NOT_RUN', value = '-';
    otherwise, value = compact_text(raw, 5);
end
end

function value = exists_code(path)
if isempty(path) || strcmp(path, '-')
    value = '-';
elseif isfile(path)
    value = 'Y';
else
    value = 'N';
end
end

function value = field_text(item, name)
value = '-';
if ~isstruct(item) || ~isfield(item, name), return; end
raw = item.(name);
if isempty(raw), return; end
value = char(string(raw));
if isempty(value), value = '-'; end
end

function value = compact_text(raw, limit)
value = char(regexprep(char(string(raw)), '\s+', ' '));
if strlength(string(value)) > limit
    value = [value(1:max(1, limit-3)) '...'];
end
end
