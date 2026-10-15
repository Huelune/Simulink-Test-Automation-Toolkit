function action = st_discard_execution_model_changes(cfg, model, modelFile, wasLoaded, wasClean)
%ST_DISCARD_EXECUTION_MODEL_CHANGES Return the Top Model to its saved state after a test run.
%
% action = st_discard_execution_model_changes(cfg, model, modelFile, wasLoaded, wasClean)
%
% Running tests through Test Manager leaves the Top Model Dirty. On the demo
% model (2026-10-12) its own parameters differed from the saved file only in
% run-time values, but its internal Harnesses kept unsaved in-memory changes:
% clearing the Dirty flag alone still made the test specification load a
% Dirty Harness and stop with SpecificationUnsaved, while closing the model
% without saving let it pass. Every change execution means to keep
% (expected values) is saved with save_system while it runs, so whatever is
% still unsaved afterwards is discarded here.
%
% WASLOADED and WASCLEAN describe the model before execution. A model that
% was loaded and already Dirty is left alone, because that change belongs to
% the operator. Otherwise a Dirty model is closed without saving, and loaded
% again from MODELFILE when it was loaded before, so the session looks as it
% did. ACTION is "NONE", "CLOSED" or "RELOADED".
action = "NONE";
if ~bdIsLoaded(model) || (wasLoaded && ~wasClean) || ...
        strcmp(get_param(model, 'Dirty'), 'off')
    return;
end
try
    close_system(model, 0);
    action = "CLOSED";
    if wasLoaded
        load_system(modelFile);
        action = "RELOADED";
    end
    st_log(cfg, 'INFO', ['Discarded the unsaved changes a test run left | ' ...
        'Model=%s | Action=%s | nothing was saved'], model, action);
catch ME
    st_log(cfg, 'WARN', 'Could not discard the unsaved changes of %s | Action=%s | %s', ...
        model, action, ME.message);
end
end
