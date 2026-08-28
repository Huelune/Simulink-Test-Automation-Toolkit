function tests = test_expected_update_modes
tests = functiontests(localfunctions);
end


function testDefaultUsesGlobalOff(testCase)
actual = st_resolve_expected_update_modes( ...
    ["DEFAULT"; ""; string(missing)], ...
    'OFF');

verifyEqual(testCase, actual, ["OFF"; "OFF"; "OFF"]);
end


function testRowsOverrideGlobalDefault(testCase)
actual = st_resolve_expected_update_modes( ...
    ["DEFAULT"; "OFF"; "APPLY"], ...
    'APPLY');

verifyEqual(testCase, actual, ["APPLY"; "OFF"; "APPLY"]);
end


function testModesAreCaseAndWhitespaceInsensitive(testCase)
actual = st_resolve_expected_update_modes( ...
    [" apply "; "off"], ...
    'OFF');

verifyEqual(testCase, actual, ["APPLY"; "OFF"]);
end


function testReviewIsRejectedUntilImplemented(testCase)
verifyError( ...
    testCase, ...
    @() st_resolve_expected_update_modes("REVIEW", 'OFF'), ...
    'simtest:InvalidExpectedUpdateMode');
end
