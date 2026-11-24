function tests = test_final_document_defects
%TEST_FINAL_DOCUMENT_DEFECTS Defect iteration rows of the final document.
% No model is loaded. Row 1 of the fixture is the source scenario and row 2
% the defect iteration bound to it, as the specification collector gives
% them. st_final_document_defects reads target profiles and has no test
% here; it is checked on a real model.
tests = functiontests(localfunctions);
end

function testDefectRowUsesIterationNameForId(testCase)
specification = st_final_document_defect_rows(defect_specification(), ...
    sample_details(), defect_list("Secret_Switch", "Switch", "false", false), ...
    no_reasons(), base_config());
document = st_final_document_table(base_config(), specification, ...
    empty_outcomes(), empty_source());
verifyEqual(testCase, document.Sheet1.TestCaseID, ...
    ["UT_REQ_Secret_12345_001"; "UT_REQ_Secret_12345_004"]);
verifyEqual(testCase, document.Results.('Test Case ID'), document.Sheet1.TestCaseID);
verifyFalse(testCase, any(contains(document.Results.('확인 사유'), ...
    "DUPLICATE_TEST_CASE_ID")));
end

function testDescriptionKeepsOnlyTheTargetLineWithItsOutcome(testCase)
specification = st_final_document_defect_rows(defect_specification(), ...
    sample_details(), defect_list("Secret_Switch", "Switch", "false", false), ...
    no_reasons(), base_config());
verifyEqual(testCase, specification.DecisionBlocks(2), "D1 [F]Switch (u2 >= 1)");
% The source row keeps the whole list.
verifyEqual(testCase, specification.DecisionBlocks(1), rendered_description());
verifyEqual(testCase, specification.DefectCode, ["", "EXACT"]');

specification = st_final_document_defect_rows(defect_specification(), ...
    sample_details(), defect_list("Secret_Max", "MinMax", "input 1", false), ...
    no_reasons(), base_config());
verifyEqual(testCase, specification.DecisionBlocks(2), "D2 [input 1]Max");

% Several outcomes of one block share the bracket.
specification = st_final_document_defect_rows(defect_specification(), ...
    sample_details(), defect_list("Secret_Max", "MinMax", "input 1|input 2", false), ...
    no_reasons(), base_config());
verifyEqual(testCase, specification.DecisionBlocks(2), "D2 [input 1/input 2]Max");
end

function testBlockNameWithLineBreakStillFindsItsDLine(testCase)
% The model path keeps the newline of a default block name; the defect's
% relative path may carry other whitespace. Both are folded before the
% comparison, as the outcome lookup folds them.
details = sample_details();
details.Path(details.Path == "TOP/Secret/Secret_Switch") = ...
    "TOP/Secret/Secret" + newline + "Switch";
specification = st_final_document_defect_rows(defect_specification(), ...
    details, defect_list("Secret  Switch", "Switch", "false", false), ...
    no_reasons(), base_config());
verifyEqual(testCase, specification.DecisionBlocks(2), "D1 [F]Switch (u2 >= 1)");
end

function testNestedBlockWithoutDLineUsesPath(testCase)
specification = st_final_document_defect_rows(defect_specification(), ...
    sample_details(), defect_list("Sub/Secret_Switch", "Switch", "false", false), ...
    no_reasons(), base_config());
verifyEqual(testCase, specification.DecisionBlocks(2), ...
    "Switch [false] (Sub/Secret_Switch)");
end

function testExpectedAndOutputCells(testCase)
% The workbook has no reason sheet, so the fixed sentences are used.
cfg = reason_config(testCase, "", strings(1,0), strings(0,1), strings(0,1));
reasons = st_read_defect_reasons(cfg);
verifyEqual(testCase, height(reasons), 0);
specification = st_final_document_defect_rows(defect_specification(), ...
    sample_details(), defect_list("Secret_Switch", "Switch", "false", false), ...
    reasons, cfg);
document = st_final_document_table(cfg, specification, empty_outcomes(), ...
    empty_source());
verifyEqual(testCase, document.Sheet1.Description(2), "D1 [F]Switch (u2 >= 1)");
verifyEqual(testCase, document.Sheet1.ExpectedResult(2), ...
    "D1 [F]Switch (u2 >= 1)가 한 번 이상 실행된다");
verifyEqual(testCase, document.Sheet1.OutputValue(2), ...
    "SLDV가 어떤 입력으로도 실행할 수 없음을 증명함");
% The source row is untouched.
verifyEqual(testCase, document.Sheet1.ExpectedResult(1), "y == 1");
verifyEqual(testCase, document.Sheet1.OutputValue(1), "y == 1");

specification = st_final_document_defect_rows(defect_specification(), ...
    sample_details(), defect_list("Secret_Switch", "Switch", "false", true), ...
    reasons, cfg);
document = st_final_document_table(cfg, specification, empty_outcomes(), ...
    empty_source());
verifyEqual(testCase, document.Sheet1.OutputValue(2), ...
    "SLDV 근사 분석에서 실행할 수 없다고 판정함(확인 필요)");
end

function testReasonSheetTextWins(testCase)
cfg = reason_config(testCase, "DefectReasons", ["TestName", "Reason"], ...
    "UT_REQ_Secret_004", "입력 범위가 0 이하로 제한됨");
specification = st_final_document_defect_rows(defect_specification(), ...
    sample_details(), defect_list("Secret_Switch", "Switch", "false", false), ...
    st_read_defect_reasons(cfg), cfg);
document = st_final_document_table(cfg, specification, empty_outcomes(), ...
    empty_source());
verifyEqual(testCase, document.Sheet1.OutputValue(2), "입력 범위가 0 이하로 제한됨");
end

function testEmptyReasonCellsUseTheDefaultSentence(testCase)
% A Reason column with no text is read as double NaN; it must not reach the
% output value as "NaN".
cfg = reason_config(testCase, "DefectReasons", ["TestName", "Reason"], ...
    "UT_REQ_Secret_004", "");
reasons = st_read_defect_reasons(cfg);
verifyEqual(testCase, height(reasons), 0);
specification = st_final_document_defect_rows(defect_specification(), ...
    sample_details(), defect_list("Secret_Switch", "Switch", "false", false), ...
    reasons, cfg);
verifyEqual(testCase, specification.DefectReason(2), ...
    "SLDV가 어떤 입력으로도 실행할 수 없음을 증명함");
end

function testLowerCaseSheetNameIsRead(testCase)
cfg = reason_config(testCase, "defectreasons", ["TestName", "Reason"], ...
    "UT_REQ_Secret_004", "입력 범위가 0 이하로 제한됨");
reasons = st_read_defect_reasons(cfg);
verifyEqual(testCase, reasons.Reason, "입력 범위가 0 이하로 제한됨");
end

function testReasonSheetKoreanNamesAreRead(testCase)
cfg = reason_config(testCase, "도달불가사유", ["결함TC", "사유"], ...
    "UT_REQ_Secret_004", "입력 범위가 0 이하로 제한됨");
reasons = st_read_defect_reasons(cfg);
verifyEqual(testCase, reasons.TestName, "UT_REQ_Secret_004");
verifyEqual(testCase, reasons.Reason, "입력 범위가 0 이하로 제한됨");
end

function testReasonSheetUnknownAndDuplicateNamesWarn(testCase)
cfg = reason_config(testCase, "DefectReasons", ["TestName", "Reason"], ...
    ["UT_REQ_Secret_004"; "UT_REQ_Secret_004"; "UT_REQ_Secret_009"], ...
    ["첫 사유"; "둘째 사유"; "모르는 사유"]);
spec = defect_specification();
details = sample_details();
defects = defect_list("Secret_Switch", "Switch", "false", false);
output = evalc('readReasons = st_read_defect_reasons(cfg);');
verifyEqual(testCase, readReasons.Reason, ["첫 사유"; "모르는 사유"]);
verifyTrue(testCase, contains(output, "Defect reasons repeat a name"));
output = [output evalc( ...
    'rewritten = st_final_document_defect_rows(spec, details, defects, readReasons, cfg);')];
verifyEqual(testCase, rewritten.DefectReason(2), "첫 사유");
verifyTrue(testCase, contains(output, "Defect reasons name no defect iteration"));
% The console line gives counts and rows, never the names.
verifyFalse(testCase, contains(output, "Secret"));
end

function testMissingWorkbookGivesNoReasons(testCase)
cfg = base_config();
cfg.ManagementExcel = fullfile(tempdir, 'no_such_secret_workbook.xlsx');
output = evalc('missingReasons = st_read_defect_reasons(cfg);');
verifyEqual(testCase, height(missingReasons), 0);
verifyTrue(testCase, contains(output, "WARN"));
verifyFalse(testCase, contains(output, "secret"));
end

function testFailedExactDefectIsInformational(testCase)
document = judged_document(false, "Failed");
verifyEqual(testCase, document.Sheet1.Judgement(2), "FAIL");
verifyEqual(testCase, document.Results.('확인 사유')(2), "UNREACHABLE_DEFECT");
verifyEqual(testCase, document.Results.('확인 필요')(2), "");
% The source row is an ordinary passed row.
verifyEqual(testCase, document.Results.('확인 사유')(1), "");
end

function testApproximateDefectNeedsReview(testCase)
document = judged_document(true, "Failed");
verifyEqual(testCase, document.Results.('확인 사유')(2), ...
    "UNREACHABLE_DEFECT_APPROXIMATE");
verifyEqual(testCase, document.Results.('확인 필요')(2), "Y");
end

function testPassedDefectNeedsReview(testCase)
document = judged_document(false, "Passed");
verifyEqual(testCase, document.Results.('확인 사유')(2), "UNREACHABLE_DEFECT_PASSED");
verifyEqual(testCase, document.Results.('확인 필요')(2), "Y");
end

function testOrdinaryRowsUnchanged(testCase)
cfg = base_config();
specification = defect_specification();
outcomes = outcomes_with(["Secret_12345"; "Secret_12345"], ...
    ["UT_REQ_Secret_001"; "UT_REQ_Secret_004"], ["Passed"; "Failed"], ["", ""]);
rewritten = st_final_document_defect_rows(specification, sample_details(), ...
    no_defects(), no_reasons(), cfg);
verifyEqual(testCase, rewritten.DefectCode, ["", ""]');
verifyEqual(testCase, rewritten.DefectReason, ["", ""]');
verifyEqual(testCase, rewritten(:, specification.Properties.VariableNames), specification);
before = st_final_document_table(cfg, specification, outcomes, empty_source());
after = st_final_document_table(cfg, rewritten, outcomes, empty_source());
verifyEqual(testCase, after.Sheet1, before.Sheet1);
verifyEqual(testCase, after.Results, before.Results);
end


function document = judged_document(approximate, defectOutcome)
specification = st_final_document_defect_rows(defect_specification(), ...
    sample_details(), defect_list("Secret_Switch", "Switch", "false", approximate), ...
    no_reasons(), base_config());
outcomes = outcomes_with(["Secret_12345"; "Secret_12345"], ...
    ["UT_REQ_Secret_001"; "UT_REQ_Secret_004"], ["Passed"; defectOutcome], ["", ""]);
document = st_final_document_table(base_config(), specification, outcomes, ...
    empty_source());
end


function text = rendered_description()
% What st_format_specification_decision_blocks leaves in the cell.
text = "Secret_Switch" + newline + "D1 [T/F]Switch (u2 >= 1)" + newline + ...
    "Secret_Max" + newline + "D2 [T/F]Max";
end


function specification = defect_specification()
% Same shape as test_export_final_document's sample, two rows.
rows = strings(2,13);
rows(:,1) = "Secret_12345";
rows(:,2) = "Secret";
rows(:,3) = "Secret_Harness1";
rows(:,4) = "TOP_Secret_Harness1_HarnessInputs.mat";
rows(:,5) = "UT_REQ_Secret_001";
rows(:,6) = "u2: 1";
rows(:,8) = "TOP";
rows(:,9) = "TOP/Secret";
rows(:,10) = ["UT_REQ_Secret_001"; "UT_REQ_Secret_004"];
rows(:,11) = "UT_REQ_Secret_001";
rows(:,12) = "OK";
specification = st_specification_table(rows, {"y == 1"; "y == 1"}, ...
    [0.2; 0.2], repmat(rendered_description(), 2, 1));
end


function details = sample_details()
% The columns st_final_document_defect_rows reads from DecisionBlockDetails.
% Both specification rows (Excel rows 2 and 3) list the same two blocks.
details = table(["2"; "2"; "3"; "3"], ["D1"; "D2"; "D1"; "D2"], ...
    repmat(["TOP/Secret/Secret_Switch"; "TOP/Secret/Secret_Max"], 2, 1), ...
    'VariableNames', {'TestSpecificationRow','Decision','Path'});
end


function defects = defect_list(relativePath, blockType, outcomeTexts, approximate)
defects = table("Secret_12345", "UT_REQ_Secret_004", string(blockType), ...
    string(relativePath), string(outcomeTexts), logical(approximate), ...
    'VariableNames', {'TestCaseName','Name','BlockType','RelativePath', ...
    'OutcomeTexts','Approximate'});
end


function defects = no_defects()
defects = defect_list("x", "Switch", "false", false);
defects(1,:) = [];
end


function reasons = no_reasons()
reasons = table(strings(0,1), strings(0,1), 'VariableNames', {'TestName','Reason'});
end


function cfg = reason_config(testCase, sheet, headers, names, texts)
% A management workbook with a Targets sheet and, when SHEET is not empty,
% a reason sheet.
folder = tempname;
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
cfg = base_config();
cfg.DefectReasonSheet = 'DefectReasons';
cfg.ManagementExcel = fullfile(folder, 'targets.xlsx');
writetable(table("Secret", 'VariableNames', {'CUTName'}), cfg.ManagementExcel, ...
    'Sheet', 'Targets', 'UseExcel', false);
if strlength(sheet) > 0
    writetable(table(string(names(:)), string(texts(:)), ...
        'VariableNames', cellstr(headers)), cfg.ManagementExcel, ...
        'Sheet', char(sheet), 'UseExcel', false);
end
end


function cfg = base_config()
cfg = struct('VerboseLogging', false, 'FinalDocumentNAText', 'N/A', ...
    'OnlyEnabled', true);
end


function outcomes = empty_outcomes()
outcomes = struct('Iterations', outcome_rows(strings(0,1), strings(0,1), ...
    strings(0,1), strings(0,1)), 'Cases', outcome_rows(strings(0,1), ...
    strings(0,1), strings(0,1), strings(0,1)), 'Notes', note_table());
end


function outcomes = outcomes_with(testCaseName, iterationName, outcome, resultSet)
outcomes = empty_outcomes();
outcomes.Iterations = outcome_rows(testCaseName, iterationName, outcome, resultSet);
end


function T = outcome_rows(testCaseName, iterationName, outcome, resultSet)
testCaseName = string(testCaseName(:));
count = numel(testCaseName);
verdict = upper(string(outcome(:)));
verdict(verdict == "PASSED") = "PASS";
verdict(verdict == "FAILED") = "FAIL";
T = table(testCaseName, string(iterationName(:)), verdict, ...
    upper(string(outcome(:))), repmat("FINAL", count, 1), ...
    string(resultSet(:)), false(count,1), 'VariableNames', ...
    {'TestCaseName','IterationName','Verdict','Outcome','Stage','ResultSet','Ambiguous'});
end


function T = note_table()
T = table(zeros(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'No','TestCaseName','Reason','Message'});
end


function source = empty_source()
source = struct('Requested', 'AUTO', 'Mode', 'NONE', 'RunId', '', ...
    'RunDirectory', '', 'UpdatedAt', '', ...
    'Workbooks', workbook_table(), 'ResultSets', workbook_table(), ...
    'Notes', note_table());
end


function T = workbook_table()
T = table(strings(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'Stage','No','TestCaseName','File'});
end
