function state = st_invalidate_workflow_state(state, plan)
%ST_INVALIDATE_WORKFLOW_STATE Clear checkpoints selected to run.

stages = {'HARNESS','SLDV','HARNESS_CONFIG','SIGNAL_EDITOR', ...
    'ASSESSMENT','COVERAGE_FILTER','TEST_MANAGER','ALIGNMENT'};
for i = 1:height(plan)
    index = find_target(state, char(plan.Key(i)));
    if isempty(index)
        state.Targets(end+1,1) = new_target(plan(i,:)); %#ok<AGROW>
        index = numel(state.Targets);
    end
    for s = 1:numel(stages)
        stage = stages{s};
        if plan.(sprintf('Run%s', stage))(i) && ...
                isfield(state.Targets(index).StageSignatures, stage)
            state.Targets(index).StageSignatures = ...
                rmfield(state.Targets(index).StageSignatures, stage);
        end
    end
end
end

function target = new_target(row)
target = struct( ...
    'Key', char(row.Key), ...
    'No', double(row.No), ...
    'CUTName', char(row.CUTName), ...
    'CUTPath', char(row.CUTPath), ...
    'HarnessName', char(row.HarnessName), ...
    'TestCaseName', char(row.TestCaseName), ...
    'StageSignatures', struct(), ...
    'UpdatedAt', '');
end

function index = find_target(state, key)
index = [];
if ~isempty(state.Targets)
    index = find(strcmp({state.Targets.Key}, key), 1, 'first');
end
end
