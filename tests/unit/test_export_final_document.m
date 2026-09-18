function tests = test_export_final_document
%TEST_EXPORT_FINAL_DOCUMENT No model simulation is required by these tests.
tests = functiontests(localfunctions);
end

function testCombinedIdentifierPutsScenarioAndTestCaseOnTwoLines(testCase)
specification = sample_specification();
document = st_final_document_table(base_config(), specification, ...
    empty_outcomes(), empty_source(), 'COMBINED');
verifyEqual(testCase, document.Sheet1.TestCaseID(1), ...
    "UT_REQ_CUT_NAME_001" + newline + "Controller_TC");
verifyEqual(testCase, document.DisplayHeaders, {'Test Case ID', '-', '-', ...
    'Pre Condition', 'Description', 'Test Steps.Action', ...
    'Test Steps.Expected result', '-', '-', '-', '-', '출력값', ...
    '판정 결과', '테스트 자료'});
end

function testScenarioIdentifierKeepsTheScenarioNameOnly(testCase)
specification = sample_specification();
document = st_final_document_table(base_config(), specification, ...
    empty_outcomes(), empty_source(), 'SCENARIO');
verifyEqual(testCase, document.Sheet1.TestCaseID(1), "UT_REQ_CUT_NAME_001");
end

function testOutputValueRepeatsTheExpectedResult(testCase)
specification = sample_specification();
document = st_final_document_table(base_config(), specification, ...
    empty_outcomes(), empty_source(), '');
verifyEqual(testCase, document.Sheet1.OutputValue, document.Sheet1.ExpectedResult);
end

function testNotApplicableTextBecomesTheSharedNAWording(testCase)
specification = sample_specification();
specification.("하네스 input 파일명")(1) = "해당 없음";
specification.("input 시나리오 내용")(1) = "해당 없음";
document = st_final_document_table(base_config(), specification, ...
    empty_outcomes(), empty_source(), '');
verifyEqual(testCase, document.Sheet1.TestData(1), "N/A");
verifyEqual(testCase, document.Sheet1.Action(1), "N/A");
end

function testFailedIterationIsFlaggedWithTheResultSetToOpen(testCase)
specification = sample_specification();
outcomes = outcomes_with("Controller_TC", "Iteration 1", "Failed", ...
    "D:\run\targets\001\final\Results.mldatx");
document = st_final_document_table(base_config(), specification, outcomes, ...
    empty_source(), '');
verifyEqual(testCase, document.Sheet1.Judgement(1), "FAIL");
verifyEqual(testCase, document.Results.('확인 필요')(1), "Y");
verifyEqual(testCase, document.Results.('확인 위치')(1), ...
    "D:\run\targets\001\final\Results.mldatx");
verifyTrue(testCase, contains(document.Results.('확인 사유')(1), "FAILED"));
end

function testPassedIterationIsNotFlagged(testCase)
specification = sample_specification();
outcomes = outcomes_with("Controller_TC", "Iteration 1", "Passed", "");
document = st_final_document_table(base_config(), specification, outcomes, ...
    empty_source(), '');
verifyEqual(testCase, document.Sheet1.Judgement(1), "PASS");
verifyEqual(testCase, document.Results.('확인 필요')(1), "");
end

function testUnknownOutcomeTokenIsWrittenThroughInUpperCase(testCase)
specification = sample_specification();
outcomes = outcomes_with("Controller_TC", "Iteration 1", "Incomplete", "");
document = st_final_document_table(base_config(), specification, outcomes, ...
    empty_source(), '');
verifyEqual(testCase, document.Sheet1.Judgement(1), "INCOMPLETE");
verifyTrue(testCase, contains(document.Results.('확인 사유')(1), ...
    "NOT_PASSED:INCOMPLETE"));
end

function testMissingResultLeavesTheVerdictBlankAndSaysWhy(testCase)
specification = sample_specification();
document = st_final_document_table(base_config(), specification, ...
    empty_outcomes(), empty_source(), '');
verifyEqual(testCase, document.Sheet1.Judgement(1), "");
verifyTrue(testCase, contains(document.Results.('확인 사유')(1), ...
    "NO_MATCHING_TEST_RESULT"));
end

function testIterationWithoutAUsableNameFallsBackToTheTestCase(testCase)
specification = sample_specification();
specification.("Iteration명")(1) = "<기본 설정>";
outcomes = empty_outcomes();
outcomes.Cases = outcome_rows("Controller_TC", "", "Passed", "");
document = st_final_document_table(base_config(), specification, outcomes, ...
    empty_source(), '');
verifyEqual(testCase, document.Sheet1.Judgement(1), "PASS");
verifyTrue(testCase, contains(document.Results.('확인 사유')(1), ...
    "ITERATION_MATCHED_BY_TEST_CASE"));
end

function testConflictingDuplicateResultsAreNotResolvedBySilentChoice(testCase)
specification = sample_specification();
outcomes = empty_outcomes();
outcomes.Iterations = [outcome_rows("Controller_TC", "Iteration 1", "Passed", ""); ...
    outcome_rows("Controller_TC", "Iteration 1", "Failed", "")];
outcomes.Iterations.Ambiguous(:) = true;
document = st_final_document_table(base_config(), specification, outcomes, ...
    empty_source(), '');
verifyEqual(testCase, document.Sheet1.Judgement(1), "");
verifyTrue(testCase, contains(document.Results.('확인 사유')(1), ...
    "AMBIGUOUS_TEST_RESULT"));
end


function testAutoPrefersTheNewerPointerAndIgnoresTheCopiedSummary(testCase)
% The regression this design exists for: result/TestSummary.xlsx is
% refreshed by BATCH only, so reading it after a PER_CUT run reports the
% previous BATCH numbers without saying anything.
folder = temp_folder(testCase);
cfg = pointer_config(folder);
write_json(cfg.LatestReportPointer, struct('Version', 1, 'RunId', 'batch-1', ...
    'RunDirectory', fullfile(folder, 'test_runs', 'batch-1'), ...
    'UpdatedAt', '2026-09-18 10:00:00.000'));
batchDirectory = fullfile(folder, 'test_runs', 'batch-1');
mkdir(batchDirectory);
write_iterations(fullfile(batchDirectory, 'TestSummary.xlsx'), ...
    ["INITIAL";"FINAL"], ["Controller_TC";"Controller_TC"], ...
    ["Iteration 1";"Iteration 1"], ["Passed";"Passed"]);
runDirectory = write_per_cut_run(folder, 'per-cut-1', 'Passed', true);
write_json(cfg.PerCutLatestPointer, struct('Version', 1, 'RunId', 'per-cut-1', ...
    'RunDirectory', runDirectory, ...
    'Manifest', fullfile(runDirectory, 'manifest.json'), ...
    'UpdatedAt', '2026-09-18 11:00:00.000'));

source = st_final_document_run_source(cfg, 'AUTO');
verifyEqual(testCase, source.Mode, 'PER_CUT');
verifyEqual(testCase, source.RunId, 'per-cut-1');
verifyFalse(testCase, any(contains(source.Workbooks.File, 'test_runs')));
verifyFalse(testCase, any(contains(source.Workbooks.File, ...
    fullfile(folder, 'TestSummary.xlsx'))));
end

function testAutoPicksTheBatchRunWhenItIsTheNewerOne(testCase)
folder = temp_folder(testCase);
cfg = pointer_config(folder);
runDirectory = write_per_cut_run(folder, 'per-cut-1', 'Passed', true);
write_json(cfg.PerCutLatestPointer, struct('Version', 1, 'RunId', 'per-cut-1', ...
    'RunDirectory', runDirectory, ...
    'Manifest', fullfile(runDirectory, 'manifest.json'), ...
    'UpdatedAt', '2026-09-18 09:00:00.000'));
batchDirectory = fullfile(folder, 'test_runs', 'batch-1');
mkdir(batchDirectory);
write_iterations(fullfile(batchDirectory, 'TestSummary.xlsx'), ...
    "FINAL", "Controller_TC", "Iteration 1", "Passed");
write_json(cfg.LatestReportPointer, struct('Version', 1, 'RunId', 'batch-1', ...
    'RunDirectory', batchDirectory, 'UpdatedAt', '2026-09-18 12:00:00.000'));

source = st_final_document_run_source(cfg, 'AUTO');
verifyEqual(testCase, source.Mode, 'BATCH');
verifyEqual(testCase, source.RunId, 'batch-1');
end

function testNoRunHistoryIsNotFatalAndSaysSo(testCase)
folder = temp_folder(testCase);
source = st_final_document_run_source(pointer_config(folder), 'AUTO');
verifyEqual(testCase, source.Mode, 'NONE');
verifyTrue(testCase, any(source.Notes.Reason == "NO_RESULT_RUN"));
end

function testExplicitBatchWithoutHistoryIsFatal(testCase)
folder = temp_folder(testCase);
cfg = pointer_config(folder);
verifyError(testCase, @() st_final_document_run_source(cfg, 'BATCH'), ...
    'simtest:FinalDocumentResultRunMissing');
verifyError(testCase, @() st_final_document_run_source(cfg, 'PER_CUT'), ...
    'simtest:FinalDocumentResultRunMissing');
end

function testPerCutUsesTheRecordedTargetDirectoryWithoutFinalReport(testCase)
% FinalReport and InitialReport stay empty on the default DEFERRED path, so
% the resolver has to reach the workbook through TargetManifest.
folder = temp_folder(testCase);
cfg = pointer_config(folder);
runDirectory = write_per_cut_run(folder, 'per-cut-1', 'Failed', true);
write_json(cfg.PerCutLatestPointer, struct('Version', 1, 'RunId', 'per-cut-1', ...
    'RunDirectory', runDirectory, ...
    'Manifest', fullfile(runDirectory, 'manifest.json'), ...
    'UpdatedAt', '2026-09-18 11:00:00.000'));
source = st_final_document_run_source(cfg, 'PER_CUT');
verifyEqual(testCase, height(source.Workbooks), 1);
verifyEqual(testCase, source.Workbooks.Stage(1), "FINAL");
verifyTrue(testCase, endsWith(source.Workbooks.File(1), ...
    fullfile('final', 'TestSummary.xlsx')));
verifyEqual(testCase, source.ResultSets.File(1), ...
    string(fullfile(runDirectory, 'targets', '001_Controller_abc', 'final', 'Results.mldatx')));
end

function testPerCutWithoutARerunUsesTheInitialRunAndRecordsIt(testCase)
folder = temp_folder(testCase);
cfg = pointer_config(folder);
runDirectory = write_per_cut_run(folder, 'per-cut-1', 'Passed', false);
write_json(cfg.PerCutLatestPointer, struct('Version', 1, 'RunId', 'per-cut-1', ...
    'RunDirectory', runDirectory, ...
    'Manifest', fullfile(runDirectory, 'manifest.json'), ...
    'UpdatedAt', '2026-09-18 11:00:00.000'));
source = st_final_document_run_source(cfg, 'PER_CUT');
verifyEqual(testCase, source.Workbooks.Stage(1), "INITIAL");
verifyTrue(testCase, any(source.Notes.Reason == "NO_FINAL_RUN_USED_INITIAL"));
end

function testPerCutWithoutCollectedWorkbooksSaysWhichCommandToRun(testCase)
folder = temp_folder(testCase);
cfg = pointer_config(folder);
runDirectory = write_per_cut_run(folder, 'per-cut-1', 'Passed', false);
delete(fullfile(runDirectory, 'targets', '001_Controller_abc', 'initial', 'TestSummary.xlsx'));
write_json(cfg.PerCutLatestPointer, struct('Version', 1, 'RunId', 'per-cut-1', ...
    'RunDirectory', runDirectory, ...
    'Manifest', fullfile(runDirectory, 'manifest.json'), ...
    'UpdatedAt', '2026-09-18 11:00:00.000'));
source = st_final_document_run_source(cfg, 'PER_CUT');
verifyEqual(testCase, height(source.Workbooks), 0);
verifyTrue(testCase, any(source.Notes.Reason == "NOT_COLLECTED"));
verifyTrue(testCase, any(contains(source.Notes.Message, 'st_collect_per_cut_results')));
end

function testUnreportedBatchRunIsCalledOut(testCase)
folder = temp_folder(testCase);
cfg = pointer_config(folder);
batchDirectory = fullfile(folder, 'test_runs', 'batch-1');
mkdir(batchDirectory);
write_iterations(fullfile(batchDirectory, 'TestSummary.xlsx'), ...
    "FINAL", "Controller_TC", "Iteration 1", "Passed");
write_json(cfg.LatestReportPointer, struct('Version', 1, 'RunId', 'batch-1', ...
    'RunDirectory', batchDirectory, 'UpdatedAt', '2026-09-18 10:00:00.000'));
write_json(cfg.LatestRunRecordPointer, struct('Version', 1, ...
    'RecordId', '20260918_130000_000', 'Directory', folder, ...
    'Record', fullfile(folder, 'run_record.mat'), 'RerunPerformed', false, ...
    'UpdatedAt', '2026-09-18 13:00:00'));
source = st_final_document_run_source(cfg, 'BATCH');
verifyTrue(testCase, any(source.Notes.Reason == "NOT_REPORTED"));
verifyTrue(testCase, any(contains(source.Notes.Message, 'st_generate_test_report')));
end


function testBatchWorkbookPrefersTheFinalRowsOverTheInitialOnes(testCase)
folder = temp_folder(testCase);
file = fullfile(folder, 'TestSummary.xlsx');
write_iterations(file, ["INITIAL";"FINAL"], ["Controller_TC";"Controller_TC"], ...
    ["Iteration 1";"Iteration 1"], ["Passed";"Failed"]);
outcomes = st_final_document_outcomes(base_config(), ...
    source_with_workbook("ANY", file));
verifyEqual(testCase, height(outcomes.Iterations), 1);
verifyEqual(testCase, outcomes.Iterations.Verdict(1), "FAIL");
verifyEqual(testCase, outcomes.Iterations.Stage(1), "FINAL");
end

function testBatchWorkbookWithoutFinalRowsUsesTheInitialOnes(testCase)
folder = temp_folder(testCase);
file = fullfile(folder, 'TestSummary.xlsx');
write_iterations(file, "INITIAL", "Controller_TC", "Iteration 1", "Passed");
outcomes = st_final_document_outcomes(base_config(), ...
    source_with_workbook("ANY", file));
verifyEqual(testCase, outcomes.Iterations.Verdict(1), "PASS");
verifyEqual(testCase, outcomes.Iterations.Stage(1), "INITIAL");
verifyTrue(testCase, any(outcomes.Notes.Reason == "NO_FINAL_RUN_USED_INITIAL"));
end

function testWorkbookWithoutAnIterationsSheetIsReportedNotGuessed(testCase)
folder = temp_folder(testCase);
file = fullfile(folder, 'TestSummary.xlsx');
writetable(table("x", 'VariableNames', {'Metric'}), file, ...
    'Sheet', 'Overview', 'UseExcel', false);
outcomes = st_final_document_outcomes(base_config(), ...
    source_with_workbook("ANY", file));
verifyEqual(testCase, height(outcomes.Iterations), 0);
verifyTrue(testCase, any(outcomes.Notes.Reason == "RESULT_WORKBOOK_SHAPE_UNEXPECTED"));
end

function testCoverageKeepsNumeratorAndDenominatorApartAndMarksGaps(testCase)
folder = temp_folder(testCase);
cfg = coverage_config(folder, ["Controller"; "Limiter"]);
summary = fullfile(folder, 'CoverageSummary.xlsx');
write_coverage_summary(summary, "Controller", 7, 10, 12, 15);
manifest = write_pipeline(folder, summary);
restore = shadow_targets(testCase, folder, ["Controller"; "Limiter"]);  %#ok<NASGU>
coverage = st_final_document_coverage(cfg, 'STANDALONE', manifest, []);
verifyEqual(testCase, coverage.Rows.ExecutionExecuted(1), 12);
verifyEqual(testCase, coverage.Rows.ExecutionTotal(1), 15);
verifyEqual(testCase, coverage.Rows.DecisionExecuted(1), 7);
verifyEqual(testCase, coverage.Rows.DecisionTotal(1), 10);
verifyTrue(testCase, isnan(coverage.Rows.ExecutionTotal(2)));
verifyTrue(testCase, any(coverage.Notes.Reason == "COVERAGE_ROW_MISSING"));
end

function testZeroDenominatorStaysUnavailableInsteadOfDividing(testCase)
coverage = coverage_struct(["Controller"], 0, 0, 0, 0);
document = minimal_document();
folder = temp_folder(testCase);
file = fullfile(folder, 'final.xlsx');
st_write_final_document_workbook(document, coverage, sample_metadata(), ...
    file, base_config());
cells = readcell(file, 'Sheet', 'Coverage');
verifyEqual(testCase, string(cells{2,2}), "N/A");
verifyEqual(testCase, string(cells{2,4}), "N/A");
package = unpack(file, folder);
sheet = xmlread(worksheet_of(package, 'Coverage'));
verifyEqual(testCase, sheet.getElementsByTagName('f').getLength(), 0);
end

function testPercentageIsARealFormulaWithACachedValueAndPercentFormat(testCase)
coverage = coverage_struct(["Controller"], 7, 10, 12, 15);
folder = temp_folder(testCase);
file = fullfile(folder, 'final.xlsx');
st_write_final_document_workbook(minimal_document(), coverage, ...
    sample_metadata(), file, base_config());
package = unpack(file, folder);
sheet = xmlread(worksheet_of(package, 'Coverage'));
[formula, styleIndex, cached] = formula_cell(sheet, 'D2');
verifyEqual(testCase, formula, 'B2/C2');
verifyEqual(testCase, str2double(cached), 12/15, 'AbsTol', 1e-12);
verifyEqual(testCase, char(formula_cell(sheet, 'G2')), 'E2/F2');
% LibreOffice does not recalculate an xlsx on open, so the cached value is
% what makes the percentage visible there.
styles = xmlread(fullfile(package, 'xl', 'styles.xml'));
xfs = styles.getElementsByTagName('cellXfs').item(0);
entries = xfs.getElementsByTagName('xf');
verifyEqual(testCase, str2double(char(xfs.getAttribute('count'))), ...
    double(entries.getLength()));
target = entries.item(styleIndex);
verifyEqual(testCase, char(target.getAttribute('numFmtId')), '10');
verifyEqual(testCase, char(target.getAttribute('applyNumberFormat')), '1');
book = xmlread(fullfile(package, 'xl', 'workbook.xml'));
calc = book.getElementsByTagName('calcPr');
verifyEqual(testCase, calc.getLength(), 1);
verifyEqual(testCase, char(calc.item(0).getAttribute('fullCalcOnLoad')), '1');
verifyFalse(testCase, isfile(fullfile(package, 'xl', 'calcChain.xml')));
end

function testSheetOrderAndHeadersMatchTheCustomerForm(testCase)
folder = temp_folder(testCase);
file = fullfile(folder, 'final.xlsx');
st_write_final_document_workbook(minimal_document(), ...
    coverage_struct(["Controller"], 7, 10, 12, 15), sample_metadata(), ...
    file, base_config());
verifyEqual(testCase, string(sheetnames(file))', ["TestCase"; "Coverage"; ...
    "TestResults"; "OverflowDetails"; "Metadata"]');
cells = readcell(file, 'Sheet', 'TestCase');
headers = cellfun(@(v) string(v), cells(1,:));
verifyEqual(testCase, headers, ["Test Case ID", "-", "-", "Pre Condition", ...
    "Description", "Test Steps.Action", "Test Steps.Expected result", ...
    "-", "-", "-", "-", "출력값", "판정 결과", "테스트 자료"]);
for column = [2 3 8 9 10 11]
    verifyTrue(testCase, ismissing(cells{2,column}) || ...
        strlength(string(cells{2,column})) == 0);
end
verifyEqual(testCase, cells{2,4}, 0.2);
verifyEqual(testCase, string(cells{2,12}), string(cells{2,7}));
package = unpack(file, folder);
styles = fileread(fullfile(package, 'xl', 'styles.xml'));
verifyTrue(testCase, contains(styles, 'wrapText="1"'));
end

function testExistingOutputIsRefusedAndLeftUntouched(testCase)
folder = temp_folder(testCase);
file = fullfile(folder, 'final.xlsx');
st_write_final_document_workbook(minimal_document(), ...
    coverage_struct(["Controller"], 7, 10, 12, 15), sample_metadata(), ...
    file, base_config());
before = st_file_signature(file).SHA256;
verifyError(testCase, @() st_write_final_document_workbook(minimal_document(), ...
    coverage_struct(["Controller"], 7, 10, 12, 15), sample_metadata(), ...
    file, base_config()), 'simtest:FinalDocumentOutputExists');
verifyEqual(testCase, st_file_signature(file).SHA256, before);
end


function testOverflowKeepsTheFirstChunkInTheCustomerCell(testCase)
folder = temp_folder(testCase);
file = fullfile(folder, 'final.xlsx');
document = minimal_document();
long = string(repmat('A', 1, 40000));
document.Sheet1.ExpectedResult(1) = long;
document.Sheet1.OutputValue(1) = long;
st_write_final_document_workbook(document, ...
    coverage_struct(["Controller"], 7, 10, 12, 15), sample_metadata(), ...
    file, base_config());
cells = readcell(file, 'Sheet', 'TestCase');
verifyTrue(testCase, startsWith(string(cells{2,7}), "AAA"));
verifyFalse(testCase, contains(string(cells{2,7}), "[OverflowDetails!"));
results = readcell(file, 'Sheet', 'TestResults');
verifyTrue(testCase, any(contains(string(results(:,7)), "[OverflowDetails!")));
overflow = readtable(file, 'Sheet', 'OverflowDetails', 'TextType', 'string');
verifyEqual(testCase, strjoin(overflow.Text(overflow.Column == "ExpectedResult"), ''), long);
end

function testCoverageFromTheTestRunReadsTheFinalRows(testCase)
folder = temp_folder(testCase);
file = fullfile(folder, 'TestSummary.xlsx');
writetable(table(["INITIAL";"FINAL";"FINAL"], ...
    ["Controller";"Controller";"Controller"], ...
    ["Decision";"Decision";"Execution"], [1;7;12], [10;10;15], ...
    'VariableNames', {'Run','CUTName','Metric','Covered','Total'}), ...
    file, 'Sheet', 'Coverage', 'UseExcel', false);
restore = shadow_targets(testCase, folder, "Controller"); %#ok<NASGU>
coverage = st_final_document_coverage(base_config(), 'TEST_RUN', 'LATEST', ...
    source_with_workbook("ANY", file));
verifyEqual(testCase, coverage.Rows.DecisionExecuted(1), 7);
verifyEqual(testCase, coverage.Rows.DecisionTotal(1), 10);
verifyEqual(testCase, coverage.Rows.ExecutionExecuted(1), 12);
verifyEqual(testCase, coverage.Rows.ExecutionTotal(1), 15);
end

function testFinalDocumentSourcesNeverSimulateOrOpenResultSets(testCase)
% Reading a .mldatx would pull in a Test Manager session and cost time on
% every export. The document quotes the path instead.
originalPath = path;
restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
addpath(fullfile(st_project_root(), 'tests', 'fixtures'));
folder = fullfile(st_project_root(), 'src', 'exporting');
files = dir(fullfile(folder, 'st_*final_document*.m'));
verifyGreaterThan(testCase, numel(files), 0);
forbidden = {'\bsim\s*\(', 'sltest\.testmanager\.run\s*\(', ...
    '\bsave_system\s*\(', '\bsaveToFile\s*\(', ...
    'sltest\.testsequence\.(activateScenario|editStep|addScenario)\s*\(', ...
    '\bst_run_\w*\s*\(', '\bst_update_expected_from_results\s*\(', ...
    '\bimportResults\s*\('};
for i = 1:numel(files)
    source = st_executable_source( ...
        fileread(fullfile(files(i).folder, files(i).name)));
    for j = 1:numel(forbidden)
        verifyEmpty(testCase, regexp(source, forbidden{j}, 'once'), files(i).name);
    end
end
end

function testMetadataRecordsBothRunIdentities(testCase)
% The verdicts and the coverage come from different executions, so the
% document has to name both.
source = fileread(fullfile(st_project_root(), 'src', 'exporting', ...
    'st_export_final_document.m'));
verifyTrue(testCase, contains(source, "add('ResultRunId'"));
verifyTrue(testCase, contains(source, "add('ResultRunMode'"));
verifyTrue(testCase, contains(source, "add('CoveragePipelineId'"));
verifyTrue(testCase, contains(source, "add('CoverageSummarySHA256'"));
verifyTrue(testCase, contains(source, 'simtest:FinalDocumentTestResultsRequired'));
verifyTrue(testCase, contains(source, 'simtest:FinalDocumentCoverageRequired'));
end


function cfg = base_config()
cfg = struct('VerboseLogging', false, 'FinalDocumentNAText', 'N/A', ...
    'FinalDocumentTestCaseIdMode', 'COMBINED', 'OnlyEnabled', true);
end


function folder = temp_folder(testCase)
folder = tempname;
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
end


function cfg = pointer_config(folder)
cfg = base_config();
cfg.ResultDir = folder;
cfg.LatestReportPointer = fullfile(folder, 'latest.json');
cfg.PerCutLatestPointer = fullfile(folder, 'per_cut_latest.json');
cfg.LatestRunRecordPointer = fullfile(folder, 'run_record_latest.json');
end


function cfg = coverage_config(folder, cuts) %#ok<INUSD>
cfg = base_config();
cfg.ResultDir = folder;
cfg.StandaloneCoverageRootDir = fullfile(folder, 'standalone_coverage');
end


function specification = sample_specification()
rows = strings(1,13);
rows(1) = "Controller_TC";
rows(2) = "Controller";
rows(3) = "Controller_Harness1";
rows(4) = "TOP_Controller_Harness1_HarnessInputs.mat";
rows(5) = "UT_REQ_CUT_NAME_001";
rows(6) = "ABC: 1";
rows(8) = "TOP";
rows(9) = "TOP/Controller";
rows(10) = "Iteration 1";
rows(11) = "Scenario1";
rows(12) = "OK";
specification = st_specification_table(rows, {"[step2]" + newline + "AAA: 2"}, ...
    0.2, "D1 [T/F]Switch (c1 > 0)");
end


function metadata = sample_metadata()
metadata = table(["CreatedAt"; "TopModel"], ["2026-09-18 00:00:00.000"; "TOP"], ...
    'VariableNames', {'Key','Value'});
end


function document = minimal_document()
document = st_final_document_table(base_config(), sample_specification(), ...
    empty_outcomes(), empty_source(), 'COMBINED');
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


function source = source_with_workbook(stage, file)
source = empty_source();
source.Mode = 'BATCH';
source.Workbooks = table(string(stage), 0, "", string(file), ...
    'VariableNames', {'Stage','No','TestCaseName','File'});
end


function coverage = coverage_struct(cuts, decisionExecuted, decisionTotal, executionExecuted, executionTotal)
cuts = string(cuts(:));
count = numel(cuts);
coverage = struct('Source', 'STANDALONE', 'PipelineId', 'pipeline-1', ...
    'SummaryFile', '', 'SummarySHA256', '', 'Notes', note_table(), ...
    'Rows', table(cuts, cuts, repmat(executionExecuted, count, 1), ...
    repmat(executionTotal, count, 1), repmat(decisionExecuted, count, 1), ...
    repmat(decisionTotal, count, 1), 'VariableNames', ...
    {'CUT','CUTPath','ExecutionExecuted','ExecutionTotal', ...
    'DecisionExecuted','DecisionTotal'}));
end


function write_json(file, value)
folder = fileparts(file);
if ~isfolder(folder), mkdir(folder); end
handle = fopen(file, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(handle)); %#ok<NASGU>
fwrite(handle, unicode2native(jsonencode(value), 'UTF-8'));
end


function write_iterations(file, runLabel, testCaseName, iterationName, outcome)
count = numel(string(runLabel(:)));
folder = fileparts(file);
if ~isfolder(folder), mkdir(folder); end
writetable(table(string(runLabel(:)), ones(count,1), ...
    repmat("Controller", count, 1), string(testCaseName(:)), ...
    string(iterationName(:)), string(outcome(:)), zeros(count,1), ...
    'VariableNames', {'Run','No','CUTName','TestCaseName','IterationName', ...
    'Outcome','DurationSec'}), file, 'Sheet', 'Iterations', 'UseExcel', false);
writetable(table(string(runLabel(:)), ones(count,1), ...
    repmat("Controller", count, 1), repmat("TOP/Controller", count, 1), ...
    string(testCaseName(:)), string(outcome(:)), zeros(count,1), ones(count,1), ...
    'VariableNames', {'Run','No','CUTName','CUTPath','TestCaseName', ...
    'Outcome','DurationSec','IterationCount'}), file, 'Sheet', 'Targets', ...
    'UseExcel', false);
end


function runDirectory = write_per_cut_run(folder, runId, outcome, rerun)
runDirectory = fullfile(folder, 'per_cut_runs', runId);
targetDirectory = fullfile(runDirectory, 'targets', '001_Controller_abc');
mkdir(fullfile(targetDirectory, 'initial'));
write_iterations(fullfile(targetDirectory, 'initial', 'TestSummary.xlsx'), ...
    "INITIAL", "Controller_TC", "Iteration 1", "Passed");
artifacts = struct('No', 1, 'Stage', 'INITIAL', 'Type', 'MLDATX', ...
    'Path', fullfile(targetDirectory, 'initial', 'Results.mldatx'), ...
    'Status', 'OK', 'Message', 'Saved for st_collect_per_cut_results');
if rerun
    mkdir(fullfile(targetDirectory, 'final'));
    write_iterations(fullfile(targetDirectory, 'final', 'TestSummary.xlsx'), ...
        "FINAL", "Controller_TC", "Iteration 1", outcome);
    artifacts(2) = struct('No', 1, 'Stage', 'FINAL', 'Type', 'MLDATX', ...
        'Path', fullfile(targetDirectory, 'final', 'Results.mldatx'), ...
        'Status', 'OK', 'Message', 'Saved for st_collect_per_cut_results');
end
manifestPath = fullfile(targetDirectory, 'target-manifest.json');
write_json(manifestPath, struct('No', 1, 'CUTName', 'Controller'));
% InitialReport and FinalReport stay empty, as they do on the default
% DEFERRED collection path.
target = struct('No', 1, 'CUTName', 'Controller', 'CUTPath', 'TOP/Controller', ...
    'TestCaseName', 'Controller_TC', 'InitialReport', '', 'FinalReport', '', ...
    'RerunPerformed', rerun, 'TargetManifest', manifestPath, 'Status', 'PASS');
write_json(fullfile(runDirectory, 'manifest.json'), struct( ...
    'Version', 1, 'RunId', runId, 'ExecutionMode', 'PER_CUT', ...
    'RunDirectory', runDirectory, 'ExcelWritten', true, ...
    'Targets', target, 'Artifacts', artifacts));
end


function write_coverage_summary(file, cut, decisionExecuted, decisionTotal, executionExecuted, executionTotal)
writetable(table(1, string(cut), "TOP/" + string(cut), "Controller_TC", ...
    "Controller_Harness1", decisionExecuted, decisionTotal, "70.00%", ...
    executionExecuted, executionTotal, "80.00%", 'VariableNames', ...
    {'NUM','CUT_NAME','CUT_PATH','Test Case Name','Harness Name', ...
    'Decision Executed','Decision Total','Decision (%)', ...
    'Execution Executed','Execution Total','Execution (%)'}), ...
    file, 'Sheet', 'CoverageSummary', 'UseExcel', false);
end


function pipelineId = write_pipeline(folder, summaryFile)
pipelineId = 'pipeline-1';
root = fullfile(folder, 'standalone_coverage', pipelineId);
mkdir(root);
manifestPath = fullfile(root, 'pipeline-manifest.json');
write_json(manifestPath, struct('Version', 3, 'PipelineId', pipelineId, ...
    'PipelineRoot', root, 'Actions', struct('SUMMARY', struct('Status', 'OK')), ...
    'CoverageSummary', summaryFile, ...
    'CoverageSummarySHA256', st_file_signature(summaryFile).SHA256));
handle = fopen(fullfile(root, 'pipeline-manifest.sha256'), 'w');
cleanup = onCleanup(@() fclose(handle)); %#ok<NASGU>
fprintf(handle, '%s\n', st_file_signature(manifestPath).SHA256);
end


function restore = shadow_targets(testCase, folder, cuts)
% st_final_document_coverage keeps a row for every managed CUT, so the test
% supplies the target list the way the dirty-model test supplies cfg: by
% shadowing the real function on the path.
shadow = fullfile(folder, 'shadow');
mkdir(shadow);
names = string(cuts(:));
save(fullfile(shadow, 'shadow_targets.mat'), 'names');
write_lines(fullfile(shadow, 'st_load_targets.m'), [ ...
    "function targets = st_load_targets(varargin)"
    "loaded = load(fullfile(fileparts(mfilename('fullpath')), 'shadow_targets.mat'));"
    "targets = table(loaded.names, ""TOP/"" + loaded.names, ..."
    "    'VariableNames', {'CUTName','CUTPath'});"
    "end"]);
originalPath = path;
testCase.addTeardown(@() restore_shadow(originalPath));
addpath(shadow, '-begin');
clear st_load_targets;
restore = [];
end


function restore_shadow(originalPath)
path(originalPath);
clear st_load_targets;
end


function write_lines(file, lines)
handle = fopen(file, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(handle)); %#ok<NASGU>
fwrite(handle, unicode2native(strjoin(cellstr(lines), newline), 'UTF-8'));
end


function package = unpack(file, folder)
package = tempname(folder);
unzip(file, package);
end


function file = worksheet_of(package, sheetName)
book = xmlread(fullfile(package, 'xl', 'workbook.xml'));
rels = xmlread(fullfile(package, 'xl', '_rels', 'workbook.xml.rels'));
targets = containers.Map('KeyType', 'char', 'ValueType', 'char');
items = rels.getElementsByTagName('Relationship');
for i = 0:items.getLength()-1
    targets(char(items.item(i).getAttribute('Id'))) = ...
        char(items.item(i).getAttribute('Target'));
end
sheets = book.getElementsByTagName('sheet');
file = '';
for i = 0:sheets.getLength()-1
    if ~strcmp(char(sheets.item(i).getAttribute('name')), sheetName), continue; end
    parts = strsplit(strrep(targets(char(sheets.item(i).getAttribute('r:id'))), ...
        char(92), '/'), '/');
    file = fullfile(package, 'xl', 'worksheets', parts{end});
    return;
end
end


function [formula, styleIndex, cached] = formula_cell(sheet, reference)
formula = '';
styleIndex = -1;
cached = '';
cells = sheet.getElementsByTagName('c');
for k = 0:cells.getLength()-1
    node = cells.item(k);
    if ~strcmp(char(node.getAttribute('r')), reference), continue; end
    styleIndex = str2double(char(node.getAttribute('s')));
    entries = node.getElementsByTagName('f');
    if entries.getLength() > 0
        formula = char(entries.item(0).getTextContent());
    end
    values = node.getElementsByTagName('v');
    if values.getLength() > 0
        cached = char(values.item(0).getTextContent());
    end
    return;
end
end
