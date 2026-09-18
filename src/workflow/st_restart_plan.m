function plan = st_restart_plan(plan, fromStage)
%ST_RESTART_PLAN Apply a strict boundary after prerequisite validation.
stages = st_workflow_stages('FROM_HARNESS');
[~, index] = st_workflow_stages('FROM_HARNESS',fromStage);
% The last stage is EXECUTE, which the plan does not carry columns for.
for s = 1:numel(stages)-1
    selected = s >= index;
    plan.(['Run' char(stages(s))])(:) = selected;
    if selected, action = "FORCE"; reason = "Explicit restart from " + string(fromStage);
    else, action = "CACHED"; reason = "Validated restart prerequisite"; end
    plan.(['Action' char(stages(s))])(:) = action;
    plan.(['Reason' char(stages(s))])(:) = reason;
end
end
