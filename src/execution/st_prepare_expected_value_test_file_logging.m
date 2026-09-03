function st_prepare_expected_value_test_file_logging(cfg, tf, targetConfig)
%ST_PREPARE_EXPECTED_VALUE_TEST_FILE_LOGGING Enable Test Case output logs.

T = targetConfig(targetConfig.ExpectedUpdateMode == "APPLY", :);
if isempty(T), return; end
expectedNames = string(T.TestCaseName);
suites = getTestSuites(tf);
for s = 1:numel(suites)
    if ~strcmp(char(string(suites(s).Name)), cfg.TestSuiteName), continue; end
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
st_log(cfg, 'DEBUG', ...
    'Expected-value Test File logging enabled | targets=%d', height(T));
end
