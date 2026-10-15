function released = st_release_execution_dirty_flag(cfg, model, wasClean)
%ST_RELEASE_EXECUTION_DIRTY_FLAG Clear the Dirty flag a test run raised.
%
% released = st_release_execution_dirty_flag(cfg, model, wasClean)
%
% Running tests through Test Manager marks the Top Model Dirty without
% changing anything that is saved: on the demo model on 2026-10-12 only
% run-time parameters differed (SavedSinceLoaded, RTWModifiedTimeStamp,
% SolverStatusFlags, ...), no block parameter. The test specification and
% the final document refuse a Dirty model, so they stopped on a change
% nobody made. Every change execution means to keep (expected values) is
% saved with save_system while it runs.
%
% WASCLEAN is true when the model was not loaded or was loaded and clean
% before execution. Only then is the flag cleared; a model that was already
% Dirty keeps it, because that change belongs to the operator. Nothing is
% saved. RELEASED is true when the flag was cleared.
released = false;
if ~wasClean || ~bdIsLoaded(model) || strcmp(get_param(model, 'Dirty'), 'off')
    return;
end
try
    set_param(model, 'Dirty', 'off');
    released = true;
    st_log(cfg, 'INFO', ['Cleared the Dirty flag raised while executing | ' ...
        'Model=%s | nothing was saved'], model);
catch ME
    st_log(cfg, 'WARN', 'Could not clear the Dirty flag of %s | %s', ...
        model, ME.message);
end
end
