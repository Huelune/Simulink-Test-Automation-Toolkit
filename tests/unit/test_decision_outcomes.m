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

function testCountsAcceptOutcomeTextsThatGoOnAfterTrueOrFalse(testCase)
% Simulink Coverage names the port a Switch passes after the word.
description = struct('decision', fake_decision('switch', ...
    ["true (output is from 1st input port)", "false (output is from 3rd input port)"], ...
    [4 1]));
verifyEqual(testCase, st_decision_outcome_counts(description), [4 1]);
end

function testCountsRejectWordsThatOnlyBeginWithTrueOrFalse(testCase)
description = struct('decision', fake_decision('x', ["trueish","falsehood"], [1 1]));
verifyEmpty(testCase, st_decision_outcome_counts(description));
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

function testLookupReadsCountsInDecisionOrder(testCase)
file = outcome_workbook(testCase, ...
    ["FINAL","FINAL","FINAL"], ["UNIT","DECISION","DECISION"], ...
    ["","If1","If1"], [0 1 2], [0 3 0], [0 0 4]);
outcomes = st_final_document_decision_outcomes(base_config(), source_with(file, "ANY"));
found = outcomes.Lookup("Case1", "Iteration 1", "If1");
verifyTrue(testCase, found.UnitFound);
verifyEqual(testCase, found.Counts, [3 0; 0 4]);
verifyEqual(testCase, outcomes.Units, 1);
end

function testBatchWorkbookPrefersTheFinalRows(testCase)
file = outcome_workbook(testCase, ...
    ["INITIAL","INITIAL","FINAL","FINAL"], ["UNIT","DECISION","UNIT","DECISION"], ...
    ["","Sw","","Sw"], [0 1 0 1], [0 1 0 0], [0 0 0 7]);
outcomes = st_final_document_decision_outcomes(base_config(), source_with(file, "ANY"));
found = outcomes.Lookup("Case1", "Iteration 1", "Sw");
verifyEqual(testCase, found.Counts, [0 7]);
end

function testPlaceholderIterationIsLookedUpAtTheTestCaseLevel(testCase)
file = outcome_workbook(testCase, ["FINAL","FINAL"], ["UNIT","DECISION"], ...
    ["","Sw"], [0 1], [0 2], [0 0], ["",""]);
outcomes = st_final_document_decision_outcomes(base_config(), source_with(file, "ANY"));
found = outcomes.Lookup("Case1", "<기본 설정>", "Sw");
verifyTrue(testCase, found.UnitFound);
verifyEqual(testCase, found.Counts, [2 0]);
end

function testLookupMatchesBlockNamesWithNewlines(testCase)
file = outcome_workbook(testCase, ["FINAL","FINAL"], ["UNIT","DECISION"], ...
    ["","For Iterator"], [0 1], [0 1], [0 1]);
outcomes = st_final_document_decision_outcomes(base_config(), source_with(file, "ANY"));
found = outcomes.Lookup("Case1", "Iteration 1", "For" + newline + "Iterator");
verifyEqual(testCase, found.Counts, [1 1]);
end

function testWorkbookWithoutTheSheetMarksRowsUnavailable(testCase)
folder = tempname; mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
file = fullfile(folder, 'TestSummary.xlsx');
writetable(table("x"), file, 'Sheet', 'Iterations', 'UseExcel', false);
outcomes = st_final_document_decision_outcomes(base_config(), source_with(file, "ANY"));
[formatted, ~, reasons] = st_format_specification_decision_blocks( ...
    one_row_specification(switch_item("TOP/CUT/Sw")), base_config(), outcomes.Lookup);
verifyEqual(testCase, formatted.DecisionBlocks(1), "Sw" + newline + "D1 [T/F]Switch (u > 0)");
verifyEqual(testCase, reasons(1), "DECISION_OUTCOME_UNAVAILABLE");
end

function testWorkbookWithABadRowIsSkippedWhole(testCase)
% DecisionIndex 0 cannot be placed. The export goes on, and the UNIT row
% of the same workbook is dropped too, so the row reads as unavailable
% rather than as "scanned, no two-way branch".
file = outcome_workbook(testCase, ["FINAL","FINAL"], ["UNIT","DECISION"], ...
    ["","If1"], [0 0], [0 3], [0 0]);
outcomes = st_final_document_decision_outcomes(base_config(), source_with(file, "ANY"));
verifyEqual(testCase, outcomes.Units, 0);
found = outcomes.Lookup("Case1", "Iteration 1", "If1");
verifyFalse(testCase, found.UnitFound);
verifyEmpty(testCase, found.Counts);
end

function testFormatterWritesTheActualOutcome(testCase)
lookup = fake_lookup(struct('Sw', [4 0]));
[formatted, ~, reasons] = st_format_specification_decision_blocks( ...
    one_row_specification(switch_item("TOP/CUT/Sw")), base_config(), lookup);
verifyEqual(testCase, formatted.DecisionBlocks(1), "Sw" + newline + "D1 [T]Switch (u > 0)");
verifyEqual(testCase, reasons(1), "");
end

function testFormatterLabelsEveryCombination(testCase)
items = [if_item("TOP/CUT/If1", "a > 0"); if_item("TOP/CUT/If1", "elseif b > 0"); ...
    switch_item("TOP/CUT/Sw"); switch_item("TOP/CUT/Sw2")];
lookup = fake_lookup(struct('If1', [1 1; 0 0], 'Sw', [0 2], 'Sw2', [5 5]));
formatted = st_format_specification_decision_blocks( ...
    one_row_specification(items), base_config(), lookup);
lines = split(formatted.DecisionBlocks(1), newline);
verifyEqual(testCase, lines, ["If1"; "D1 [T/F]IF (a > 0)"; "D2 [-]IF (elseif b > 0)"; ...
    "Sw"; "D3 [F]Switch (u > 0)"; "Sw2"; "D4 [T/F]Switch (u > 0)"]);
end

function testCountMismatchKeepsTheStaticMarkAndSaysSo(testCase)
items = [if_item("TOP/CUT/If1", "a > 0"); if_item("TOP/CUT/If1", "elseif b > 0")];
lookup = fake_lookup(struct('If1', [1 0]));
[formatted, ~, reasons] = st_format_specification_decision_blocks( ...
    one_row_specification(items), base_config(), lookup);
verifyEqual(testCase, count(formatted.DecisionBlocks(1), "[T/F]"), 2);
verifyEqual(testCase, reasons(1), "DECISION_OUTCOME_MISMATCH");
end

function testBlockWithoutTwoWayDecisionsKeepsTheStaticMarkSilently(testCase)
% MinMax selects among inputs, so its outcomes are not true/false.
item = struct('BlockType', 'MinMax', 'Name', 'Mx', 'Path', 'TOP/CUT/Mx', ...
    'Outcome', 'SELECT', 'Expression', 'max; Inputs=3', 'ExpressionStatus', 'OK', 'Message', '');
lookup = fake_lookup(struct());
[formatted, ~, reasons] = st_format_specification_decision_blocks( ...
    one_row_specification(item), base_config(), lookup);
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D1 [T/F]MinMax"));
verifyEqual(testCase, reasons(1), "");
end

function testTwoWayBlockScannedWithoutCountsSaysUnavailable(testCase)
% The unit was scanned but nothing was recorded for a Switch. A silent
% [T/F] would read as "both taken".
lookup = fake_lookup(struct());
[formatted, ~, reasons] = st_format_specification_decision_blocks( ...
    one_row_specification(switch_item("TOP/CUT/Sw")), base_config(), lookup);
verifyEqual(testCase, formatted.DecisionBlocks(1), "Sw" + newline + "D1 [T/F]Switch (u > 0)");
verifyEqual(testCase, reasons(1), "DECISION_OUTCOME_UNAVAILABLE");
end

function testBlockTypeOutsideTheTwoWaySetIsNeverLookedUp(testCase)
% MinMax is not a true/false block, so asking would pair its outcomes as a
% mismatch on every row. The type alone keeps it out.
item = struct('BlockType', 'MinMax', 'Name', 'Mx', 'Path', 'TOP/CUT/Mx', ...
    'Outcome', 'SELECT', 'Expression', 'max; Inputs=3', 'ExpressionStatus', 'OK', 'Message', '');
calls = 0;
[formatted, ~, reasons] = st_format_specification_decision_blocks( ...
    one_row_specification(item), base_config(), @counting_lookup);
verifyEqual(testCase, calls, 0);
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D1 [T/F]MinMax"));
verifyEqual(testCase, reasons(1), "");

    function found = counting_lookup(~, ~, ~)
        calls = calls + 1;
        found = struct('UnitFound', true, 'Counts', [1 0; 0 1]);
    end
end

function testConditionalCutIsLookedUpAsDot(testCase)
item = struct('BlockType', 'EnablePort', 'Name', 'CUT', 'Path', 'TOP/CUT', ...
    'Outcome', 'ON/OFF', 'Expression', 'enable', 'ExpressionStatus', 'OK', 'Message', '');
lookup = fake_lookup(containers.Map({'.'}, {[0 9]}));
formatted = st_format_specification_decision_blocks( ...
    one_row_specification(item), base_config(), lookup);
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D1 [F]Enable"));
end

function testFormatterWithoutALookupIsUnchanged(testCase)
specification = one_row_specification(switch_item("TOP/CUT/Sw"));
[formatted, ~, reasons] = st_format_specification_decision_blocks(specification, base_config());
verifyEqual(testCase, formatted.DecisionBlocks(1), "Sw" + newline + "D1 [T/F]Switch (u > 0)");
verifyEqual(testCase, reasons(1), "");
end

function testFinalDocumentWiresTheOutcomes(testCase)
source = fileread(fullfile(st_project_root(), 'src', 'exporting', ...
    'st_export_final_document.m'));
verifyNotEmpty(testCase, regexp(source, 'st_final_document_decision_outcomes\(cfg, source\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'st_final_document_table\(cfg, specification, outcomes, source, outcomeReasons\)', 'once'));
end

function testLookupReturnsRecordedDecisionTexts(testCase)
file = outcome_workbook(testCase, ["FINAL","FINAL","FINAL"], ...
    ["UNIT","DECISION","DECISION"], ["","Sat","Sat"], [0 1 2], [0 3 0], [0 0 4], ...
    [], ["","U >= LL","U  > UL"]);
outcomes = st_final_document_decision_outcomes(base_config(), source_with(file, "ANY"));
found = outcomes.Lookup("Case1", "Iteration 1", "Sat");
verifyEqual(testCase, found.Counts, [3 0; 0 4]);
verifyEqual(testCase, found.Texts, ["U >= LL"; "U > UL"]);
end

function testTextPairingFollowsTextNotOrder(testCase)
% Coverage lists the lower limit first. Recorded in the opposite order of
% the D lines, each result must still land on its own line.
lookup = fake_text_lookup("Sat", [0 5; 7 0], ["U > UL"; "U >= LL"]);
formatted = st_format_specification_decision_blocks( ...
    one_row_specification(saturate_items()), base_config(), lookup);
verifyEqual(testCase, split(formatted.DecisionBlocks(1), newline), ...
    ["Sat"; "D1 [T]Saturate (U >= LL; LowerLimit=-32)"; ...
     "D2 [F]Saturate (U > UL; UpperLimit=32)"]);
end

function testTextPairingIgnoresSpacingAndCase(testCase)
lookup = fake_text_lookup("Sat", [1 1; 0 0], ["u  >=  ll"; "U > UL"]);
formatted = st_format_specification_decision_blocks( ...
    one_row_specification(saturate_items()), base_config(), lookup);
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D1 [T/F]Saturate (U >= LL"));
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D2 [-]Saturate (U > UL"));
end

function testRepeatedTextKeepsStaticMarkAndSaysMismatch(testCase)
% A vector input gives each element its own decision with the same text.
lookup = fake_text_lookup("Sat", [1 0; 1 0; 0 1; 0 1], ...
    ["U >= LL"; "U >= LL"; "U > UL"; "U > UL"]);
[formatted, ~, reasons] = st_format_specification_decision_blocks( ...
    one_row_specification(saturate_items()), base_config(), lookup);
verifyEqual(testCase, count(formatted.DecisionBlocks(1), "[T/F]"), 2);
verifyEqual(testCase, reasons(1), "DECISION_OUTCOME_MISMATCH");
end

function testRecordedDecisionWithoutALineIsAMismatch(testCase)
% The D list has only the reset branch, but the run recorded an enable
% decision too (the setting changed after the export).
item = struct('BlockType', 'Delay', 'Name', 'Dly', 'Path', 'TOP/CUT/Dly', ...
    'Outcome', 'RESET', 'Expression', 'Reset; ExternalReset=Rising', ...
    'CoverageText', 'Reset', 'ExpressionStatus', 'OK', 'Message', '');
lookup = fake_text_lookup("Dly", [1 1; 2 3], ["Enable"; "Reset"]);
[formatted, ~, reasons] = st_format_specification_decision_blocks( ...
    one_row_specification(item), base_config(), lookup);
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D1 [T/F]Delay"));
verifyEqual(testCase, reasons(1), "DECISION_OUTCOME_MISMATCH");
end

function testLinesWithoutCoverageTextStillPairByPosition(testCase)
% If has no coverage text on its lines; its order was confirmed at runtime.
items = [if_item("TOP/CUT/If1", "a > 0"); if_item("TOP/CUT/If1", "elseif b > 0")];
lookup = fake_lookup(struct('If1', [1 0; 0 1]));
formatted = st_format_specification_decision_blocks( ...
    one_row_specification(items), base_config(), lookup);
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D1 [T]IF (a > 0)"));
verifyTrue(testCase, contains(formatted.DecisionBlocks(1), "D2 [F]IF (elseif b > 0)"));
end

function items = saturate_items()
items = [ ...
    struct('BlockType', 'Saturate', 'Name', 'Sat', 'Path', 'TOP/CUT/Sat', ...
        'Outcome', 'LIMIT', 'Expression', 'U >= LL; LowerLimit=-32', ...
        'CoverageText', 'U >= LL', 'ExpressionStatus', 'OK', 'Message', ''); ...
    struct('BlockType', 'Saturate', 'Name', 'Sat', 'Path', 'TOP/CUT/Sat', ...
        'Outcome', 'LIMIT', 'Expression', 'U > UL; UpperLimit=32', ...
        'CoverageText', 'U > UL', 'ExpressionStatus', 'OK', 'Message', '')];
end

function lookup = fake_text_lookup(relative, counts, texts)
% One scanned unit with one recorded block; any other path has no counts.
lookup = @(~, ~, asked) text_lookup_result(string(asked) == string(relative), counts, texts);
end

function result = text_lookup_result(matches, counts, texts)
result = struct('UnitFound', true, 'Counts', zeros(0,2), 'Texts', strings(0,1));
if matches
    result.Counts = counts;
    result.Texts = texts;
end
end

function cfg = base_config()
cfg = struct('VerboseLogging', false);
end

function source = source_with(file, stage)
source = struct('Mode', 'BATCH', 'Workbooks', table(string(stage), 0, "", ...
    string(file), 'VariableNames', {'Stage','No','TestCaseName','File'}));
end

function file = outcome_workbook(testCase, runs, kinds, paths, indices, trues, falses, iterations, texts)
if nargin < 8 || isempty(iterations)
    iterations = repmat("Iteration 1", 1, numel(runs));
end
if nargin < 9
    texts = repmat("", 1, numel(runs));
end
folder = tempname; mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
file = fullfile(folder, 'TestSummary.xlsx');
count = numel(runs);
writetable(table(runs(:), repmat("CUT", count, 1), repmat("Case1", count, 1), ...
    iterations(:), kinds(:), paths(:), indices(:), texts(:), ...
    trues(:), falses(:), 'VariableNames', {'Run','CUTName','TestCaseName', ...
    'IterationName','Kind','RelativePath','DecisionIndex','DecisionText', ...
    'TrueCount','FalseCount'}), file, 'Sheet', 'DecisionOutcomes', 'UseExcel', false);
end

function lookup = fake_lookup(counts)
% counts maps a relative path to its [True False] matrix. The unit is
% always found, as if the row was scanned.
if isstruct(counts)
    keys = fieldnames(counts);
    values = struct2cell(counts);
    if isempty(keys)
        counts = containers.Map('KeyType', 'char', 'ValueType', 'any');
    else
        counts = containers.Map(keys, values);
    end
end
lookup = @(~, ~, relative) struct('UnitFound', true, ...
    'Counts', value_or_empty(counts, char(relative)));
end

function value = value_or_empty(map, key)
value = zeros(0,2);
if isKey(map, key), value = map(key); end
end

function item = switch_item(path)
[~, name] = fileparts(path);
item = struct('BlockType', 'Switch', 'Name', name, 'Path', char(path), ...
    'Outcome', 'T/F', 'Expression', 'u > 0', 'ExpressionStatus', 'OK', 'Message', '');
end

function item = if_item(path, expression)
[~, name] = fileparts(path);
item = struct('BlockType', 'If', 'Name', name, 'Path', char(path), ...
    'Outcome', 'T/F', 'Expression', char(expression), 'ExpressionStatus', 'OK', 'Message', '');
end

function specification = one_row_specification(items)
raw = string(jsonencode(items(:)));
specification = table("Case1", "TOP/CUT", "Iteration 1", raw, 'VariableNames', ...
    {'테스트 케이스명', 'CUTPath', 'Iteration명', 'DecisionBlocks'});
end
