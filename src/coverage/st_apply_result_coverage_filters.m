function result = st_apply_result_coverage_filters( ...
        resultObj, filterFiles, cfg)
%ST_APPLY_RESULT_COVERAGE_FILTERS Attach exact CVFs to result coverage data.

totalTimer = tic;
st_log(cfg, 'DEBUG', ...
    'Result coverage filter attach start');
try
    filterFiles = resolve_filter_files(filterFiles);
    coverageObjects = getCoverageResults(resultObj);
    result = struct( ...
        'CoverageObjectCount', numel(coverageObjects), ...
        'FilterFiles', filterFiles, ...
        'Status', 'OK', ...
        'Message', 'Coverage filters attached to result data');

    if isempty(filterFiles)
        result.Message = 'No coverage filters to attach';
        st_log(cfg, 'DEBUG', ...
            ['Result coverage filter attach complete | no filters | ' ...
             'elapsed=%.3f sec'], toc(totalTimer));
        return;
    end
    if isempty(coverageObjects)
        result.Status = 'WARN';
        result.Message = 'ResultSet contains no coverage objects';
        st_log(cfg, 'WARN', ...
            ['Result coverage filter attach skipped | no coverage ' ...
             'objects | elapsed=%.3f sec'], toc(totalTimer));
        return;
    end

    st_log(cfg, 'DEBUG', ...
        'Result coverage filter attach resolved | objects=%d | filters=%d', ...
        numel(coverageObjects), numel(filterFiles));
    propertyValue = filter_property_value(filterFiles);
    for i = 1:numel(coverageObjects)
        coverageObjects(i).filter = propertyValue;
        actual = normalize_filter_values(coverageObjects(i).filter);
        if ~all(ismember(path_keys(filterFiles), path_keys(actual)))
            error('simtest:ResultCoverageFilterVerificationFailed', ...
                ['Coverage result did not retain every requested filter. ' ...
                 'Object=%d'], i);
        end
    end
    st_log(cfg, 'DEBUG', ...
        'Result coverage filter attach complete | elapsed=%.3f sec', ...
        toc(totalTimer));
catch ME
    st_log(cfg, 'ERROR', ...
        'Result coverage filter attach failed | %s: %s', ...
        ME.identifier, ME.message);
    rethrow(ME);
end
end


function files = normalize_filter_values(values)
files = string(values(:));
files(ismissing(files)) = "";
files = files(strlength(files) > 0);
for i = 1:numel(files)
    candidate = char(files(i));
    [resolved, found] = existing_filter_path(candidate, false);
    if found
        files(i) = resolved;
    end
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
if isfile(candidate)
    located = candidate;
else
    located = which(candidate);
end
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
    tf = ~isempty(regexp(path, '^[A-Za-z]:[\\/]', 'once')) || ...
        startsWith(path, '\\');
else
    tf = startsWith(path, '/');
end
end


function keys = path_keys(paths)
keys = replace(string(paths(:)), '/', filesep);
if ispc
    keys = lower(keys);
end
end


function value = filter_property_value(files)
if numel(files) == 1
    value = char(files(1));
else
    value = cellstr(files);
end
end
