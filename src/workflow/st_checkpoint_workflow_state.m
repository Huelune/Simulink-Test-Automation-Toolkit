function state = st_checkpoint_workflow_state(state, plan, stage, result, cfg)
%ST_CHECKPOINT_WORKFLOW_STATE Save successful rows for one workflow stage.

stage = upper(char(string(stage)));
runColumn = ['Run' stage];
signatureColumn = ['Signature' stage];
if height(result) ~= height(plan) || ~ismember('Status', ...
        result.Properties.VariableNames)
    error('simtest:InvalidStageResult', ...
        'Stage %s result rows/status do not match the execution plan.', stage);
end

for i = 1:height(plan)
    if ~plan.(runColumn)(i) || strcmpi(char(result.Status(i)), 'FAIL')
        continue;
    end
    index = find(strcmp({state.Targets.Key}, char(plan.Key(i))), ...
        1, 'first');
    if isempty(index)
        error('simtest:WorkflowStateTargetMissing', ...
            'Workflow state target is missing: %s', char(plan.Key(i)));
    end
    state.Targets(index).StageSignatures.(stage) = ...
        char(plan.(signatureColumn)(i));
    state.Targets(index).UpdatedAt = char(datetime('now', ...
        'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
end

state.Artifacts.Model = st_file_signature(cfg.ModelFile);
state.Artifacts.TestFile = st_file_signature(cfg.TestFile);
st_save_workflow_state(state, cfg);
end
