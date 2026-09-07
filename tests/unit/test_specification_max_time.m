function tests = test_specification_max_time
tests = functiontests(localfunctions);
end

function testOffUsesHarnessStopTimeEvenWhenInputHasTime(testCase)
[value, source, note] = st_specification_max_time('OFF', '0.25', 7);
verifyEqual(testCase, value, 0.25);
verifyEqual(testCase, source, "HARNESS_STOP_TIME");
verifyEqual(testCase, note, "");
end

function testSldvFileUsesLinkedInputTmax(testCase)
[value, source, note] = st_specification_max_time('FILE', '0.25', 7);
verifyEqual(testCase, value, 7);
verifyEqual(testCase, source, "INPUT_TMAX");
verifyEqual(testCase, note, "");
end

function testSldvGenerateUsesLinkedInputTmax(testCase)
[value, source] = st_specification_max_time("GENERATE", 0.25, 3.5);
verifyEqual(testCase, value, 3.5);
verifyEqual(testCase, source, "INPUT_TMAX");
end

function testSldvDoesNotFallBackToHarnessStopTime(testCase)
[value, source, note] = st_specification_max_time('FILE', '0.25', NaN);
verifyTrue(testCase, isnan(value));
verifyEqual(testCase, source, "INPUT_TMAX");
verifyTrue(testCase, contains(note, "unavailable"));
end

function testImportedHarnessSemanticsUseSolverStopTime(testCase)
[value, source] = st_specification_max_time('OFF', 1.5, NaN);
verifyEqual(testCase, value, 1.5);
verifyEqual(testCase, source, "HARNESS_STOP_TIME");
end

function testInvalidHarnessStopTimeProducesBlankValueAndNote(testCase)
[value, source, note] = st_specification_max_time('OFF', 'modelStopTime', 9);
verifyTrue(testCase, isnan(value));
verifyEqual(testCase, source, "HARNESS_STOP_TIME");
verifyTrue(testCase, contains(note, "finite nonnegative"));
end
