function [required, usableOutputCount] = ...
        st_inspect_verify_output_requirement(targetRow, cfg)
%ST_INSPECT_VERIFY_OUTPUT_REQUIREMENT Inspect the actual execution context.
% When verification is limited to Harness outputs, a target with no usable
% top-level Harness output signal legitimately has no verify result.
if ~logical(cfg.VerifyHarnessOutportsOnly)
    required = st_verify_results_required(false, 0);
    usableOutputCount = NaN;
    return;
end

timerValue = tic;
[executionModel, standalone] = execution_model(targetRow, cfg);
st_log(cfg, 'DEBUG', ...
    'Verify output inspection start | Model=%s | Standalone=%d', ...
    executionModel, standalone);

modelCleanup = [];
harnessCleanup = [];
if standalone
    openedModelHere = ~bdIsLoaded(executionModel);
    if openedModelHere
        modelFile = optional_text(targetRow, 'ExecutionModelFile');
        if isempty(modelFile)
            load_system(executionModel);
        else
            load_system(modelFile);
        end
        modelCleanup = onCleanup(@() close_model_quiet(executionModel, cfg));
    end
    harnessRoot = executionModel;
else
    openedModelHere = ~bdIsLoaded(cfg.TopModel);
    if openedModelHere
        load_system(cfg.TopModel);
        modelCleanup = onCleanup(@() close_model_quiet(cfg.TopModel, cfg));
    end
    ownerPath = st_normalize_cut_path(targetRow.CUTPath, cfg.TopModel);
    harnessName = char(string(targetRow.HarnessName));
    if ~bdIsLoaded(harnessName)
        sltest.harness.load(ownerPath, harnessName);
        harnessCleanup = onCleanup(@() close_harness_quiet( ...
            ownerPath, harnessName, cfg));
    end
    harnessRoot = harnessName;
end

outputs = st_collect_harness_output_signals(harnessRoot);
usableOutputCount = sum(strlength(outputs.SignalName) > 0);
required = st_verify_results_required(true, usableOutputCount);

st_log(cfg, 'DEBUG', ...
    ['Verify output inspection end | Model=%s | UsableOutputs=%d | ' ...
     'Required=%d | Elapsed=%.3f'], ...
    executionModel, usableOutputCount, required, toc(timerValue));

clear harnessCleanup;
clear modelCleanup;
end

function [model, standalone] = execution_model(row, cfg)
standalone = ismember('ExecutionModel', row.Properties.VariableNames) && ...
    strlength(strtrim(string(row.ExecutionModel))) > 0;
if standalone
    model = char(string(row.ExecutionModel));
else
    model = char(string(cfg.TopModel));
end
end

function value = optional_text(row, name)
value = '';
if ismember(name, row.Properties.VariableNames)
    candidate = strtrim(string(row.(name)));
    if isscalar(candidate) && ~ismissing(candidate)
        value = char(candidate);
    end
end
end

function close_harness_quiet(ownerPath, harnessName, cfg)
try
    sltest.harness.close(ownerPath, harnessName);
catch ME
    st_log(cfg, 'WARN', ...
        'Verify output inspection Harness close failed | Harness=%s | %s', ...
        harnessName, ME.message);
end
end

function close_model_quiet(model, cfg)
try
    if bdIsLoaded(model)
        close_system(model, 0);
    end
catch ME
    st_log(cfg, 'WARN', ...
        'Verify output inspection model close failed | Model=%s | %s', ...
        model, ME.message);
end
end
