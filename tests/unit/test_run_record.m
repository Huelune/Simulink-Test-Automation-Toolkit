function tests = test_run_record
%TEST_RUN_RECORD Running the tests and collecting the results are separate.
%
% A Test Manager ResultSet only exists inside the session that produced it,
% so the integrated report used to be something only that session could
% build. The run now saves itself, and the report is rebuilt from the saved
% record.
tests = functiontests(localfunctions);
end

function testConfigKeepsRunRecordsUnderResult(testCase)
cfg = st_config();
rootDir = st_project_root();
verifyEqual(testCase, cfg.RunRecordRootDir, ...
    fullfile(rootDir, 'result', 'run_records'));
verifyEqual(testCase, cfg.LatestRunRecordPointer, ...
    fullfile(rootDir, 'result', 'run_record_latest.json'));
end

function testIntegratedReportIsNotAutomatic(testCase)
% The workflow stops at the finished tests. Collecting the results is the
% caller's next choice: this report, or the standalone pipeline.
cfg = st_config();
verifyFalse(testCase, cfg.GenerateTestReport);
end

function testMissingPointerNamesWhatToRunFirst(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
cfg = struct( ...
    'RunRecordRootDir', fullfile(folder, 'run_records'), ...
    'LatestRunRecordPointer', fullfile(folder, 'missing.json'));

verifyError(testCase, @() st_load_run_record('LATEST', cfg), ...
    'simtest:RunRecordPointerMissing');
end

function testPointerToAnAbsentRecordIsRejected(testCase)
% A pointer that survives its record must fail loudly rather than report on
% nothing.
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
pointer = fullfile(folder, 'run_record_latest.json');
st_write_json_atomic(pointer, struct('Version', 1, 'RecordId', '20260101_000000_000'));
cfg = struct( ...
    'RunRecordRootDir', fullfile(folder, 'run_records'), ...
    'LatestRunRecordPointer', pointer);

verifyError(testCase, @() st_load_run_record('LATEST', cfg), ...
    'simtest:RunRecordMissing');
end

function testReportRejectsAnUnknownCallShape(testCase)
verifyError(testCase, @() st_generate_test_report(1, 2), ...
    'simtest:InvalidReportInputs');
end

function testWorkflowSavesTheRecordBeforeChoosingToReport(testCase)
% The save must not sit behind cfg.GenerateTestReport, otherwise turning the
% report off would throw the run away.
source = fileread(fullfile(st_project_root(), 'src', 'workflow', ...
    'st_run_workflow.m'));
savePosition = regexp(source, 'st_save_run_record', 'once');
reportBranch = regexp(source, 'if cfg\.GenerateTestReport', 'once');

verifyNotEmpty(testCase, savePosition);
verifyNotEmpty(testCase, reportBranch);
verifyLessThan(testCase, savePosition, reportBranch);
end

function testCleanupCoversSavedRunRecords(testCase)
plan = st_cleanup_results('Scope', 'RUNS');
cfg = st_config();
verifyTrue(testCase, any(strcmp(plan.Path, cfg.RunRecordRootDir)));
verifyTrue(testCase, any(strcmp(plan.Path, cfg.LatestRunRecordPointer)));
end
