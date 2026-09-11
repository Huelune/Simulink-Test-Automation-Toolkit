function result = st_apply_result_coverage_filters( ...
        resultObj, filterFiles, cfg, varargin)
%ST_APPLY_RESULT_COVERAGE_FILTERS Attach exact CVFs to result coverage data.
%
% Normal PER_CUT execution keeps its Test Manager-time filter behavior. The
% standalone pipeline opts into this strict post-run registration path.

p = inputParser;
addParameter(p, 'RequireCoverage', false, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'CoveragePath', '', ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'ReadOnly', false, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'RequireExactSet', false, ...
    @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

totalTimer = tic;
st_log(cfg, 'INFO', 'Result coverage filter attach start');
try
    filterFiles = resolve_filter_files(filterFiles);
    coverageObjects = st_flatten_coverage_results( ...
        getCoverageResults(resultObj));
    result = struct( ...
        'CoverageObjectCount', numel(coverageObjects), ...
        'FilterFiles', filterFiles, ...
        'MetricReadbackCount', 0, ...
        'Status', 'OK', ...
        'Message', 'Coverage filters attached to result data');

    if isempty(filterFiles)
        result.Message = 'No coverage filters to attach';
        st_log(cfg, 'INFO', ...
            ['Result coverage filter attach complete | no filters | ' ...
             'elapsed=%.3f sec'], toc(totalTimer));
        return;
    end
    if isempty(coverageObjects)
        if p.Results.RequireCoverage
            error('simtest:ResultCoverageDataMissing', ...
                'ResultSet contains no model coverage objects.');
        end
        result.Status = 'WARN';
        result.Message = 'ResultSet contains no coverage objects';
        st_log(cfg, 'WARN', ...
            ['Result coverage filter attach skipped | no coverage ' ...
             'objects | elapsed=%.3f sec'], toc(totalTimer));
        return;
    end

    propertyValue = filter_property_value(filterFiles);
    metricCount = 0;
    for i = 1:numel(coverageObjects)
        cvd = coverageObjects{i};
        if ~p.Results.ReadOnly
            cvd.filter = propertyValue;
        end
        returned = string(cvd.filter);
        returned = returned(:);
        returned(ismissing(returned)) = "";
        returned = returned(strlength(returned) > 0);
        actual = normalize_filter_values(returned);
        st_log(cfg, 'TRACE', ...
            ['Result coverage filter readback | Object=%d | ' ...
             'Requested=%s | Returned=%s | Resolved=%s'], ...
            i, join_filter_values(filterFiles), ...
            join_filter_values(returned), join_filter_values(actual));
        matches = filter_sets_match(filterFiles, actual);
        if p.Results.RequireExactSet
            matches = matches && filter_sets_match(actual, filterFiles);
        end
        if ~matches
            error('simtest:ResultCoverageFilterVerificationFailed', ...
                ['Coverage result did not retain every requested filter. ' ...
                 'Object=%d | Requested=%s | Returned=%s'], ...
                i, join_filter_values(filterFiles), ...
                join_filter_values(returned));
        end
        metricCount = metricCount + verify_metric_readback( ...
            cvd, char(string(p.Results.CoveragePath)));
    end
    result.MetricReadbackCount = metricCount;
    if p.Results.ReadOnly
        result.Message = 'Coverage filter readback verified';
    end
    st_log(cfg, 'INFO', ...
        'Result coverage filter attach complete | elapsed=%.3f sec', ...
        toc(totalTimer));
catch ME
    st_log(cfg, 'ERROR', ...
        'Result coverage filter attach failed | %s: %s', ...
        ME.identifier, ME.message);
    rethrow(ME);
end
end

function count = verify_metric_readback(cvd, coveragePath)
count = 0;
if isempty(coveragePath)
    return;
end
try
    decisioninfo(cvd, coveragePath);
    count = count + 1;
catch ME
    error('simtest:ResultCoverageDecisionReadbackFailed', ...
        'decisioninfo failed after CVF registration for %s: %s', ...
        coveragePath, ME.message);
end
try
    executioninfo(cvd, coveragePath);
    count = count + 1;
catch ME
    error('simtest:ResultCoverageExecutionReadbackFailed', ...
        'executioninfo failed after CVF registration for %s: %s', ...
        coveragePath, ME.message);
end
end

function files = normalize_filter_values(values)
files = string(values(:));
files(ismissing(files)) = "";
files = files(strlength(files) > 0);
for i = 1:numel(files)
    [resolved, found] = existing_filter_path(char(files(i)), true);
    if found, files(i) = resolved; end
end
end

function files = resolve_filter_files(values)
files = string(values(:));
files(ismissing(files)) = "";
files = unique(files(strlength(files) > 0), 'stable');
for i = 1:numel(files)
    candidate = char(files(i));
    [resolved, found] = existing_filter_path(candidate, true);
    if ~found
        error('simtest:ResultCoverageFilterNotFound', ...
            'Coverage filter cannot be resolved for result data: %s', ...
            candidate);
    end
    files(i) = resolved;
end
files = unique(files, 'stable');
end

function [path, found] = existing_filter_path(candidate, tryExtension)
located = '';
if isfile(candidate), located = candidate; else, located = which(candidate); end
if isempty(located) && tryExtension && ...
        ~endsWith(candidate, '.cvf', 'IgnoreCase', true)
    candidateWithExtension = [candidate '.cvf'];
    if isfile(candidateWithExtension)
        located = candidateWithExtension;
    else
        located = which(candidateWithExtension);
    end
end
found = ~isempty(located);
if ~found
    path = string(candidate);
    return;
end
[attributeStatus, attributes] = fileattrib(located);
if attributeStatus && isstruct(attributes) && isfield(attributes, 'Name')
    located = attributes.Name;
elseif ~is_absolute_path(located)
    located = fullfile(pwd, located);
end
path = string(located);
end

function tf = is_absolute_path(path)
if ispc
    tf = ~isempty(regexp(path, '^[A-Za-z]:[\\/]', 'once')) || startsWith(path, '\\');
else
    tf = startsWith(path, '/');
end
end

function keys = path_keys(paths)
keys = replace(string(paths(:)), '/', filesep);
if ispc, keys = lower(keys); end
end

function tf = filter_sets_match(expected, actual)
if all(ismember(path_keys(expected), path_keys(actual)))
    tf = true;
    return;
end
tf = all(ismember(filter_name_keys(expected), filter_name_keys(actual)));
end

function keys = filter_name_keys(paths)
paths = string(paths(:));
keys = strings(size(paths));
for i = 1:numel(paths)
    [~, name, extension] = fileparts(char(paths(i)));
    if isempty(extension), extension = '.cvf'; end
    keys(i) = string([name lower(extension)]);
end
if ispc, keys = lower(keys); end
end

function value = join_filter_values(values)
values = string(values(:));
if isempty(values), value = '<empty>'; else, value = char(strjoin(values, ' | ')); end
end

function value = filter_property_value(files)
if numel(files) == 1
    value = char(files(1));
else
    value = cellstr(files);
end
end
