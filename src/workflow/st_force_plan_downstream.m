function plan = st_force_plan_downstream(plan, rows, fromStage, reason)
%ST_FORCE_PLAN_DOWNSTREAM Mark selected rows and downstream stages to run.

stages = ["HARNESS", "SLDV", "HARNESS_CONFIG", "SIGNAL_EDITOR", ...
    "ASSESSMENT", "TEST_MANAGER", "ALIGNMENT"];
startIndex = find(stages == upper(string(fromStage)), 1);
if isempty(startIndex)
    error('simtest:InvalidPreparationFromStage', ...
        'Unknown workflow stage: %s', char(string(fromStage)));
end
rows = logical(rows(:));
for s = startIndex:numel(stages)
    stage = char(stages(s));
    plan.(sprintf('Run%s', stage))(rows) = true;
    plan.(sprintf('Action%s', stage))(rows) = "RUN";
    plan.(sprintf('Reason%s', stage))(rows) = string(reason);
end
end
