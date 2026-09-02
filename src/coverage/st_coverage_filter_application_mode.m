function mode = st_coverage_filter_application_mode(value)
%ST_COVERAGE_FILTER_APPLICATION_MODE Validate the global apply policy.

mode = upper(strtrim(char(string(value))));
if ~ismember(mode, {'RUNTIME', 'PERSIST'})
    error('simtest:InvalidCoverageFilterApplicationMode', ...
        ['cfg.CoverageFilterApplicationMode must be RUNTIME or PERSIST. ' ...
         'Actual=%s'], mode);
end
end
