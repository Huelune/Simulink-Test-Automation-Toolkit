function st_save_workflow_state(state, cfg)
%ST_SAVE_WORKFLOW_STATE Atomically replace MAT state and JSON summary.

stateDir = fileparts(cfg.WorkflowStateFile);
if ~isfolder(stateDir)
    mkdir(stateDir);
end

state.UpdatedAt = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));

matTemp = [tempname(stateDir) '.mat'];
jsonTemp = [tempname(stateDir) '.json'];
cleanupFiles = onCleanup(@() cleanup_temporary(matTemp, jsonTemp)); %#ok<NASGU>

save(matTemp, 'state');
replace_file(matTemp, cfg.WorkflowStateFile);

jsonText = jsonencode(state);
fileId = fopen(jsonTemp, 'w', 'n', 'UTF-8');
if fileId < 0
    error('simtest:WorkflowStateWriteFailed', ...
        'Cannot create workflow state summary: %s', jsonTemp);
end
fileCleanup = onCleanup(@() fclose_quiet(fileId));
fprintf(fileId, '%s\n', jsonText);
clear fileCleanup;
replace_file(jsonTemp, cfg.WorkflowStateSummaryFile);
end

function replace_file(source, destination)
[ok, message] = movefile(source, destination, 'f');
if ~ok
    error('simtest:WorkflowStateWriteFailed', ...
        'Cannot replace %s: %s', destination, message);
end
end

function cleanup_temporary(varargin)
for i = 1:nargin
    if isfile(varargin{i})
        delete(varargin{i});
    end
end
end

function fclose_quiet(fileId)
if fileId >= 0
    fclose(fileId);
end
end
