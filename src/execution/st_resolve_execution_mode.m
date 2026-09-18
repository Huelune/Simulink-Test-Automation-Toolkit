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

% Coverage filters are applied when the artifacts are built, so they no
% longer decide how the tests run. AUTO still prefers PER_CUT for a target
% that carries one, because that target is usually also the one that has to
% run alone, but BATCH is now a legitimate choice for it.
hasActiveFilter = any(st_coverage_filter_active(targetConfig));
if requestedMode == "AUTO"
    if hasActiveFilter
        mode = 'PER_CUT';
    else
        mode = 'BATCH';
    end
else
    mode = char(requestedMode);
end
end
