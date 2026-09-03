function policy = st_coverage_filter_existing_policy(value)
%ST_COVERAGE_FILTER_EXISTING_POLICY Normalize existing-CVF handling policy.

policy = upper(strtrim(char(string(value))));
if ~ismember(policy, {'REPLACE', 'MERGE'})
    error('simtest:InvalidCoverageFilterExistingPolicy', ...
        ['CoverageFilterExistingPolicy must be REPLACE or MERGE. ' ...
         'Received: %s'], policy);
end
end
