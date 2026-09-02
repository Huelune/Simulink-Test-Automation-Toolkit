function st_prepare_expected_value_logging_for_targets(cfg, tf, targetConfig)
%ST_PREPARE_EXPECTED_VALUE_LOGGING_FOR_TARGETS Enable logging for APPLY rows.

T = targetConfig(targetConfig.ExpectedUpdateMode == "APPLY", :);
if isempty(T)
    return;
end

if ~bdIsLoaded(cfg.TopModel)
    load_system(cfg.TopModel);
end
st_force_model_stopped(cfg.TopModel);

for i = 1:height(T)
    ownerPath = st_normalize_cut_path(T.CUTPath(i), cfg.TopModel);
    harnessName = char(T.HarnessName(i));
    try
        sltest.harness.load(ownerPath, harnessName);
        logResult = st_enable_harness_output_logging(harnessName);
        if any(string(logResult.Status) == "FAIL")
            failed = logResult(string(logResult.Status) == "FAIL", :);
            error('simtest:ExpectedLoggingPreparationFailed', ...
                'Harness Outport logging failed: %s', ...
                char(strjoin(string(failed.Message), ' | ')));
        end
        save_system(cfg.TopModel);
        close_harness_quiet(ownerPath, harnessName);
    catch ME
        close_harness_quiet(ownerPath, harnessName);
        error('simtest:ExpectedLoggingPreparationFailed', ...
            'Expected value logging preparation failed [%s]: %s', ...
            harnessName, ME.message);
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


function close_harness_quiet(ownerPath, harnessName)
try
    sltest.harness.close(ownerPath, harnessName);
catch
end
end
