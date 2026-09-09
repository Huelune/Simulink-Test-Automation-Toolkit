function modes = st_resolve_coverage_boundary_modes(values)
%ST_RESOLVE_COVERAGE_BOUNDARY_MODES Normalize OFF/CUT_ONLY target values.

modes = upper(strtrim(string(values)));
modes(ismissing(modes) | strlength(modes) == 0) = "OFF";
invalid = ~ismember(modes, ["OFF","CUT_ONLY"]);
if any(invalid)
    error('simtest:InvalidCoverageBoundaryMode', ...
        'CoverageBoundaryMode must be OFF or CUT_ONLY: %s', ...
        char(strjoin(unique(modes(invalid)), ', ')));
end
end
