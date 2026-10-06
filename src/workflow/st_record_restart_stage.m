function state = st_record_restart_stage(state, plan, stage, cfg, status)
%ST_RECORD_RESTART_STAGE Persist stage-scoped readbacks, including failure.
% Only st_run_from_stage reads this evidence, and the readback reopens every
% Harness, so nothing is recorded unless cfg.RecordRestartEvidence is set.
if ~(isfield(cfg,'RecordRestartEvidence') && logical(cfg.RecordRestartEvidence))
    return;
end
if ~isfield(state,'RestartEvidence'), state.RestartEvidence = struct([]); end
state.Version = 2;
for i = 1:height(plan)
    if ~plan.(['Run' stage])(i), continue; end
    record = struct('Key',char(plan.Key(i)),'Stage',stage,'Status',status, ...
        'InputHash','','OutputHash','','Message','','UpdatedAt',char(datetime('now')));
    if strcmp(status,'OK')
        try
            T = st_load_targets(cfg.OnlyEnabled);
            row = T(T.No == plan.No(i) & T.TestCaseName == plan.TestCaseName(i),:);
            if height(row) ~= 1, error('simtest:RestartIdentity','Target mapping is ambiguous.'); end
            inputs = st_stage_inputs(row,cfg);
            record.InputHash = inputs.(stage);
            value = st_inspect_preparation_stage(stage,row,cfg);
            record.OutputHash = st_hash_value(value);
        catch ME
            record.Status = 'UNVERIFIED';
            record.Message = ME.message;
            st_log(cfg,'WARN','Restart checkpoint unverified | Stage=%s | TC=%s | %s', ...
                stage,plan.TestCaseName(i),ME.message);
        end
    end
    index = [];
    if ~isempty(state.RestartEvidence)
        index = find(strcmp({state.RestartEvidence.Key},record.Key) & ...
            strcmp({state.RestartEvidence.Stage},stage),1);
    end
    if isempty(state.RestartEvidence), state.RestartEvidence = record;
    elseif isempty(index), state.RestartEvidence(end+1) = record;
    else, state.RestartEvidence(index) = record; end
end
st_save_workflow_state(state,cfg);
end
