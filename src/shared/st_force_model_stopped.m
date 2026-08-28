function st_force_model_stopped(modelName)
%ST_FORCE_MODEL_STOPPED Force a model to SimulationStatus='stopped'.
%
% Important:
% A model compiled with feval(model,[],[],[],'compile') can appear as
% SimulationStatus='paused' on some models/releases. In that case the
% correct termination command is 'term', not SimulationCommand='stop'.
%
% Strategy:
%   stopped  -> return
%   compiled -> try term
%   paused   -> try term first, then SimulationCommand='stop' as fallback
%   running  -> SimulationCommand='stop'

modelName = char(modelName);

if ~bdIsLoaded(modelName)
    load_system(modelName);
end

maxAttempts = 100;

for k = 1:maxAttempts
    status = get_param(modelName, 'SimulationStatus');

    if strcmp(status, 'stopped')
        return;
    end

    % Model-function compile may report either compiled or paused.
    if strcmp(status, 'compiled') || strcmp(status, 'paused')
        termSucceeded = false;
        try
            feval(modelName, [], [], [], 'term');
            termSucceeded = true;
        catch
            % If this was a normal paused simulation, term can fail.
        end

        if termSucceeded
            pause(0.05);
            continue;
        end
    end

    if strcmp(status, 'running') || strcmp(status, 'paused')
        try
            set_param(modelName, 'SimulationCommand', 'stop');
        catch ME
            error(['Could not stop model. SimulationStatus=%s\n' ...
                'Message: %s'], status, ME.message);
        end
        pause(0.05);
        continue;
    end

    if strcmp(status, 'initializing') || ...
            strcmp(status, 'updating') || ...
            strcmp(status, 'terminating')
        pause(0.1);
        continue;
    end

    error('Unknown SimulationStatus: %s', status);
end

status = get_param(modelName, 'SimulationStatus');
error('Could not force model to stopped state. Current status: %s', status);
end
