function plan = st_restart_plan(plan, fromStage)
%ST_RESTART_PLAN Apply a strict boundary after prerequisite validation.
stages = st_workflow_stages('FROM_HARNESS');
[~, index] = st_workflow_stages('FROM_HARNESS',fromStage);
for s = 1:8
    selected = s >= index;
    plan.(['Run' char(stages(s))])(:) = selected;
    if selected, action = "FORCE"; reason = "Explicit restart from " + string(fromStage);
    else, action = "CACHED"; reason = "Validated restart prerequisite"; end
    plan.(['Action' char(stages(s))])(:) = action;
    plan.(['Reason' char(stages(s))])(:) = reason;
end
end
