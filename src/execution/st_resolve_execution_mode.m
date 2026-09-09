function mode = st_resolve_execution_mode(requestedMode, targetConfig)
%ST_RESOLVE_EXECUTION_MODE Resolve AUTO/BATCH/PER_CUT execution policy.

requestedMode = upper(strtrim(string(requestedMode)));
if ismissing(requestedMode) || strlength(requestedMode) == 0
    requestedMode = "AUTO";
end
if ~isscalar(requestedMode) || ...
        ~ismember(requestedMode, ["AUTO","BATCH","PER_CUT"])
    error('simtest:InvalidExecutionMode', ...
        'ExecutionMode must be AUTO, BATCH, or PER_CUT.');
end

hasActiveFilter = any(st_coverage_filter_active(targetConfig));
if requestedMode == "AUTO"
    if hasActiveFilter
        mode = 'PER_CUT';
    else
        mode = 'BATCH';
    end
elseif requestedMode == "BATCH" && hasActiveFilter
    error('simtest:BatchExecutionWithCoverageFilter', ...
        ['BATCH execution is allowed only when every enabled target has ' ...
         'both coverage filter modes OFF. Use AUTO or PER_CUT.']);
else
    mode = char(requestedMode);
end
end
