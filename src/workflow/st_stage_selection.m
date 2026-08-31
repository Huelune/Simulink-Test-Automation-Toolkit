function selection = st_stage_selection(plan, stage)
%ST_STAGE_SELECTION Convert one execution-plan stage to a row selection.

stage = upper(char(string(stage)));
runName = ['Run' stage];
actionName = ['Action' stage];
reasonName = ['Reason' stage];
selection = struct( ...
    'Run', plan.(runName), ...
    'Action', plan.(actionName), ...
    'Reason', plan.(reasonName));
end
