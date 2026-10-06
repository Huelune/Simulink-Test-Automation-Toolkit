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

function testRelativePathIsKeyedBelowTheCut(testCase)
verifyEqual(testCase, st_cut_relative_path("TOP/CUT/Switch1", "TOP/CUT"), "Switch1");
verifyEqual(testCase, st_cut_relative_path("TOP/CUT", "TOP/CUT"), ".");
verifyEqual(testCase, st_cut_relative_path("TOP/Other/Switch1", "TOP/CUT"), "");
verifyEqual(testCase, st_cut_relative_path("TOP/CUTX/Switch1", "TOP/CUT"), "");
end

function testRelativePathCollapsesNewlinesAndTrailingSpaces(testCase)
verifyEqual(testCase, st_cut_relative_path( ...
    "TOP/CUT/For" + newline + "Iterator", "TOP/CUT"), "For Iterator");
verifyEqual(testCase, st_cut_relative_path("TOP/X /If1", "TOP/X "), "If1");
end

function testCountsKeepTrueAndFalsePerDecision(testCase)
description = struct('decision', [ ...
    fake_decision('if', ["true","false"], [3 0]), ...
    fake_decision('elseif', ["false","true"], [5 2])]);
[counts, texts] = st_decision_outcome_counts(description);
verifyEqual(testCase, counts, [3 0; 2 5]);
verifyEqual(testCase, texts, ["if"; "elseif"]);
end

function testCountsIgnoreOutcomeTextCase(testCase)
description = struct('decision', fake_decision('loop', ["False","TRUE"], [3 30]));
verifyEqual(testCase, st_decision_outcome_counts(description), [30 3]);
end

function testBlockWithAThreeWayDecisionIsNotDescribed(testCase)
description = struct('decision', fake_decision('max', ["in1","in2","in3"], [1 0 2]));
verifyEmpty(testCase, st_decision_outcome_counts(description));
end

function testBlockWithNonBooleanOutcomeTextIsNotDescribed(testCase)
description = struct('decision', fake_decision('relay', ["on","off"], [1 1]));
verifyEmpty(testCase, st_decision_outcome_counts(description));
end

function testOneNonBooleanDecisionDropsTheWholeBlock(testCase)
% Keeping only the two-way decision would shift the order the final
% document pairs D lines with.
description = struct('decision', [ ...
    fake_decision('a', ["true","false"], [1 1]), ...
    fake_decision('b', ["x","y"], [1 1])]);
verifyEmpty(testCase, st_decision_outcome_counts(description));
end

function testEmptyDescriptionIsNotDescribed(testCase)
verifyEmpty(testCase, st_decision_outcome_counts([]));
verifyEmpty(testCase, st_decision_outcome_counts(struct('decision', [])));
end

function testBothReportsWriteTheDecisionOutcomesSheet(testCase)
root = st_project_root();
for file = ["st_export_result_set_report.m", "st_generate_test_report.m"]
    source = fileread(fullfile(root, 'src', 'reporting', char(file)));
    verifyNotEmpty(testCase, regexp(source, ...
        "writetable\(decisionOutcomes, path, 'Sheet', 'DecisionOutcomes'\)", 'once'), ...
        char(file));
    verifyNotEmpty(testCase, regexp(source, 'st_collect_decision_outcomes\(', 'once'), ...
        char(file));
end
end

function testVerdictOnlyReportStillCollectsDecisionOutcomes(testCase)
% A LEAN collection writes only what the final document reads, and the
% final document reads this sheet, so it sits next to DecisionPoints,
% outside the verdict-only branch.
source = fileread(fullfile(st_project_root(), 'src', 'reporting', ...
    'st_export_result_set_report.m'));
verifyNotEmpty(testCase, regexp(source, ...
    ['decisionPoints = collect_decision_points\(resultObj, targetConfig, cfg\);\s*' ...
     'decisionOutcomes = st_collect_decision_outcomes\('], 'once'));
end

function d = fake_decision(text, outcomeTexts, executionCounts)
outcomes = struct('text', cellstr(outcomeTexts), ...
    'executionCount', num2cell(executionCounts));
d = struct('text', text, 'outcome', outcomes);
end
