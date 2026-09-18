function mode = st_resolve_execution_mode(requestedMode, ~)
%ST_RESOLVE_EXECUTION_MODE Validate the BATCH/PER_CUT execution policy.
%
% The caller decides how the tests run. Nothing in the workbook does.
%
%   BATCH    run(tf) once for every enabled Test Case
%   PER_CUT  run(tc) per Test Case, for Test Cases that must run alone
%
% The second argument is the Targets table. It is ignored and kept only so
% existing call sites do not have to change.

requestedMode = upper(strtrim(string(requestedMode)));
if ismissing(requestedMode) || strlength(requestedMode) == 0
    requestedMode = "BATCH";
end
if isscalar(requestedMode) && requestedMode == "AUTO"
    error('simtest:RemovedExecutionMode', ...
        ['AUTO is gone. It chose PER_CUT whenever a target carried a ' ...
         'coverage filter, which stopped being a reason once filters ' ...
         'moved to the artifact stage. Pass BATCH or PER_CUT.']);
end
if ~isscalar(requestedMode) || ...
        ~ismember(requestedMode, ["BATCH","PER_CUT"])
    error('simtest:InvalidExecutionMode', ...
        'ExecutionMode must be BATCH or PER_CUT.');
end
mode = char(requestedMode);
end
