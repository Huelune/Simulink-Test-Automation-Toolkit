function [state, loadStatus] = st_load_workflow_state(cfg)
%ST_LOAD_WORKFLOW_STATE Load the latest incremental workflow checkpoint.

state = empty_state();
loadStatus = 'MISSING';
if ~isfile(cfg.WorkflowStateFile)
    return;
end

try
    loaded = load(cfg.WorkflowStateFile, 'state');
    if ~isfield(loaded, 'state') || ...
            ~isstruct(loaded.state) || ...
            ~isfield(loaded.state, 'Version') || ...
            loaded.state.Version ~= 1
        loadStatus = 'INVALID';
        return;
    end
    state = loaded.state;
    loadStatus = 'OK';
catch
    state = empty_state();
    loadStatus = 'CORRUPT';
end
end

function state = empty_state()
state = struct();
state.Version = 1;
state.CreatedAt = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
state.UpdatedAt = state.CreatedAt;
state.Artifacts = struct('Model', struct(), 'TestFile', struct());
state.Targets = repmat(struct( ...
    'Key', '', 'No', NaN, 'CUTName', '', 'CUTPath', '', ...
    'HarnessName', '', 'TestCaseName', '', ...
    'StageSignatures', struct(), 'UpdatedAt', ''), 0, 1);
end
