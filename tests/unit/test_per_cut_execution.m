function tests = test_per_cut_execution
%TEST_PER_CUT_EXECUTION Pure/static checks for isolated CUT execution.
tests = functiontests(localfunctions);
end


function testAutoKeepsLegacyBatchWhenAllFiltersAreOff(testCase)
T = filter_table(["OFF"; "OFF"]);
verifyEqual(testCase, st_resolve_execution_mode('AUTO', T), 'BATCH');
verifyEqual(testCase, st_resolve_execution_mode('PER_CUT', T), 'PER_CUT');
end


function testAutoSelectsPerCutForEveryRowWhenOneFilterIsActive(testCase)
T = filter_table(["OFF"; "SUBSYSTEM"; "OFF"]);
verifyEqual(testCase, st_resolve_execution_mode('AUTO', T), 'PER_CUT');
end


function testBatchRejectsAnyActiveFilter(testCase)
T = filter_table(["OFF"; "ALL_CONTENT"]);
verifyError(testCase, @() st_resolve_execution_mode('BATCH', T), ...
    'simtest:BatchExecutionWithCoverageFilter');
end


function testTargetDirectoryIsStableAndCollisionResistant(testCase)
runDirectory = fullfile(tempdir, 'per-cut-run');
No = [1; 2];
CUTName = ["CUT A"; "CUT A"];
CUTPath = ["Top/CUT A"; "Top/CUT A"];
TestCaseName = ["TC"; "TC"];
T = table(No, CUTName, CUTPath, TestCaseName);

first = st_per_cut_target_directory(runDirectory, T(1,:));
verifyEqual(testCase, first, ...
    st_per_cut_target_directory(runDirectory, T(1,:)));
verifyNotEqual(testCase, first, ...
    st_per_cut_target_directory(runDirectory, T(2,:)));
verifyTrue(testCase, startsWith(string(first), ...
    string(fullfile(runDirectory, 'targets'))));
end


function testRunnerUsesIndependentTestCaseRunAndRestores(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'execution', ...
    'st_run_tests_per_cut.m'));

verifyGreaterThanOrEqual(testCase, ...
    numel(regexp(source, 'run\(tc\)', 'match')), 1);
verifyNotEmpty(testCase, regexp(source, ...
    'for i = 1:n', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'session\.Restore\(\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'simtest:CoverageFilterRestoreFailed', 'once'));
orderedEvents = {'APPLY_START','RUN_INITIAL_START', ...
    'EXPORT_INITIAL_START','RESTORE_START','TARGET_COMPLETE'};
positions = zeros(numel(orderedEvents),1);
for i = 1:numel(orderedEvents)
    positions(i) = regexp(source, orderedEvents{i}, 'once');
end
verifyTrue(testCase, all(diff(positions) > 0));
verifyEmpty(testCase, regexp(source, ...
    'st_apply_run_test_case_scope', 'once'));
end


function testRunnerKeepsSeparateReportAndPointerPaths(testCase)
cfg = st_config();
verifyTrue(testCase, endsWith(string(cfg.PerCutRunRootDir), ...
    fullfile('result', 'per_cut_runs')));
verifyTrue(testCase, endsWith(string(cfg.PerCutLatestPointer), ...
    fullfile('result', 'per_cut_latest.json')));

root = st_project_root();
source = fileread(fullfile(root, 'src', 'execution', ...
    'st_run_tests_per_cut.m'));
verifyNotEmpty(testCase, regexp(source, ...
    '''applied\.cvf''', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    '''ResultLabel'', ''INITIAL''', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    '''ResultLabel'', ''FINAL''', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'PerCutInitialReportFailed', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'PerCutFinalReportFailed', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'CVFSHA256', 'once'));
end


function testPerCutWorkflowDefersSharedFilterGeneration(testCase)
root = st_project_root();
workflow = fileread(fullfile(root, 'src', 'workflow', ...
    'st_run_workflow.m'));
deferred = fileread(fullfile(root, 'src', 'coverage', ...
    'st_defer_coverage_filters_to_per_cut.m'));
verifyNotEmpty(testCase, regexp(workflow, ...
    'st_defer_coverage_filters_to_per_cut', 'once'));
verifyNotEmpty(testCase, regexp(workflow, ...
    '''DeferCoverageFilters'', true', 'once'));
verifyEmpty(testCase, regexp(deferred, ...
    'st_generate_coverage_filter_file', 'once'));
verifyNotEmpty(testCase, regexp(deferred, ...
    'Deferred to execution-local PER_CUT', 'once'));
end


function testLegacyRunnerRemainsBatchOnly(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'src', 'execution', ...
    'st_run_generated_tests.m'));
verifyNotEmpty(testCase, regexp(source, 'run\(tf\)', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'BatchExecutionWithCoverageFilter', 'once'));
end


function testFixtureDefinesThreeCoverageFilterCases(testCase)
root = st_project_root();
source = fileread(fullfile(root, 'tests', 'fixtures', ...
    'st_build_verification_fixture.m'));
verifyNotEmpty(testCase, regexp(source, ...
    '"SUBSYSTEM"; "ALL_CONTENT"; repmat\("OFF"', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    '"JUSTIFY"; "EXCLUDE"', 'once'));
end


function T = filter_table(modes)
CoverageFilterMode = string(modes(:));
T = table(CoverageFilterMode);
end
