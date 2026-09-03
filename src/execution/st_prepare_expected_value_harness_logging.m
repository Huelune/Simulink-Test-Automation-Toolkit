function st_prepare_expected_value_harness_logging(cfg, targetConfig)
%ST_PREPARE_EXPECTED_VALUE_HARNESS_LOGGING Enable source Harness logging.

T = targetConfig(targetConfig.ExpectedUpdateMode == "APPLY", :);
if isempty(T), return; end
if ~bdIsLoaded(cfg.TopModel), load_system(cfg.ModelFile); end
st_force_model_stopped(cfg.TopModel);
st_log(cfg, 'INFO', ...
    'Expected-value Harness logging start | targets=%d', height(T));
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
        st_log(cfg, 'ERROR', ...
            'Expected-value Harness logging failed | %s: %s', ...
            ME.identifier, ME.message);
        error('simtest:ExpectedLoggingPreparationFailed', ...
            'Expected value logging preparation failed [%s]: %s', ...
            harnessName, ME.message);
    end
end
st_log(cfg, 'INFO', ...
    'Expected-value Harness logging complete | targets=%d', height(T));
end

function close_harness_quiet(ownerPath, harnessName)
try, sltest.harness.close(ownerPath, harnessName); catch, end
end
