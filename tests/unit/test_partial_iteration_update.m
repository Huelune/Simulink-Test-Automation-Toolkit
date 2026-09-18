function tests = test_partial_iteration_update
%TEST_PARTIAL_ITERATION_UPDATE Partial Iteration handling for verify updates.
%
% A Test Case owns one Iteration per Test Sequence scenario. When some
% Iterations fail with an error and others run normally, the healthy ones must
% still reach the expected-value update, and the run must be judged PARTIAL
% instead of passing quietly or aborting everything.
tests = functiontests(localfunctions);
end


function cfg = quiet_config()
cfg = struct('VerboseLogging', false);
end


function T = verify_rows(statuses)
statuses = string(statuses(:));
n = numel(statuses);
TestCaseName = repmat("TC_A", n, 1);
ScenarioName = "SC_" + string((1:n)');
Message = "message " + string((1:n)');
Status = statuses;
T = table(TestCaseName, ScenarioName, Status, Message);
end


function T = update_rows(statuses, updatedCounts)
statuses = string(statuses(:));
n = numel(statuses);
TestCaseName = repmat("TC_A", n, 1);
ScenarioName = "SC_" + string((1:n)');
Message = "message " + string((1:n)');
Status = statuses;
UpdatedCount = double(updatedCounts(:));
T = table(TestCaseName, ScenarioName, Status, Message, UpdatedCount);
end


%% ------------------------------------------------------------
% Verify timing gate
%% ------------------------------------------------------------

function testMixedVerifyTimingIsPartialAndDoesNotAbort(testCase)
gate = st_verify_timing_gate( ...
    verify_rows(["FAIL"; "FAIL"; "OK"]), quiet_config(), 'initial');

verifyEqual(testCase, gate.Status, 'PARTIAL');
verifyFalse(testCase, gate.Abort);
verifyEqual(testCase, gate.FailCount, 2);
verifyEqual(testCase, gate.OkCount, 1);
verifyEqual(testCase, gate.EvaluatedCount, 3);
verifyEqual(testCase, numel(gate.FailedScenarios), 2);
verifyNotEmpty(testCase, gate.Message);
end


function testTotalVerifyTimingFailureStillAborts(testCase)
gate = st_verify_timing_gate( ...
    verify_rows(["FAIL"; "FAIL"]), quiet_config(), 'initial');

verifyEqual(testCase, gate.Status, 'FAIL');
verifyTrue(testCase, gate.Abort);
end


function testVerifyTimingGateIgnoresSkipRowsWhenJudging(testCase)
gate = st_verify_timing_gate( ...
    verify_rows(["SKIP"; "OK"]), quiet_config(), 'initial');
verifyEqual(testCase, gate.Status, 'OK');
verifyFalse(testCase, gate.Abort);

skipOnly = st_verify_timing_gate( ...
    verify_rows(["SKIP"; "SKIP"]), quiet_config(), 'initial');
verifyEqual(testCase, skipOnly.Status, 'SKIP');
verifyFalse(testCase, skipOnly.Abort);

empty = st_verify_timing_gate(table(), quiet_config(), 'initial');
verifyEqual(testCase, empty.Status, 'NOT_RUN');
verifyFalse(testCase, empty.Abort);
end


%% ------------------------------------------------------------
% Expected update gate
%% ------------------------------------------------------------

function testMixedExpectedUpdateIsPartialAndKeepsUpdatedLines(testCase)
gate = st_expected_update_gate( ...
    update_rows(["FAIL"; "OK"; "SKIP"], [0; 4; 0]), ...
    quiet_config(), 'initial');

verifyEqual(testCase, gate.Status, 'PARTIAL');
verifyEqual(testCase, gate.UpdatedCount, 4);
verifyEqual(testCase, gate.OkCount, 1);
verifyEqual(testCase, gate.FailCount, 1);
verifyEqual(testCase, gate.SkipCount, 1);
end


function testExpectedUpdateGateReportsCleanAndTotalFailure(testCase)
clean = st_expected_update_gate( ...
    update_rows(["OK"; "SKIP"], [2; 0]), quiet_config(), 'initial');
verifyEqual(testCase, clean.Status, 'OK');
verifyEqual(testCase, clean.UpdatedCount, 2);

total = st_expected_update_gate( ...
    update_rows(["FAIL"; "FAIL"], [0; 0]), quiet_config(), 'initial');
verifyEqual(testCase, total.Status, 'FAIL');

skipped = st_expected_update_gate( ...
    update_rows(["SKIP"; "SKIP"], [0; 0]), quiet_config(), 'initial');
verifyEqual(testCase, skipped.Status, 'SKIP');

notRun = st_expected_update_gate(table(), quiet_config(), 'initial');
verifyEqual(testCase, notRun.Status, 'NOT_RUN');
end


%% ------------------------------------------------------------
% Judgment combination
%% ------------------------------------------------------------

function testPartialNeverCollapsesIntoOk(testCase)
verifyEqual(testCase, st_combine_run_status('OK', 'PARTIAL'), 'PARTIAL');
verifyEqual(testCase, st_combine_run_status('OK', 'SKIP'), 'OK');
verifyEqual(testCase, st_combine_run_status('PARTIAL', 'FAIL'), 'FAIL');
verifyEqual(testCase, st_combine_run_status('SKIP', 'NOT_RUN'), 'SKIP');
verifyEqual(testCase, st_combine_run_status('NOT_RUN'), 'NOT_RUN');
verifyEqual(testCase, st_combine_run_status(), 'NOT_RUN');
end


%% ------------------------------------------------------------
% Runner wiring
%% ------------------------------------------------------------

function testBatchRunnerAbortsOnlyOnTotalVerifyTimingFailure(testCase)
source = source_of('execution', 'st_run_generated_tests.m');

verifyNotEmpty(testCase, regexp(source, ...
    'st_verify_timing_gate\(verifyTimingResult, cfg, ''initial''\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'if verifyGate\.Abort', 'once'));
verifyEmpty(testCase, regexp(source, ...
    'any\(verifyTimingResult\.Status == ''FAIL''\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'runContext\.Status = st_combine_run_status', 'once'));
verifyNotEmpty(testCase, regexp(source, 'Run Judgment', 'once'));
end


function testPerCutKeepsGoingWhenOnlySomeScenariosFail(testCase)
source = source_of('execution', 'st_run_tests_per_cut.m');

verifyEmpty(testCase, regexp(source, ...
    'simtest:PerCutExpectedUpdateFailed', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'st_expected_update_gate\(updateResult, cfg, ''initial''\)', 'once'));
verifyNotEmpty(testCase, regexp(source, 'if gate\.Abort', 'once'));
verifyNotEmpty(testCase, regexp(source, 'VERIFY_TIMING_PARTIAL', 'once'));
verifyNotEmpty(testCase, regexp(source, 'EXPECTED_UPDATE_PARTIAL', 'once'));
verifyNotEmpty(testCase, regexp(source, 'TARGET_PARTIAL', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'VerifyTimingStatus, ExpectedUpdateStatus', 'once'));
end


function testExpectedUpdateRecordsWhyANonFailedIterationIsSkipped(testCase)
source = source_of('execution', 'st_update_expected_from_results.m');

verifyNotEmpty(testCase, regexp(source, ...
    'SKIP_OUTCOME_NOT_FAILED', 'once'));
verifyEmpty(testCase, regexp(source, ...
    '''Iteration is not Failed''', 'once'));
end


function testPerCutReportSurfacesPartialTargets(testCase)
source = source_of('reporting', 'st_write_per_cut_run_report.m');

verifyNotEmpty(testCase, regexp(source, ...
    'overallStatus = "PARTIAL"', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'PartialTargetCount', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'function total = count_partial_targets', 'once'));
end


function source = source_of(folder, name)
source = fileread(fullfile(st_project_root(), 'src', folder, name));
end
