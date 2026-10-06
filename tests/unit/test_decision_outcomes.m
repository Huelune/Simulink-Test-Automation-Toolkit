function tests = test_decision_outcomes
%TEST_DECISION_OUTCOMES No model or simulation is required by these tests.
tests = functiontests(localfunctions);
end

function testIterationNamePrefersTheResultName(testCase)
verifyEqual(testCase, st_result_iteration_name(struct('Name', 'Scenario1'), 3), ...
    "Scenario1");
end

function testIterationNameFallsBackToTheScenarioThenTheIndex(testCase)
scenario = struct('Name', '', 'TestSequenceScenario', ...
    struct('TestSequenceScenario', 'Sc2'));
verifyEqual(testCase, st_result_iteration_name(scenario, 2), "Sc2");
verifyEqual(testCase, st_result_iteration_name(struct('Name', ''), 4), ...
    "Iteration 4");
end

function testRealIterationNameRejectsThePlaceholders(testCase)
verifyTrue(testCase, st_is_real_iteration_name("Iteration 1"));
placeholders = ["", " ", "<기본 설정>", "(단일 실행)", "연결 없음"];
verifyFalse(testCase, any(arrayfun(@st_is_real_iteration_name, placeholders)));
end
