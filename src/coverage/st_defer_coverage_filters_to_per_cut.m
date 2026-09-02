function R = st_defer_coverage_filters_to_per_cut(stageSelection)
%ST_DEFER_COVERAGE_FILTERS_TO_PER_CUT Record execution-local CVF preparation.
%
% PER_CUT creates and applies CVFs inside each immutable target directory.
% This workflow-stage result deliberately creates no shared cache file.

cfg = st_require_runtime_target();
T = st_load_targets(cfg.OnlyEnabled);
if nargin < 1
    stageSelection = [];
end
selection = st_normalize_stage_selection(T, stageSelection);
n = height(T);

FilterFile = strings(n,1);
RuleCount = zeros(n,1);
RulePaths = strings(n,1);
ApplicationMode = repmat("RUNTIME", n, 1);
PreparationAction = selection.Action;
PreparationReason = selection.Reason;
Status = repmat("OK", n, 1);
Message = repmat("Coverage filter disabled", n, 1);
active = T.CoverageFilterMode ~= "OFF";
Message(active) = "Deferred to execution-local PER_CUT filter generation";
cached = ~selection.Run;
Status(cached) = "CACHED";
Message(cached) = selection.Reason(cached);
ElapsedSec = zeros(n,1);
Timestamp = repmat(string(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss.SSS')), n, 1);

R = table(T.No, T.CUTName, T.CUTPath, T.TestCaseName, ...
    T.CoverageFilterMode, T.CoverageFilterAction, ...
    T.CoverageFilterRationale, ApplicationMode, FilterFile, RuleCount, ...
    RulePaths, PreparationAction, PreparationReason, Status, Message, ...
    ElapsedSec, Timestamp, ...
    'VariableNames', {'No','CUTName','CUTPath','TestCaseName', ...
    'FilterMode','FilterAction','Rationale','ApplicationMode', ...
    'FilterFile','RuleCount','RulePaths','PreparationAction', ...
    'PreparationReason','Status','Message','ElapsedSec','Timestamp'});
st_write_result('CoverageFilterResult', R);
end
