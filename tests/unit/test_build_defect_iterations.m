function tests = test_build_defect_iterations
tests = functiontests(localfunctions);
end


function testGroupsByBlockAndNamesAfterLastScenario(testCase)
names = scenarios_for_test();
objectives = make_objectives( ...
    ["S2" "S1" "S2"], ["Switch" "Switch" "Switch"], ...
    ["Zeta" "Alpha" "Zeta"], [2 1 1], ["o2" "o1" "o1"], [false false true]);
defects = st_build_defect_iterations(objectives, names, "Secret_CUT", "");
verifyEqual(testCase, numel(defects), 2);
verifyEqual(testCase, defects(1).Name, st_scenario_name("Secret_CUT", 4));
verifyEqual(testCase, defects(2).Name, st_scenario_name("Secret_CUT", 5));
verifyEqual(testCase, defects(1).RelativePath, 'Alpha');
verifyEqual(testCase, numel(defects(1).Outcomes), 1);
verifyEqual(testCase, numel(defects(2).Outcomes), 2);
verifyEqual(testCase, [defects(2).Outcomes.Index], [1 2]);
end


function testEmptySelectorUsesLastScenario(testCase)
defects = st_build_defect_iterations(one_objective(), scenarios_for_test(), ...
    "Secret_CUT", "");
verifyEqual(testCase, defects.SourceScenario, st_scenario_name("Secret_CUT", 3));
verifyEqual(testCase, defects.SourceIndex, 3);
end


function testNumberAndNameSelectorsPickTheSameScenario(testCase)
byNumber = st_build_defect_iterations(one_objective(), scenarios_for_test(), ...
    "Secret_CUT", "2");
byName = st_build_defect_iterations(one_objective(), scenarios_for_test(), ...
    "Secret_CUT", st_scenario_name("Secret_CUT", 2));
verifyEqual(testCase, byNumber, byName);
verifyEqual(testCase, byNumber.SourceIndex, 2);
end


function testInvalidSourceSelectorIsRejected(testCase)
for selector = ["9" "abc" "0" "2.5"]
    verifyError(testCase, @() st_build_defect_iterations(one_objective(), ...
        scenarios_for_test(), "Secret_CUT", selector), ...
        'simtest:DefectInputScenarioInvalid');
end
try
    st_build_defect_iterations(one_objective(), scenarios_for_test(), ...
        "Secret_CUT", "9");
    verifyFail(testCase, 'selector 9 should have been rejected');
catch err
    verifySubstring(testCase, err.message, 'DefectInputScenario');
    verifySubstring(testCase, err.message, '1~3');
end
end


function testNoObjectivesGiveEmptyStructWithFields(testCase)
% A bad selector is not checked when there is no defect.
defects = st_build_defect_iterations(one_objective(false), ...
    scenarios_for_test(), "Secret_CUT", "abc");
verifyTrue(testCase, isempty(defects));
verifyTrue(testCase, isfield(defects, 'Outcomes'));
verifyEqual(testCase, size(defects), [0 1]);
profile = st_empty_sldv_profile();
verifyEqual(testCase, size(profile), [1 1]);
verifyEqual(testCase, size(profile.DefectIterations), [0 1]);
end


function testApproximateFlagIsKeptPerOutcome(testCase)
objectives = make_objectives(["S1" "S1"], ["Switch" "Switch"], ...
    ["A" "A"], [1 2], ["o1" "o2"], [true false]);
defects = st_build_defect_iterations(objectives, scenarios_for_test(), ...
    "Secret_CUT", "");
verifyEqual(testCase, [defects.Outcomes.Approximate], [true false]);
end


function names = scenarios_for_test()
names = {st_scenario_name("Secret_CUT", 1), st_scenario_name("Secret_CUT", 2), ...
    st_scenario_name("Secret_CUT", 3)};
end


function t = one_objective(nonEmpty)
if nargin < 1 || nonEmpty
    t = make_objectives("S1", "Switch", "A", 1, "o1", false);
else
    t = make_objectives(strings(0,1), strings(0,1), strings(0,1), ...
        zeros(0,1), strings(0,1), false(0,1));
end
end


function t = make_objectives(sid, blockType, relPath, idx, text, approx)
t = table(sid(:), blockType(:), relPath(:), idx(:), text(:), approx(:), ...
    'VariableNames', {'Sid','BlockType','RelativePath','OutcomeIndex', ...
    'OutcomeText','Approximate'});
end
