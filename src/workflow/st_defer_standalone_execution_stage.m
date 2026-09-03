function R = st_defer_standalone_execution_stage(stageSelection, stage)
%ST_DEFER_STANDALONE_EXECUTION_STAGE Defer run-local standalone assets.

cfg = st_require_runtime_target();
T = st_load_targets(cfg.OnlyEnabled);
selection = st_normalize_stage_selection(T, stageSelection);
stage = upper(string(stage));

Action = repmat("DEFERRED", height(T), 1);
Status = repmat("OK", height(T), 1);
Message = "Deferred to execution-local EXPORTED_MODEL " + stage;
Message = repmat(Message, height(T), 1);
Action(~selection.Run) = "CACHED";
Status(~selection.Run) = "CACHED";
Message(~selection.Run) = selection.Reason(~selection.Run);

R = table(T.No, T.CUTName, T.TestCaseName, Action, Status, Message, ...
    'VariableNames', {'No','CUTName','TestCaseName','Action','Status', ...
    'Message'});
st_write_result(['Standalone' char(stage) 'Result'], R);
st_log(cfg, 'INFO', ...
    'Standalone execution stage deferred | stage=%s | targets=%d', ...
    char(stage), height(T));
end
