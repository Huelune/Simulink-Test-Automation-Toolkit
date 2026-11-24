function tests = test_find_iteration_result
tests = functiontests(localfunctions);
end


function testDefectBeforeOriginalIsNotPicked(testCase)
% A defect iteration binds the source scenario, but its own name differs.
iterations = [make_iteration('UT_REQ_Secret_004', 'UT_REQ_Secret_001'), ...
    make_iteration('UT_REQ_Secret_001', 'UT_REQ_Secret_001')];
verifyEqual(testCase, st_find_iteration_result(iterations, 'UT_REQ_Secret_001', false), 2);
verifyEqual(testCase, st_find_iteration_result(iterations, 'UT_REQ_Secret_004', false), 1);
end


function testOffModeFallsBackToScenarioBinding(testCase)
iterations = make_iteration('Iteration 1', 'UT_REQ_Secret_001');
verifyEqual(testCase, st_find_iteration_result(iterations, 'UT_REQ_Secret_001', false), 1);
end


function testNothingMatchesReturnsZero(testCase)
iterations = make_iteration('Iteration 1', 'UT_REQ_Secret_001');
verifyEqual(testCase, st_find_iteration_result(iterations, 'UT_REQ_Secret_009', false), 0);
verifyEqual(testCase, st_find_iteration_result(struct('Name', {}, 'TestSequenceScenario', {}), ...
    'UT_REQ_Secret_001', true), 0);
end


function testFallbackReturnsLastIteration(testCase)
iterations = [make_iteration('Iteration 1', 'A'), make_iteration('Iteration 2', 'B')];
verifyEqual(testCase, st_find_iteration_result(iterations, 'Z', true), 2);
end


function item = make_iteration(name, scenario)
item = struct('Name', name, ...
    'TestSequenceScenario', struct('TestSequenceScenario', scenario));
end
