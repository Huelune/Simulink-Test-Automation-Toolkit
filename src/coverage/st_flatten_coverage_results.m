function objects = st_flatten_coverage_results(value)
%ST_FLATTEN_COVERAGE_RESULTS Normalize cvdata/group/cell API returns.

objects = {};
if isempty(value)
    return;
end
if iscell(value)
    for i = 1:numel(value)
        objects = [objects; st_flatten_coverage_results(value{i})]; %#ok<AGROW>
    end
    return;
end
if isa(value, 'cv.cvdatagroup')
    objects = st_flatten_coverage_results(getAll(value));
    return;
end
if isa(value, 'cvdata')
    for i = 1:numel(value)
        objects{end+1,1} = value(i); %#ok<AGROW>
    end
    return;
end
error('simtest:UnsupportedCoverageResultType', ...
    'Unsupported coverage result type: %s', class(value));
end
