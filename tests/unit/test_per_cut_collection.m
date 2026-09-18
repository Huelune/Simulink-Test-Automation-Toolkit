function tests = test_per_cut_collection
%TEST_PER_CUT_COLLECTION PER_CUT runs alone; the CVF belongs to the results.
%
% PER_CUT exists because some Test Cases only work when run by themselves.
% A coverage filter shapes the coverage data of the artifacts built from a
% run, so it is the collect step's work, not the run's.
tests = functiontests(localfunctions);
end

function testDefaultDefersCollection(testCase)
cfg = st_config();
verifyEqual(testCase, cfg.PerCutResultCollection, 'DEFERRED');
end

function testInvalidModeIsRejected(testCase)
verifyError(testCase, @() st_run_tests_per_cut( ...
    'ResultCollection', 'LATER'), ...
    'simtest:InvalidPerCutResultCollection');
end

function testDeferredRunNeverFiltersDuringTheRun(testCase)
% Both run-time filter paths must be closed, otherwise the run would shape
% the coverage data the collect step is supposed to shape.
source = fileread(fullfile(st_project_root(), 'src', 'execution', ...
    'st_run_tests_per_cut.m'));
verifyNotEmpty(testCase, regexp(source, ...
    'if deferResults\s*\n\s*%[^\n]*\n\s*%[^\n]*\n\s*applyManagedFiltersDuringRun = false;', ...
    'once'));
verifyEqual(testCase, numel(regexp(source, ...
    '~deferResults && ~applyManagedFiltersDuringRun')), 2);
end

function testStandaloneBundleKeepsItsCoverageWorkInsideTheRun(testCase)
% The bundle's execution models are disposable. Nothing could reopen them
% later to attach a CVF, so that run cannot defer.
runner = fileread(fullfile(st_project_root(), 'resources', ...
    'export_bundle', 'run_exported_tests.m'));
verifyNotEmpty(testCase, regexp(runner, ...
    "'ResultCollection', 'INLINE'", 'once'));
end

function testCollectWithoutARunNamesWhatToDoFirst(testCase)
% The message has to say the tests must run first; a bare missing-file path
% leaves the operator guessing which command they skipped.
source = fileread(fullfile(st_project_root(), 'src', 'execution', ...
    'st_collect_per_cut_results.m'));
verifyNotEmpty(testCase, regexp(source, ...
    'simtest:CollectRunMissing', 'once'));
verifyNotEmpty(testCase, regexp(source, ...
    'No PER_CUT run to collect. Run the tests first', 'once'));
end

function testDiagnosticAcceptsTheDeferredLifecycle(testCase)
% Apply and restore are about filtering a live model. A deferred run does
% neither, so NOT_REQUIRED must not read as a failure.
source = fileread(fullfile(st_project_root(), 'diagnostics', 'matlab', ...
    'st_check_per_cut_cvf.m'));
verifyNotEmpty(testCase, regexp(source, 'deferredToCollect', 'once'));
verifyNotEmpty(testCase, regexp(source, "'NOT_REQUIRED'", 'once'));
end
