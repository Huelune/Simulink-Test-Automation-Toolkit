function st_prepare_expected_value_logging_for_targets(cfg, tf, targetConfig)
%ST_PREPARE_EXPECTED_VALUE_LOGGING_FOR_TARGETS Enable logging for APPLY rows.

T = targetConfig(targetConfig.ExpectedUpdateMode == "APPLY", :);
if isempty(T)
    return;
end

for i = 1:height(T)
    [executionModel, standalone] = execution_model(T(i,:), cfg);
    ownerPath = '';
    harnessName = '';
    if standalone
        if ~bdIsLoaded(executionModel), load_system(executionModel); end
        st_force_model_stopped(executionModel);
        loggingRoot = executionModel;
    else
        if ~bdIsLoaded(cfg.TopModel), load_system(cfg.TopModel); end
        st_force_model_stopped(cfg.TopModel);
        ownerPath = st_normalize_cut_path(T.CUTPath(i), cfg.TopModel);
        harnessName = char(T.HarnessName(i));
        loggingRoot = harnessName;
    end
    try
        if ~standalone
            sltest.harness.load(ownerPath, harnessName);
        end
        logResult = st_enable_harness_output_logging(loggingRoot);
        if any(string(logResult.Status) == "FAIL")
            failed = logResult(string(logResult.Status) == "FAIL", :);
            error('simtest:ExpectedLoggingPreparationFailed', ...
                'Harness Outport logging failed: %s', ...
                char(strjoin(string(failed.Message), ' | ')));
        end
        save_system(executionModel);
        if ~standalone
            close_harness_quiet(ownerPath, harnessName);
        end
    catch ME
        if ~standalone
            close_harness_quiet(ownerPath, harnessName);
        end
        error('simtest:ExpectedLoggingPreparationFailed', ...
            'Expected value logging preparation failed [%s]: %s', ...
            executionModel, ME.message);
    end
end

expectedNames = string(T.TestCaseName);
suites = getTestSuites(tf);
for s = 1:numel(suites)
    if ~strcmp(char(string(suites(s).Name)), cfg.TestSuiteName)
        continue;
    end
    testCases = getTestCases(suites(s));
    for c = 1:numel(testCases)
        if any(string(testCases(c).Name) == expectedNames)
            setProperty(testCases(c), ...
                'OverrideModelOutputSettings', true, ...
                'SignalLogging', true);
        end
    end
end
saveToFile(tf);
end

function [model, standalone] = execution_model(row, cfg)
standalone = ismember('ExecutionModel', row.Properties.VariableNames) && ...
    strlength(strtrim(string(row.ExecutionModel))) > 0;
if standalone
    model = char(row.ExecutionModel);
else
    model = cfg.TopModel;
end
end


function close_harness_quiet(ownerPath, harnessName)
try
    sltest.harness.close(ownerPath, harnessName);
catch
end
end
