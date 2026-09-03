function mode = st_resolve_execution_mode( ...
        requestedMode, targetConfig, systemUnderTestMode)
%ST_RESOLVE_EXECUTION_MODE Resolve AUTO/BATCH/PER_CUT execution policy.

if nargin < 3
    systemUnderTestMode = 'INTERNAL_HARNESS';
end
systemUnderTestMode = st_resolve_system_under_test_mode( ...
    systemUnderTestMode);

requestedMode = upper(strtrim(string(requestedMode)));
if ismissing(requestedMode) || strlength(requestedMode) == 0
    requestedMode = "AUTO";
end
if ~isscalar(requestedMode) || ...
        ~ismember(requestedMode, ["AUTO","BATCH","PER_CUT"])
    error('simtest:InvalidExecutionMode', ...
        'ExecutionMode must be AUTO, BATCH, or PER_CUT.');
end

hasActiveFilter = any(string(targetConfig.CoverageFilterMode) ~= "OFF");
if strcmp(systemUnderTestMode, 'EXPORTED_MODEL')
    if requestedMode == "BATCH"
        error('simtest:StandaloneModelRequiresPerCut', ...
            ['EXPORTED_MODEL execution requires PER_CUT because every ' ...
             'CUT has a different standalone SUT and Harness-scope CVF.']);
    end
    mode = 'PER_CUT';
    return;
end
if requestedMode == "AUTO"
    if hasActiveFilter
        mode = 'PER_CUT';
    else
        mode = 'BATCH';
    end
elseif requestedMode == "BATCH" && hasActiveFilter
    error('simtest:BatchExecutionWithCoverageFilter', ...
        ['BATCH execution is allowed only when every enabled target has ' ...
         'CoverageFilterMode=OFF. Use AUTO or PER_CUT.']);
else
    mode = char(requestedMode);
end
end
