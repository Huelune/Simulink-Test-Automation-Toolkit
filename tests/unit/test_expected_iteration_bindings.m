function tests = test_expected_iteration_bindings
tests = functiontests(localfunctions);
end


function testScenariosBindToThemselves(testCase)
profile = make_profile('ON', {'S1'; 'S2'}, struct([]));
[names, bound] = st_expected_iteration_bindings(profile);
verifyEqual(testCase, names, {'S1'; 'S2'});
verifyEqual(testCase, bound, {'S1'; 'S2'});
end


function testDefectsBindTheirOwnScenario(testCase)
% st_get_sldv_profile has already appended the defect scenarios, copies of
% their source, so a defect iteration is listed once and binds itself.
defects = struct('Name', {'D3'; 'D4'}, 'SourceScenario', {'S2'; 'S1'});
profile = make_profile('ON', {'S1'; 'S2'; 'D3'; 'D4'}, defects);
[names, bound] = st_expected_iteration_bindings(profile);
verifyEqual(testCase, names, {'S1'; 'S2'; 'D3'; 'D4'});
verifyEqual(testCase, bound, {'S1'; 'S2'; 'D3'; 'D4'});
end


function testOffModeKeepsIteration1(testCase)
defects = struct('Name', {'D3'}, 'SourceScenario', {'S2'});
profile = make_profile('OFF', {'S1'; 'S2'}, defects);
[names, bound] = st_expected_iteration_bindings(profile);
verifyEqual(testCase, names, {'Iteration 1'});
verifyEqual(testCase, bound, {'S1'});
end


function testProfileWithoutDefectFieldBehavesAsBefore(testCase)
profile = struct('Mode', 'ON', 'ScenarioNames', {{'S1'; 'S2'}});
[names, bound] = st_expected_iteration_bindings(profile);
verifyEqual(testCase, names, {'S1'; 'S2'});
verifyEqual(testCase, bound, {'S1'; 'S2'});
end


function profile = make_profile(mode, scenarios, defects)
profile = struct('Mode', mode, 'ScenarioNames', {scenarios}, ...
    'DefectIterations', defects);
end
